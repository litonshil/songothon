package migrations

import _ "embed"

//go:embed 000001_init_schema.up.sql
var SchemaSQL string

//go:embed 000002_requirements.up.sql
var RequirementsSQL string

//go:embed seed.sql
var SeedSQL string
