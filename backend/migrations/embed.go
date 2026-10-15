package migrations

import _ "embed"

//go:embed 000001_create_initial_schema.up.sql
var SchemaSQL string

//go:embed seed.sql
var SeedSQL string
