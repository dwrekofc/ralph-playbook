# Product Specification

## Overview

A CLI tool that reads, transforms, filters, and outputs CSV data. Designed for data processing pipelines.

## Features

### Feature 1: Read CSV

**User Story:** As a user, I want to read a CSV file and display its contents, so that I can inspect data.

**Success Criteria:**
1. Reads CSV from file path argument
2. Handles headers correctly (first row as column names)
3. Displays data in a formatted table to stdout
4. Handles quoted fields with commas inside them

**Eval Rubric:**
- **Pass:** Reads standard CSV files correctly, handles edge cases (quoted fields, empty cells).
- **Fail:** Crashes on valid CSV, misparses quoted fields, or can't read from file path.
- **Weight:** 5

### Feature 2: Filter Rows

**User Story:** As a user, I want to filter rows by column value, so that I can extract relevant data.

**Success Criteria:**
1. `--filter "column=value"` flag filters rows where column equals value
2. `--filter "column>value"` for numeric comparisons
3. Multiple filters can be combined (AND logic)
4. Missing column name shows helpful error

**Eval Rubric:**
- **Pass:** All filter operations work correctly on string and numeric data.
- **Fail:** Filters return wrong results, crash on valid input, or don't combine.
- **Weight:** 5

### Feature 3: Transform Columns

**User Story:** As a user, I want to select, rename, or reorder columns, so that I can reshape data for my needs.

**Success Criteria:**
1. `--select "col1,col2"` outputs only specified columns
2. `--rename "old=new"` renames a column in the output
3. Selected columns appear in the order specified
4. Invalid column name shows helpful error

**Eval Rubric:**
- **Pass:** Select and rename work independently and together. Column order is respected.
- **Fail:** Wrong columns selected, rename doesn't work, or order is wrong.
- **Weight:** 4

### Feature 4: Statistics

**User Story:** As a user, I want to compute basic statistics on numeric columns, so that I can quickly understand my data.

**Success Criteria:**
1. `--stats` flag computes: count, min, max, mean, sum for each numeric column
2. Non-numeric columns show count only
3. Output is a formatted summary table

**Eval Rubric:**
- **Pass:** All stats computed correctly for numeric and non-numeric columns.
- **Fail:** Wrong calculations, crashes on non-numeric data, or missing stats.
- **Weight:** 3

### Feature 5: Output Formats

**User Story:** As a user, I want to output results as CSV, JSON, or table format, so that I can pipe data to other tools.

**Success Criteria:**
1. `--output csv` writes valid CSV to stdout (default)
2. `--output json` writes valid JSON array
3. `--output table` writes formatted ASCII table
4. Output can be redirected to a file

**Eval Rubric:**
- **Pass:** All 3 output formats are valid and parseable by other tools.
- **Fail:** Invalid CSV/JSON output, or table format is unreadable.
- **Weight:** 3

## Cross-Cutting Requirements

- Helpful error messages for all invalid inputs (file not found, bad flags, invalid column names)
- `--help` flag shows usage with examples
- Exit code 0 on success, 1 on error

## Out of Scope

- No GUI or TUI
- No CSV writing/mutation (read-only tool)
- No streaming for very large files (load entire file into memory)
- No network/URL input (local files only)
