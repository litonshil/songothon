package migrations

import _ "embed"

//go:embed 000001_init_schema.up.sql
var SchemaSQL string

//go:embed 000002_requirements.up.sql
var RequirementsSQL string

//go:embed 000003_expenses.up.sql
var ExpensesSQL string

//go:embed 000004_incomes.up.sql
var IncomesSQL string

//go:embed seed.sql
var SeedSQL string
