# Manufacturing Parts Traceability — Integrity Checks Guide

> **File**: `python/integrity_check.py`
> **Database**: `manufacturing_traceability` (PostgreSQL 18.6, localhost:5432)
> **Script type**: Read-only automated data-validation audit
> **Output**: Terminal summary table + `integrity_report.csv`

---

## 1. Project Purpose

The Manufacturing Parts Traceability project traces Bosch QC-inspected parts
through a simulated manufacturing supply chain stored in a PostgreSQL relational
database. The four tables are:

| Table | Rows | Description |
|---|---|---|
| `raw_materials` | 10 | Supplier material lots |
| `production_lots` | 20 | Production runs on 4 lines |
| `qc_checks` | 1,000 | One row per QC-inspected Bosch part |
| `shipments` | 20 | Outbound shipments to customers |

Because those four tables are linked by foreign keys, any mistake in loading or
updating data can silently break the supply-chain trace. `integrity_check.py`
runs 7 read-only checks automatically so that problems are caught before they
reach a report or dashboard.

---

## 2. Full Python Code (Exact — Not Modified)

```python
"""
Manufacturing Parts Traceability - Automated Data Integrity Checker
-------------------------------------------------------------------
This script runs automated read-only verification checks against the
PostgreSQL manufacturing_traceability database, outputs a clean summary
to the terminal, and exports the results to integrity_report.csv.
"""

import os
import sys
import csv
import psycopg


def get_db_connection():
    """
    STEP 2: OPENING THE DATABASE CONNECTION
    Connects to the local PostgreSQL database using connection parameters.
    The password is read securely from the PGPASSWORD environment variable
    so no sensitive credentials are ever hardcoded in this script.
    """
    password = os.environ.get("PGPASSWORD")
    if not password:
        print("ERROR: Environment variable PGPASSWORD is not set.")
        print("Please set PGPASSWORD before running this script.")
        sys.exit(1)

    connection = psycopg.connect(
        host="localhost",
        port=5432,
        dbname="manufacturing_traceability",
        user="postgres",
        password=password
    )
    return connection


def run_integrity_checks(conn):
    """
    STEP 3: EXECUTING QUERIES & READING RESULTS
    Runs 7 read-only integrity checks; returns list of result dicts.
    """
    results = []

    with conn.cursor() as cur:

        # CHECK 1: Table Row Counts
        tables = ["raw_materials", "production_lots", "qc_checks", "shipments"]
        expected_counts = {
            "raw_materials": 10,
            "production_lots": 20,
            "qc_checks": 1000,
            "shipments": 20
        }
        for table in tables:
            cur.execute(f"SELECT COUNT(*) FROM {table};")
            (count,) = cur.fetchone()
            expected = expected_counts[table]
            status = "PASS" if count == expected else "FAIL"
            results.append({"check_name": f"row_count_{table}",
                             "result_value": str(count), "status": status})

        # CHECK 2: Duplicate Bosch Part IDs
        cur.execute("SELECT COUNT(part_id) - COUNT(DISTINCT part_id) FROM qc_checks;")
        (dup_parts,) = cur.fetchone()
        results.append({"check_name": "duplicate_part_ids",
                         "result_value": str(dup_parts),
                         "status": "PASS" if dup_parts == 0 else "FAIL"})

        # CHECK 3: Invalid QC Responses (must only be 0 or 1)
        cur.execute("SELECT COUNT(*) FROM qc_checks WHERE response NOT IN (0, 1);")
        (invalid_resp,) = cur.fetchone()
        results.append({"check_name": "invalid_qc_responses",
                         "result_value": str(invalid_resp),
                         "status": "PASS" if invalid_resp == 0 else "FAIL"})

        # CHECK 4: Broken Production-to-Raw-Material Links
        cur.execute("""
            SELECT COUNT(*)
            FROM production_lots pl
            LEFT JOIN raw_materials rm ON pl.raw_material_lot_id = rm.raw_material_lot_id
            WHERE rm.raw_material_lot_id IS NULL;
        """)
        (broken_links,) = cur.fetchone()
        results.append({"check_name": "broken_production_to_raw_material_links",
                         "result_value": str(broken_links),
                         "status": "PASS" if broken_links == 0 else "FAIL"})

        # CHECK 5: Shipment Quantity Violations (shipped > produced)
        cur.execute("""
            SELECT COUNT(*)
            FROM shipments s
            JOIN production_lots pl ON s.production_lot_id = pl.production_lot_id
            WHERE s.quantity_shipped > pl.quantity_produced;
        """)
        (qty_violations,) = cur.fetchone()
        results.append({"check_name": "shipment_quantity_violations",
                         "result_value": str(qty_violations),
                         "status": "PASS" if qty_violations == 0 else "FAIL"})

        # CHECK 6: QC Failure Count (informational — always PASS)
        cur.execute("SELECT COUNT(*) FROM qc_checks WHERE response = 1;")
        (qc_failures,) = cur.fetchone()
        results.append({"check_name": "qc_failure_count",
                         "result_value": str(qc_failures), "status": "PASS"})

        # CHECK 7: QC Pass Count (informational — always PASS)
        cur.execute("SELECT COUNT(*) FROM qc_checks WHERE response = 0;")
        (qc_passes,) = cur.fetchone()
        results.append({"check_name": "qc_pass_count",
                         "result_value": str(qc_passes), "status": "PASS"})

    return results


def write_csv_report(results, report_filename="integrity_report.csv"):
    """
    STEP 4: WRITING THE CSV REPORT
    Writes the collected verification findings to a standardized CSV report.
    """
    output_path = os.path.join(os.path.dirname(__file__), report_filename)
    with open(output_path, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["check_name", "result_value", "status"])
        writer.writeheader()
        writer.writerows(results)
    return output_path


def print_terminal_summary(results):
    """Prints a human-readable summary table to the console."""
    print("\n" + "=" * 70)
    print(" MANUFACTURING PARTS TRACEABILITY - DATA INTEGRITY AUDIT")
    print("=" * 70)
    print(f"{'Check Name':<42} | {'Result':<10} | {'Status'}")
    print("-" * 70)
    for r in results:
        status_display = f"[ {r['status']} ]"
        print(f"{r['check_name']:<42} | {r['result_value']:<10} | {status_display}")
    print("=" * 70)


def main():
    print("Connecting to PostgreSQL database: manufacturing_traceability...")
    conn = get_db_connection()
    print("Connected successfully. Running read-only integrity checks...\n")
    try:
        results = run_integrity_checks(conn)
        print_terminal_summary(results)
        report_path = write_csv_report(results)
        print(f"\nAudit report exported to: {report_path}\n")
    finally:
        conn.close()
        print("Database connection closed cleanly.")


if __name__ == "__main__":
    main()
```

