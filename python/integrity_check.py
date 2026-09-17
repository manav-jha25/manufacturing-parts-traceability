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

# -----------------------------------------------------------------------------
# STEP 1: IMPORTING PSYCOPG
# We import psycopg, the official PostgreSQL database driver for Python.
# -----------------------------------------------------------------------------
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
    Runs 7 read-only integrity checks and collects (check_name, result_value, status).
    """
    results = []

    # Open a database cursor to execute SQL statements
    with conn.cursor() as cur:

        # ---------------------------------------------------------------------
        # CHECK 1: Table Row Counts
        # ---------------------------------------------------------------------
        tables = ["raw_materials", "production_lots", "qc_checks", "shipments"]
        expected_counts = {
            "raw_materials": 10,
            "production_lots": 20,
            "qc_checks": 1000,
            "shipments": 20
        }

        for table in tables:
            # Executing a query
            cur.execute(f"SELECT COUNT(*) FROM {table};")
            # Reading the result
            (count,) = cur.fetchone()
            expected = expected_counts[table]
            status = "PASS" if count == expected else "FAIL"
            results.append({
                "check_name": f"row_count_{table}",
                "result_value": str(count),
                "status": status
            })

        # ---------------------------------------------------------------------
        # CHECK 2: Duplicate Bosch Part IDs
        # ---------------------------------------------------------------------
        cur.execute("SELECT COUNT(part_id) - COUNT(DISTINCT part_id) FROM qc_checks;")
        (dup_parts,) = cur.fetchone()
        results.append({
            "check_name": "duplicate_part_ids",
            "result_value": str(dup_parts),
            "status": "PASS" if dup_parts == 0 else "FAIL"
        })

        # ---------------------------------------------------------------------
        # CHECK 3: Invalid QC Responses (must only be 0 or 1)
        # ---------------------------------------------------------------------
        cur.execute("SELECT COUNT(*) FROM qc_checks WHERE response NOT IN (0, 1);")
        (invalid_resp,) = cur.fetchone()
        results.append({
            "check_name": "invalid_qc_responses",
            "result_value": str(invalid_resp),
            "status": "PASS" if invalid_resp == 0 else "FAIL"
        })

        # ---------------------------------------------------------------------
        # CHECK 4: Broken Production-to-Raw-Material Links
        # ---------------------------------------------------------------------
        cur.execute("""
            SELECT COUNT(*) 
            FROM production_lots pl
            LEFT JOIN raw_materials rm ON pl.raw_material_lot_id = rm.raw_material_lot_id
            WHERE rm.raw_material_lot_id IS NULL;
        """)
        (broken_links,) = cur.fetchone()
        results.append({
            "check_name": "broken_production_to_raw_material_links",
            "result_value": str(broken_links),
            "status": "PASS" if broken_links == 0 else "FAIL"
        })

        # ---------------------------------------------------------------------
        # CHECK 5: Shipment Quantity Violations (shipped > produced)
        # ---------------------------------------------------------------------
        cur.execute("""
            SELECT COUNT(*) 
            FROM shipments s
            JOIN production_lots pl ON s.production_lot_id = pl.production_lot_id
            WHERE s.quantity_shipped > pl.quantity_produced;
        """)
        (qty_violations,) = cur.fetchone()
        results.append({
            "check_name": "shipment_quantity_violations",
            "result_value": str(qty_violations),
            "status": "PASS" if qty_violations == 0 else "FAIL"
        })

        # ---------------------------------------------------------------------
        # CHECK 6: QC Failure Count (response = 1)
        # ---------------------------------------------------------------------
        cur.execute("SELECT COUNT(*) FROM qc_checks WHERE response = 1;")
        (qc_failures,) = cur.fetchone()
        results.append({
            "check_name": "qc_failure_count",
            "result_value": str(qc_failures),
            "status": "PASS"
        })

        # ---------------------------------------------------------------------
        # CHECK 7: QC Pass Count (response = 0)
        # ---------------------------------------------------------------------
        cur.execute("SELECT COUNT(*) FROM qc_checks WHERE response = 0;")
        (qc_passes,) = cur.fetchone()
        results.append({
            "check_name": "qc_pass_count",
            "result_value": str(qc_passes),
            "status": "PASS"
        })

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
    """
    Prints a human-readable summary table to the console.
    """
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
    
    # Open connection
    conn = get_db_connection()
    print("Connected successfully. Running read-only integrity checks...\n")

    try:
        # Execute checks
        results = run_integrity_checks(conn)

        # Print human-readable summary
        print_terminal_summary(results)

        # Write CSV report
        report_path = write_csv_report(results)
        print(f"\nAudit report exported to: {report_path}\n")

    finally:
        # ---------------------------------------------------------------------
        # STEP 5: CLOSING THE CONNECTION
        # Always close the connection in a finally block to release resources.
        # ---------------------------------------------------------------------
        conn.close()
        print("Database connection closed cleanly.")


if __name__ == "__main__":
    main()
