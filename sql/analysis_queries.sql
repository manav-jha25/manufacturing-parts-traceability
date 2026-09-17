-- =============================================================================
-- Manufacturing Parts Traceability Dashboard — Analysis Queries
-- =============================================================================
-- READ-ONLY queries demonstrating SQL traceability and defect analysis.
-- Run against: manufacturing_traceability database.
-- =============================================================================


-- =============================================================================
-- QUERY 1: Trace a single part through the full supply chain
-- Replace :part_id with the desired Bosch part ID (e.g. 4)
-- =============================================================================
SELECT
    qc.part_id,
    pl.production_lot_id,
    pl.production_date,
    pl.production_line,
    rm.raw_material_lot_id,
    rm.supplier_name,
    rm.material_type,
    qc.response,
    qc.defect_code,
    s.shipment_id,
    s.customer_name,
    s.quantity_shipped
FROM qc_checks qc
JOIN production_lots pl ON qc.production_lot_id = pl.production_lot_id
JOIN raw_materials rm   ON pl.raw_material_lot_id = rm.raw_material_lot_id
JOIN shipments s        ON pl.production_lot_id   = s.production_lot_id
WHERE qc.part_id = 4
ORDER BY qc.part_id;


-- =============================================================================
-- QUERY 2: All failed Bosch parts with full supplier and customer trace
-- (response = 1 means QC failure)
-- =============================================================================
SELECT
    qc.part_id,
    qc.production_lot_id,
    rm.raw_material_lot_id,
    rm.supplier_name,
    rm.material_type,
    s.shipment_id,
    s.customer_name,
    s.quantity_shipped
FROM qc_checks qc
JOIN production_lots pl ON qc.production_lot_id = pl.production_lot_id
JOIN raw_materials rm   ON pl.raw_material_lot_id = rm.raw_material_lot_id
JOIN shipments s        ON pl.production_lot_id   = s.production_lot_id
WHERE qc.response = 1
ORDER BY qc.part_id;


-- =============================================================================
-- QUERY 3: Defect rate by production line
-- =============================================================================
SELECT
    pl.production_line,
    COUNT(*)                                                           AS parts_inspected,
    SUM(CASE WHEN qc.response = 1 THEN 1 ELSE 0 END)                  AS failures,
    ROUND(
        100.0 * SUM(CASE WHEN qc.response = 1 THEN 1 ELSE 0 END)
              / COUNT(*),
        2
    )                                                                  AS defect_rate_percent
FROM qc_checks qc
JOIN production_lots pl ON qc.production_lot_id = pl.production_lot_id
GROUP BY pl.production_line
ORDER BY pl.production_line;


-- =============================================================================
-- QUERY 4: Failures by supplier (simulated genealogy)
-- NOTE: supplier relationships are simulated, not derived from Bosch source data.
-- =============================================================================
SELECT
    rm.supplier_name,
    COUNT(*)  AS failed_parts
FROM qc_checks qc
JOIN production_lots pl ON qc.production_lot_id = pl.production_lot_id
JOIN raw_materials rm   ON pl.raw_material_lot_id = rm.raw_material_lot_id
WHERE qc.response = 1
GROUP BY rm.supplier_name
ORDER BY failed_parts DESC;


-- =============================================================================
-- QUERY 5: Production vs shipment comparison (shipment variance)
-- =============================================================================
SELECT
    pl.production_lot_id,
    pl.production_line,
    pl.quantity_produced,
    s.quantity_shipped,
    pl.quantity_produced - s.quantity_shipped AS retained_units
FROM production_lots pl
JOIN shipments s ON pl.production_lot_id = s.production_lot_id
ORDER BY retained_units DESC;


-- =============================================================================
-- QUERY 6: Full traceability_view sample (first 10 rows)
-- =============================================================================
SELECT * FROM traceability_view LIMIT 10;