---

## 3. The 7 Checks — Full Documentation

The script implements exactly 7 checks. Checks 1–5 are structural data-quality
checks that produce a meaningful PASS or FAIL. Checks 6–7 are informational
summary checks that are always marked PASS — they report QC distribution for
context, not to detect errors.

---

### Check 1 — `row_count_<table>` (runs 4 times)

**Category**: Validation (row count)

**SQL queries**:
```sql
SELECT COUNT(*) FROM raw_materials;
SELECT COUNT(*) FROM production_lots;
SELECT COUNT(*) FROM qc_checks;
SELECT COUNT(*) FROM shipments;
```

**Python logic**:
Loops through a list of 4 table names. For each, executes `SELECT COUNT(*)`,
reads the integer result with `cur.fetchone()`, compares it to a hardcoded
expected value in a Python dictionary, and marks PASS or FAIL.
Produces 4 separate result rows.

**PASS**: Actual count equals expected count exactly.
**FAIL**: Actual count differs from expected count in any direction.

**Expected counts**: `raw_materials`=10, `production_lots`=20,
`qc_checks`=1000, `shipments`=20.

**Plain English**: "Do all four tables contain the exact number of rows
we loaded?" Row count drift usually means an accidental extra insert,
a failed partial load, or an unintended delete.

**Scenario that triggers FAIL**: The data-load script runs twice.
`qc_checks` now has 2,000 rows. Check returns `result_value=2000`, `status=FAIL`.

---

