package service_test

import (
	"bytes"
	"os"
	"strings"
	"testing"

	"github.com/xuri/excelize/v2"
	"songothon/internal/service"
)

func buildSheet(t *testing.T, rows [][]interface{}) *bytes.Buffer {
	t.Helper()
	f := excelize.NewFile()
	for i, r := range rows {
		cell, _ := excelize.CoordinatesToCellName(1, i+1)
		if err := f.SetSheetRow("Sheet1", cell, &r); err != nil {
			t.Fatal(err)
		}
	}
	buf, err := f.WriteToBuffer()
	if err != nil {
		t.Fatal(err)
	}
	return buf
}

func TestParseBulkDepositSheet_SampleFile(t *testing.T) {
	data, err := os.ReadFile("../../../Batch_13_Deposits_Upload.xlsx")
	if err != nil {
		t.Skip("sample file not present:", err)
	}
	cells, cycles, validation, err := service.ParseBulkDepositSheet(bytes.NewReader(data))
	if err != nil {
		t.Fatal(err)
	}
	if len(validation) != 0 {
		t.Fatalf("unexpected validation errors: %+v", validation)
	}
	if len(cycles) != 20 || cycles[0] != "2025-05" || cycles[19] != "2026-12" {
		t.Fatalf("unexpected cycles: %v", cycles)
	}
	var total float64
	for _, c := range cells {
		total += c.Amount
	}
	// 2025 months 113,000 + 2026 months 138,000 (matches the original workbook)
	if total != 251000 {
		t.Fatalf("expected total 251000, got %.2f across %d cells", total, len(cells))
	}
}

func TestParseBulkDepositSheet_Validation(t *testing.T) {
	buf := buildSheet(t, [][]interface{}{
		{"Sl", "EMAIL", "2026-01", "2026-02", "Notes"},
		{1, " Alice@Example.com ", "1,000", 0, "ignored"},
		{2, "", 1000},
		{3, "bob@example.com", "abc", -5},
		{},
		{4, "alice@example.com", 500},
		{5, "carol@example.com", nil, 1500.5},
	})
	cells, _, validation, err := service.ParseBulkDepositSheet(buf)
	if err != nil {
		t.Fatal(err)
	}

	if len(cells) != 2 {
		t.Fatalf("expected 2 deposit cells, got %+v", cells)
	}
	if cells[0].Email != "alice@example.com" || cells[0].Cycle != "2026-01" || cells[0].Amount != 1000 {
		t.Errorf("unexpected first cell: %+v", cells[0])
	}
	if cells[1].Email != "carol@example.com" || cells[1].Cycle != "2026-02" || cells[1].Amount != 1500.5 {
		t.Errorf("unexpected second cell: %+v", cells[1])
	}

	wantRows := map[int]string{3: "email is missing", 4: "not a valid amount", 6: "also listed on row 2"}
	for row, frag := range wantRows {
		found := false
		for _, v := range validation {
			if v.Row == row && strings.Contains(v.Message, frag) {
				found = true
			}
		}
		if !found {
			t.Errorf("expected error on row %d containing %q, got %+v", row, frag, validation)
		}
	}
	negFound := false
	for _, v := range validation {
		if v.Row == 4 && strings.Contains(v.Message, "negative") {
			negFound = true
		}
	}
	if !negFound {
		t.Errorf("expected negative amount error on row 4: %+v", validation)
	}
}

func TestParseBulkDepositSheet_BadHeader(t *testing.T) {
	cases := map[string][][]interface{}{
		"no email column":  {{"Name", "2026-01"}, {"x", 1}},
		"no cycle columns": {{"Email", "Jan"}, {"a@b.c", 1}},
		"duplicate cycle":  {{"Email", "2026-01", "2026-01"}, {"a@b.c", 1, 1}},
		"invalid month":    {{"Email", "2026-13"}, {"a@b.c", 1}},
	}
	for name, rows := range cases {
		t.Run(name, func(t *testing.T) {
			if _, _, _, err := service.ParseBulkDepositSheet(buildSheet(t, rows)); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
	if _, _, _, err := service.ParseBulkDepositSheet(strings.NewReader("not an xlsx")); err == nil {
		t.Fatal("expected error for non-xlsx input")
	}
}
