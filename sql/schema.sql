-- =============================================================================
-- Manufacturing Parts Traceability Dashboard — Database Schema
-- =============================================================================
-- Database: manufacturing_traceability
-- PostgreSQL 18.6+
-- Run this file to create the four relational tables and the traceability view.
-- =============================================================================

-- Create database (run separately as superuser if needed):
-- CREATE DATABASE manufacturing_traceability;

-- Connect to the database:
-- \c manufacturing_traceability


-- =============================================================================
-- TABLE 1: raw_materials
-- Stores raw material lots received from external suppliers.
-- =============================================================================
CREATE TABLE IF NOT EXISTS raw_materials (
    raw_material_lot_id VARCHAR(10)  PRIMARY KEY,
    supplier_name       VARCHAR(100) NOT NULL,
    material_type       VARCHAR(100) NOT NULL,
    received_date       DATE         NOT NULL,
    quantity_kg         INTEGER      NOT NULL CHECK (quantity_kg > 0)
);


-- =============================================================================
-- TABLE 2: production_lots
-- Stores production runs. Each lot uses one raw material lot
-- and runs on one production line.
-- =============================================================================
CREATE TABLE IF NOT EXISTS production_lots (
    production_lot_id   VARCHAR(10)  PRIMARY KEY,
    raw_material_lot_id VARCHAR(10)  NOT NULL
                            REFERENCES raw_materials(raw_material_lot_id),
    production_date     DATE         NOT NULL,
    production_line     VARCHAR(10)  NOT NULL,
    quantity_produced   INTEGER      NOT NULL CHECK (quantity_produced > 0)
);


-- =============================================================================
-- TABLE 3: qc_checks
-- One row per inspected part. Bosch Production Line Performance part IDs
-- and pass/fail responses (response=0 pass, response=1 fail) are the source data.
-- Production lot assignment was simulated for this portfolio project.
-- =============================================================================
CREATE TABLE IF NOT EXISTS qc_checks (
    qc_check_id         VARCHAR(10)  PRIMARY KEY,
    production_lot_id   VARCHAR(10)  NOT NULL
                            REFERENCES production_lots(production_lot_id),
    part_id             BIGINT       NOT NULL UNIQUE,
    response            INTEGER      NOT NULL CHECK (response IN (0, 1)),
    inspection_date     DATE         NOT NULL,
    defect_code         VARCHAR(50)
);


-- =============================================================================
-- TABLE 4: shipments
-- Stores outbound shipments of finished parts to customers.
-- One shipment per production lot.
-- =============================================================================
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id         VARCHAR(10)  PRIMARY KEY,
    production_lot_id   VARCHAR(10)  NOT NULL
                            REFERENCES production_lots(production_lot_id),
    customer_name       VARCHAR(100) NOT NULL,
    quantity_shipped    INTEGER      NOT NULL CHECK (quantity_shipped > 0)
);


-- =============================================================================
-- VIEW: traceability_view
-- Flat join of all four tables for Power BI and ad-hoc analysis.
-- 1,000 rows, one row per QC-inspected part.
-- =============================================================================
CREATE OR REPLACE VIEW traceability_view AS
SELECT
    qc.part_id,
    pl.production_lot_id,
    pl.production_date,
    pl.production_line,
    rm.raw_material_lot_id,
    rm.supplier_name,
    rm.material_type,
    pl.quantity_produced,
    qc.response,
    qc.inspection_date,
    qc.defect_code,
    s.shipment_id,
    s.customer_name,
    s.quantity_shipped
FROM qc_checks qc
JOIN production_lots pl
    ON qc.production_lot_id = pl.production_lot_id
JOIN raw_materials rm
    ON pl.raw_material_lot_id = rm.raw_material_lot_id
JOIN shipments s
    ON pl.production_lot_id = s.production_lot_id
ORDER BY qc.part_id;