### Check 2 — `duplicate_part_ids`

**Category**: Structural data-quality (uniqueness)

**SQL query**:
```sql
SELECT COUNT(part_id) - COUNT(DISTINCT part_id) FROM qc_checks;
```

**Python logic**: Reads one integer — the difference between total
`part_id` count and unique `part_id` count. If every part appears exactly
once, the difference is 0.

**PASS**: Result = 0.
**FAIL**: Result > 0 (at least one part_id appears more than once).

**Plain English**: Every Bosch part must appear exactly once in `qc_checks`.
A duplicate means the same part has two QC records — an ambiguity that breaks
traceability because there is no authoritative single result for that part.

**Scenario that triggers FAIL**: A migration script imports the same batch of
50 parts twice. Result = 50, status = FAIL.

---

### Check 3 — `invalid_qc_responses`

**Category**: Structural data-quality (domain constraint)

**SQL query**:
```sql
SELECT COUNT(*) FROM qc_checks WHERE response NOT IN (0, 1);
```

**Python logic**: Counts rows where `response` is anything other than 0 or 1.
If the count is 0, all values are valid.

**PASS**: Result = 0.
**FAIL**: Result > 0 (at least one response value is not 0 or 1).

**Plain English**: `response` is a binary QC result — 0 means pass, 1 means
fail. Any other value (e.g. NULL, 2, -1) is invalid and would corrupt QC
analysis by introducing uninterpretable data.

**Scenario that triggers FAIL**: An import script assigns `response = 2` to
rows with missing values in the source file instead of NULL. Those rows
return as FAIL.

---

### Check 4 — `broken_production_to_raw_material_links`

**Category**: Structural data-quality (referential integrity)

**SQL query**:
```sql
SELECT COUNT(*)
FROM production_lots pl
LEFT JOIN raw_materials rm
    ON pl.raw_material_lot_id = rm.raw_material_lot_id
WHERE rm.raw_material_lot_id IS NULL;
```

**Python logic**: Performs a LEFT JOIN from `production_lots` to
`raw_materials`. In a LEFT JOIN, every row from `production_lots` is kept.
Where no matching `raw_materials` row exists, the `rm.*` columns are NULL.
The WHERE filters to only those unmatched rows. COUNT returns the number of
broken links.

**PASS**: Result = 0 (every production lot resolves to a valid raw material lot).
**FAIL**: Result > 0 (one or more production lots reference a non-existent
raw material lot).

**Plain English**: Every production lot must trace back to a real supplier
lot. A broken link means part of the supply chain is untraceable —
you cannot determine who supplied the material for that production run.

**Scenario that triggers FAIL**: A script inserts PL021 with
`raw_material_lot_id = 'RM099'` but RM099 was never inserted into
`raw_materials`. Result = 1, status = FAIL.

---

### Check 5 — `shipment_quantity_violations`

**Category**: Structural data-quality (business rule)

**SQL query**:
```sql
SELECT COUNT(*)
FROM shipments s
JOIN production_lots pl ON s.production_lot_id = pl.production_lot_id
WHERE s.quantity_shipped > pl.quantity_produced;
```

**Python logic**: Joins `shipments` to `production_lots` and counts rows where
shipped quantity exceeds produced quantity.

**PASS**: Result = 0 (no shipment exceeds production).
**FAIL**: Result > 0 (at least one shipment shipped more than was produced).

**Plain English**: A factory cannot ship more parts than it produced. This
check enforces a manufacturing physics rule. A violation usually indicates a
typo, a wrong lot linked to a shipment, or a data-entry error.

**Scenario that triggers FAIL**: SH005 is set to `quantity_shipped = 700`
while PL005 has `quantity_produced = 600`. Result = 1, status = FAIL.
(See Section 5 — SH005 Test Anomaly.)

---

### Check 6 — `qc_failure_count`

**Category**: Informational summary (always PASS)

**SQL query**:
```sql
SELECT COUNT(*) FROM qc_checks WHERE response = 1;
```

**Python logic**: Counts QC failures. Unconditionally sets `status = "PASS"`.

**PASS**: Always.
**FAIL**: Never triggered automatically.

