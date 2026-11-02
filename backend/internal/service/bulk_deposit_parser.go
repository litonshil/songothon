package service

import (
	"errors"
	"fmt"
	"io"
	"math"
	"regexp"
	"strconv"
	"strings"

	"github.com/xuri/excelize/v2"
	"songothon/internal/domain"
)

const (
	bulkDepositMaxRows  = 2000
	bulkDepositMaxCells = 20000
)

var cycleHeaderRe = regexp.MustCompile(`^\d{4}-(0[1-9]|1[0-2])$`)

// ParseBulkDepositSheet reads the first worksheet of an .xlsx file.
//
// Expected layout: row 1 is the header. One column titled "Email" (any case)
// identifies the member; every column titled YYYY-MM is a deposit cycle. Other
// columns (e.g. "Sl", "Name") are ignored. Blank or zero amount cells mean
// "no deposit" and are skipped.
//
// Row-level problems are returned as validation errors rather than aborting, so
// the admin sees every issue in one pass. A non-nil error means the file itself
// is unusable.
func ParseBulkDepositSheet(r io.Reader) (cells []domain.BulkDepositCell, cycles []string, validation []domain.BulkDepositError, err error) {
	f, err := excelize.OpenReader(r)
	if err != nil {
		return nil, nil, nil, errors.New("could not read the file; upload a valid .xlsx spreadsheet")
	}
	defer f.Close()

	sheets := f.GetSheetList()
	if len(sheets) == 0 {
		return nil, nil, nil, errors.New("the spreadsheet has no worksheets")
	}
	rows, err := f.GetRows(sheets[0])
	if err != nil {
		return nil, nil, nil, fmt.Errorf("could not read worksheet %q: %w", sheets[0], err)
	}
	if len(rows) < 2 {
		return nil, nil, nil, errors.New("the first worksheet must have a header row and at least one member row")
	}
	if len(rows)-1 > bulkDepositMaxRows {
		return nil, nil, nil, fmt.Errorf("too many rows: at most %d member rows per upload", bulkDepositMaxRows)
	}

	emailCol := -1
	cycleCols := map[int]string{}
	seenCycle := map[string]bool{}
	for i, raw := range rows[0] {
		h := strings.TrimSpace(raw)
		switch {
		case strings.EqualFold(h, "email"):
			if emailCol != -1 {
				return nil, nil, nil, errors.New(`the header has more than one "Email" column`)
			}
			emailCol = i
		case cycleHeaderRe.MatchString(h):
			if seenCycle[h] {
				return nil, nil, nil, fmt.Errorf("cycle column %s appears more than once in the header", h)
			}
			seenCycle[h] = true
			cycleCols[i] = h
			cycles = append(cycles, h)
		}
	}
	if emailCol == -1 {
		return nil, nil, nil, errors.New(`the header row must contain an "Email" column`)
	}
	if len(cycleCols) == 0 {
		return nil, nil, nil, errors.New("the header row must contain at least one cycle column named like 2026-01")
	}

	seenEmail := map[string]int{}
	for ri, row := range rows[1:] {
		rowNum := ri + 2 // 1-based, after the header

		if isBlankRow(row) {
			continue
		}

		email := strings.ToLower(strings.TrimSpace(cellAt(row, emailCol)))
		if email == "" {
			validation = append(validation, domain.BulkDepositError{Row: rowNum, Column: "Email", Message: "email is missing"})
			continue
		}
		if prev, dup := seenEmail[email]; dup {
			validation = append(validation, domain.BulkDepositError{
				Row: rowNum, Column: "Email",
				Message: fmt.Sprintf("%s is also listed on row %d; put each member on one row", email, prev),
			})
			continue
		}
		seenEmail[email] = rowNum

		for col := range row {
			cycle, ok := cycleCols[col]
			if !ok {
				continue
			}
			raw := strings.TrimSpace(row[col])
			if raw == "" {
				continue
			}
			amount, perr := parseAmount(raw)
			if perr != nil {
				validation = append(validation, domain.BulkDepositError{Row: rowNum, Column: cycle, Message: fmt.Sprintf("%q is not a valid amount", raw)})
				continue
			}
			if amount < 0 {
				validation = append(validation, domain.BulkDepositError{Row: rowNum, Column: cycle, Message: "amount cannot be negative"})
				continue
			}
			if amount == 0 {
				continue
			}
			cells = append(cells, domain.BulkDepositCell{Row: rowNum, Email: email, Cycle: cycle, Amount: amount})
			if len(cells) > bulkDepositMaxCells {
				return nil, nil, nil, fmt.Errorf("too many deposits: at most %d per upload", bulkDepositMaxCells)
			}
		}
	}

	return cells, cycles, validation, nil
}

func cellAt(row []string, i int) string {
	if i < len(row) {
		return row[i]
	}
	return ""
}

func isBlankRow(row []string) bool {
	for _, v := range row {
		if strings.TrimSpace(v) != "" {
			return false
		}
	}
	return true
}

// parseAmount accepts formatted values such as "1,000", "1000.50" or "৳1,000".
func parseAmount(raw string) (float64, error) {
	s := strings.NewReplacer(",", "", " ", "", "৳", "", "BDT", "", "Tk", "").Replace(raw)
	v, err := strconv.ParseFloat(s, 64)
	if err != nil || math.IsNaN(v) || math.IsInf(v, 0) {
		return 0, errors.New("invalid amount")
	}
	return math.Round(v*100) / 100, nil
}