**Plain English**: Reports how many parts failed QC inspection. This is a
summary metric for context, not a structural constraint. The expected value
in this project is 4.

---

### Check 7 — `qc_pass_count`

**Category**: Informational summary (always PASS)

**SQL query**:
```sql
SELECT COUNT(*) FROM qc_checks WHERE response = 0;
```

**Python logic**: Counts QC passes. Unconditionally sets `status = "PASS"`.

**PASS**: Always.
**FAIL**: Never triggered automatically.

**Plain English**: Reports how many parts passed QC inspection. Together with
Check 6, the two counts should sum to the `qc_checks` row count verified in
Check 1. If they do not sum to 1,000, there are NULL `response` values or
other anomalies worth investigating. Expected value: 996.

---

## 4. Verified Output

### `integrity_report.csv` (exact file content)

```
check_name,result_value,status
row_count_raw_materials,10,PASS
row_count_production_lots,20,PASS
row_count_qc_checks,1000,PASS
row_count_shipments,20,PASS
duplicate_part_ids,0,PASS
invalid_qc_responses,0,PASS
broken_production_to_raw_material_links,0,PASS
shipment_quantity_violations,0,PASS
qc_failure_count,4,PASS
qc_pass_count,996,PASS
```

### Terminal output (exact)

```
======================================================================
 MANUFACTURING PARTS TRACEABILITY - DATA INTEGRITY AUDIT
======================================================================
Check Name                               | Result     | Status
----------------------------------------------------------------------
row_count_raw_materials                  | 10         | [ PASS ]
row_count_production_lots                | 20         | [ PASS ]
row_count_qc_checks                      | 1000       | [ PASS ]
row_count_shipments                      | 20         | [ PASS ]
duplicate_part_ids                       | 0          | [ PASS ]
invalid_qc_responses                     | 0          | [ PASS ]
broken_production_to_raw_material_links  | 0          | [ PASS ]
shipment_quantity_violations             | 0          | [ PASS ]
qc_failure_count                         | 4          | [ PASS ]
qc_pass_count                            | 996        | [ PASS ]
======================================================================
```

---

## 5. SH005 Test Anomaly

### What happened

Shipment SH005 was deliberately set to an invalid value to prove that Check 5
(shipment quantity violations) detects the error correctly.

**Step 1 — Deliberate violation**:
```sql
UPDATE shipments SET quantity_shipped = 700 WHERE shipment_id = 'SH005';
```
PL005 (the production lot linked to SH005) has `quantity_produced = 600`.
Setting `quantity_shipped = 700` creates `700 > 600` — a violation of the
business rule that a factory cannot ship more than it produced.

**What the integrity check returned during the violation**:
```
shipment_quantity_violations  | 1  | [ FAIL ]
```

**Step 2 — Correction**:
```sql
UPDATE shipments SET quantity_shipped = 580 WHERE shipment_id = 'SH005';
```
After correction: `580 <= 600` — no violation.

**What the integrity check returned after correction**:
```
shipment_quantity_violations  | 0  | [ PASS ]
```

### CRITICAL DISTINCTION

> This was a **deliberately seeded test anomaly** designed to validate that
> Check 5 works correctly. It was NOT a real manufacturing defect, NOT a
> real Bosch production issue, and NOT evidence of any supplier or factory
> problem.
>
> The Bosch Production Line Performance dataset contains only part IDs and
> binary pass/fail QC responses. All supplier, production-lot, shipment, and
> customer data in this project is **simulated** for portfolio demonstration
> purposes. The SH005 anomaly was an engineered learning exercise within that
> simulated dataset.

---

## 6. Python Functions — Detailed Explanation

### Imports: `os`, `sys`, `csv`, `psycopg`

```python
import os
import sys
import csv
import psycopg
```

| Module | Role |
|---|---|
| `os` | `os.environ.get("PGPASSWORD")` — reads password from shell; `os.path.join()` — builds output file path |
| `sys` | `sys.exit(1)` — stops the script cleanly with error code 1 if PGPASSWORD is missing |
| `csv` | `csv.DictWriter` — writes the results list as a structured CSV file with a header row |
| `psycopg` | Official Python driver for PostgreSQL; provides `psycopg.connect()` |

`os`, `sys`, and `csv` are Python standard-library modules — no installation needed.
`psycopg` is a third-party library installed with: `pip install "psycopg[binary]"`

---

### `get_db_connection()`

```python
def get_db_connection():
    password = os.environ.get("PGPASSWORD")
    if not password:
        print("ERROR: Environment variable PGPASSWORD is not set.")
        print("Please set PGPASSWORD before running this script.")
        sys.exit(1)

    connection = psycopg.connect(
        host="localhost",
        port=5432,
        dbname="manufacturing_traceability",
        user="postgres",
        password=password
    )
    return connection
```

**Step by step**:

1. `os.environ.get("PGPASSWORD")` — looks up the `PGPASSWORD` key in the
   operating system's environment variable dictionary. Returns the value as a
   string, or `None` if the variable was never set.

2. `if not password` — if `None` or empty string, prints two error messages
   and calls `sys.exit(1)`, which stops execution immediately. Exit code 1
   signals an error to any shell or CI/CD pipeline watching the process.

3. `psycopg.connect(...)` — opens a TCP network connection to PostgreSQL
   running on `localhost:5432`, authenticates as user `postgres`, and
   selects database `manufacturing_traceability`. Returns a `Connection`
   object.

4. `return connection` — passes the open connection back to `main()`.

**Why PGPASSWORD and not a hardcoded string?**
If a password is written directly into source code, it is committed to git
and permanently visible in the repository history — to every collaborator,
every fork, and any future leak. An environment variable lives only in the
running shell session; it is never written to any file and never committed.

**How to set it before running**:
```powershell
# Windows PowerShell
$env:PGPASSWORD = "your_password_here"
py integrity_check.py
```
```bash
# Linux / macOS
export PGPASSWORD="your_password_here"
python integrity_check.py
```

---

### `run_integrity_checks(conn)`

```python
def run_integrity_checks(conn):
    results = []
    with conn.cursor() as cur:
        # ... 7 checks ...
    return results
```

**What it does**: Accepts the open connection. Creates an empty list `results`.
Opens a database cursor. Executes 7 SQL queries. Appends one dict per check
to `results`. Returns the full list (10 items: 4 row counts + 6 checks).

**What is a cursor?**
A cursor is a server-side object that manages one SQL statement's execution
and result set. `conn.cursor()` requests one from PostgreSQL.
`cur.execute(sql)` sends the SQL.
`cur.fetchone()` reads the first row of the result back into Python.
Using `with conn.cursor() as cur:` ensures the cursor is automatically
closed when the `with` block ends — even if an exception occurs mid-execution.

**What each result dict looks like**:
```python
{"check_name": "row_count_qc_checks", "result_value": "1000", "status": "PASS"}
```

**`(count,) = cur.fetchone()`** — tuple unpacking.
`fetchone()` returns a tuple like `(1000,)` for a single-column result.
The left side `(count,)` unpacks that tuple, assigning the integer to
the variable `count`. The trailing comma distinguishes a one-element
tuple from a parenthesised expression.

---

### `write_csv_report(results)`

```python
def write_csv_report(results, report_filename="integrity_report.csv"):
    output_path = os.path.join(os.path.dirname(__file__), report_filename)
    with open(output_path, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["check_name", "result_value", "status"])
        writer.writeheader()
        writer.writerows(results)
    return output_path
```

**Step by step**:

1. `os.path.dirname(__file__)` — the directory containing `integrity_check.py`.
   `os.path.join(...)` combines it with `"integrity_report.csv"` so the CSV
   is always written in the same folder as the script, regardless of where
   Python was launched from.

2. `open(..., mode="w", newline="", encoding="utf-8")` — opens (or creates)
   the file for writing. `newline=""` prevents Python on Windows from
   inserting extra blank lines between rows.

3. `csv.DictWriter(f, fieldnames=[...])` — creates a writer that expects
   dictionaries with keys `check_name`, `result_value`, `status`. It maps
   those keys to CSV columns.

4. `writer.writeheader()` — writes the column names as the first row.

5. `writer.writerows(results)` — writes all 10 result dicts as data rows.

6. Returns `output_path` so `main()` can print the file location.

---

### `print_terminal_summary(results)`

```python
def print_terminal_summary(results):
    print("\n" + "=" * 70)
    print(" MANUFACTURING PARTS TRACEABILITY - DATA INTEGRITY AUDIT")
    print("=" * 70)
    print(f"{'Check Name':<42} | {'Result':<10} | {'Status'}")
    print("-" * 70)
    for r in results:
        status_display = f"[ {r['status']} ]"
        print(f"{r['check_name']:<42} | {r['result_value']:<10} | {status_display}")
    print("=" * 70)
```

**What it does**: Prints a bordered, column-aligned table to the terminal
using Python f-strings. `:<42` left-pads the check name to 42 characters.
`:<10` left-pads the result value to 10 characters. `"=" * 70` repeats
`=` 70 times to draw separator lines. This gives the human running the
script an immediate, readable PASS/FAIL summary without needing to open
any file.

---

### `main()`

```python
def main():
    print("Connecting to PostgreSQL database: manufacturing_traceability...")
    conn = get_db_connection()
    print("Connected successfully. Running read-only integrity checks...\n")
    try:
        results = run_integrity_checks(conn)
        print_terminal_summary(results)
        report_path = write_csv_report(results)
        print(f"\nAudit report exported to: {report_path}\n")
    finally:
        conn.close()
        print("Database connection closed cleanly.")
```

`main()` is the orchestrator. It calls all other functions in sequence:
open connection → run checks → print table → write CSV → close connection.

**Why `try / finally`?**
`try` wraps the code that might fail (queries, file write).
`finally` runs unconditionally — whether the `try` block succeeded or raised
an exception. Placing `conn.close()` in `finally` guarantees the database
connection is always released, even if a query crashes halfway. An unclosed
connection wastes server resources and can block other clients from connecting.

---

### `if __name__ == "__main__": main()`

```python
if __name__ == "__main__":
    main()
```

This Python idiom means: only call `main()` when this script is executed
directly (`py integrity_check.py`). If another Python file imports
`integrity_check` as a module, `main()` does not run automatically. This
makes the script both a runnable program and a safely importable module.

---

## 7. End-to-End Execution Flow

```
SHELL
  |
  +-- User sets: $env:PGPASSWORD = "..."
  |
  +-- User runs: py integrity_check.py
        |
        v
    main()
        |
        +-- get_db_connection()
        |       |
        |       +-- os.environ.get("PGPASSWORD")   <- reads from shell env
        |       +-- sys.exit(1) if password missing
        |       +-- psycopg.connect(...)            <- opens TCP connection
        |       +-- returns connection object
        |
        +-- run_integrity_checks(conn)
        |       |
        |       +-- conn.cursor()                   <- opens cursor
        |       |
        |       +-- CHECK 1: SELECT COUNT(*) x4     <- row count per table
        |       +-- CHECK 2: COUNT - COUNT DISTINCT  <- duplicate part IDs
        |       +-- CHECK 3: NOT IN (0, 1)           <- invalid QC responses
        |       +-- CHECK 4: LEFT JOIN IS NULL       <- broken FK links
        |       +-- CHECK 5: shipped > produced      <- quantity violations
        |       +-- CHECK 6: response = 1            <- QC failure count
        |       +-- CHECK 7: response = 0            <- QC pass count
        |       |
        |       +-- cursor closes (with block ends)
        |       +-- returns list of 10 result dicts
        |
        +-- print_terminal_summary(results)
        |       +-- prints formatted table to stdout
        |
        +-- write_csv_report(results)
        |       +-- writes integrity_report.csv
        |
        +-- finally: conn.close()
                +-- connection released cleanly

OUTPUT:
  integrity_report.csv  <- written next to integrity_check.py
  terminal stdout       <- formatted audit table
```

---

## 8. Interview Questions and Answers

**Q1: What does `integrity_check.py` do and why does it exist?**

It connects to the PostgreSQL `manufacturing_traceability` database and runs 7
read-only SQL queries to verify the data is complete, consistent, and follows
business rules. It exists because even well-designed databases can accumulate
errors through bad imports, accidental updates, or temporarily disabled
constraints. Automated checks catch problems before they silently corrupt
dashboard results or supply-chain traces.

---

**Q2: Why is the password in an environment variable rather than in the script?**

Hardcoding a password in source code means it gets committed to git and is
permanently visible in repository history. An environment variable
(`PGPASSWORD`) keeps the password in the shell session only — never written
to any file, never committed, never pushed to GitHub. The script reads it
at runtime with `os.environ.get("PGPASSWORD")`.

---

**Q3: What is a database cursor and why is one used here?**

A cursor is a server-side object that manages the execution of one SQL
statement and the retrieval of its results. `conn.cursor()` creates one.
`cur.execute(sql)` sends the SQL. `cur.fetchone()` reads one result row
back into Python. The `with` statement closes the cursor automatically when
the block ends, releasing server resources even if an exception occurs.

---

**Q4: What is the difference between a structural check and an informational
summary check in this script?**

Checks 1–5 are structural: they test specific conditions that indicate data
problems and produce a meaningful PASS/FAIL based on a threshold (e.g., 0
violations = PASS). Checks 6–7 are informational: they count QC failures
and passes respectively and are unconditionally marked PASS regardless of
the count. Their purpose is to provide context in the audit report, not to
detect errors.

---

**Q5: Explain the SQL for Check 4 (broken production-to-raw-material links).**

```sql
SELECT COUNT(*)
FROM production_lots pl
LEFT JOIN raw_materials rm
    ON pl.raw_material_lot_id = rm.raw_material_lot_id
WHERE rm.raw_material_lot_id IS NULL;
```

A LEFT JOIN keeps every row from `production_lots` even without a match in
`raw_materials`. Where there is no match, all `rm.*` columns are NULL. The
WHERE clause isolates those unmatched rows — production lots that reference
a `raw_material_lot_id` that does not exist. COUNT returns how many such
broken links exist. Result = 0 means all links are valid.

---

**Q6: What is `try / finally` and why is it used to close the connection?**

`try` wraps code that might raise an exception. `finally` runs unconditionally
whether or not an exception occurred. Database connections hold server
resources. If a query crashed without `finally`, Python would exit without
closing the connection, wasting resources and potentially blocking other
clients. Placing `conn.close()` in `finally` makes cleanup unconditional.

---

**Q7: What did the SH005 test anomaly demonstrate?**

SH005 was deliberately set to `quantity_shipped = 700` while its production
lot (PL005) had `quantity_produced = 600`, creating a 700 > 600 violation.
Check 5 detected it and returned `result = 1, status = FAIL`. After
confirming the check worked, SH005 was corrected to 580. This was a
controlled, deliberate test of the integrity mechanism — not a real Bosch
manufacturing issue or supplier defect. All supplier and shipment data in
this project is simulated for portfolio purposes.

---

**Q8: What does `(count,) = cur.fetchone()` mean?**

`cur.fetchone()` returns a Python tuple of the result row's columns. For
`SELECT COUNT(*)`, that tuple is `(1000,)` — one element. The left side
`(count,)` is Python tuple unpacking: it assigns the single value inside
the tuple to the variable `count`. The trailing comma tells Python this is
a one-element tuple, not just parentheses.

---

**Q9: How would you extend the script to alert on failures?**

After `run_integrity_checks()` returns, scan for any dict where
`status == "FAIL"`. If any exist, options include:
- Send an email with Python `smtplib`.
- POST to a Slack webhook using `requests`.
- Write a `failures_report.csv` separately.
- Call `sys.exit(1)` so a CI/CD pipeline treats it as a build failure and
  blocks a deployment.

---

**Q10: Why does Check 2 use `COUNT(part_id) - COUNT(DISTINCT part_id)`
rather than GROUP BY?**

This is the most compact way to count duplicates in a single query pass.
`COUNT(part_id)` counts all non-NULL values. `COUNT(DISTINCT part_id)`
counts unique values. Their difference is the number of "extra" occurrences.
A GROUP BY / HAVING approach would require two query levels and return one
row per duplicate group rather than a single aggregate integer, making it
harder to reduce to a single PASS/FAIL value.
