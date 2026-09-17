-- =============================================================================
-- Manufacturing Parts Traceability Dashboard — Reference Data Load
-- =============================================================================
-- Loads raw_materials, production_lots, and shipments reference data.
-- The qc_checks data is loaded separately from bosch_sample.csv via the
-- Python script or from the full insert_qc.sql (not included in this repo
-- due to its generated nature; regenerate using prepare_qc_insert.py).
-- =============================================================================

BEGIN;

-- =============================================================================
-- raw_materials (10 supplier lots)
-- =============================================================================
INSERT INTO raw_materials (raw_material_lot_id, supplier_name, material_type, received_date, quantity_kg) VALUES
('RM001', 'ArcelorMittal Steel',       'Carbon Steel Bar 1045',         '2026-07-25', 5000),
('RM002', 'Thyssenkrupp Materials',    'High-Strength Low-Alloy Steel', '2026-07-26', 4800),
('RM003', 'Alcoa Aluminum',            'Aluminum Alloy 6061-T6',        '2026-07-27', 3200),
('RM004', 'BASF Engineering Plastics', 'Nylon PA66 GF30',               '2026-07-28', 1500),
('RM005', 'Nippon Steel Corp',         'Stainless Steel 316L',          '2026-07-29', 4200),
('RM006', 'POSCO Metals',              'Cold-Rolled Steel Coil',        '2026-07-30', 5500),
('RM007', 'Sandvik Materials Tech',    'Machining Tool Steel D2',       '2026-07-31', 2800),
('RM008', 'DuPont Performance Mats',   'PTFE Composite Sheet',          '2026-08-01', 900),
('RM009', 'Nucor Steel Group',         'Alloy Steel Sheet 4140',        '2026-08-02', 4600),
('RM010', 'Covestro Polymers',         'Polycarbonate Blend PC/ABS',    '2026-08-03', 1200);

-- =============================================================================
-- production_lots (20 lots across 4 lines: L0, L1, L2, L3)
-- =============================================================================
INSERT INTO production_lots (production_lot_id, raw_material_lot_id, production_date, production_line, quantity_produced) VALUES
('PL001', 'RM001', '2026-08-03', 'L0', 500),
('PL002', 'RM002', '2026-08-04', 'L1', 480),
('PL003', 'RM003', '2026-08-05', 'L2', 520),
('PL004', 'RM004', '2026-08-06', 'L3', 490),
('PL005', 'RM005', '2026-08-07', 'L0', 600),
('PL006', 'RM006', '2026-08-08', 'L1', 550),
('PL007', 'RM007', '2026-08-09', 'L2', 510),
('PL008', 'RM008', '2026-08-10', 'L3', 470),
('PL009', 'RM009', '2026-08-11', 'L0', 530),
('PL010', 'RM010', '2026-08-12', 'L1', 495),
('PL011', 'RM006', '2026-08-13', 'L2', 515),
('PL012', 'RM001', '2026-08-14', 'L3', 505),
('PL013', 'RM007', '2026-08-15', 'L0', 525),
('PL014', 'RM007', '2026-08-16', 'L2', 540),
('PL015', 'RM002', '2026-08-17', 'L1', 485),
('PL016', 'RM005', '2026-08-18', 'L3', 510),
('PL017', 'RM003', '2026-08-19', 'L0', 500),
('PL018', 'RM009', '2026-08-20', 'L1', 520),
('PL019', 'RM004', '2026-08-21', 'L2', 490),
('PL020', 'RM010', '2026-08-26', 'L3', 480);

-- =============================================================================
-- shipments (20 shipments — one per production lot)
-- =============================================================================
INSERT INTO shipments (shipment_id, production_lot_id, customer_name, quantity_shipped) VALUES
('SH001', 'PL001', 'BMW Manufacturing',          480),
('SH002', 'PL002', 'Volkswagen Group',           460),
('SH003', 'PL003', 'Toyota Motor Corp',          500),
('SH004', 'PL004', 'Mercedes-Benz AG',           470),
('SH005', 'PL005', 'Ford Motor Company',         580),
('SH006', 'PL006', 'General Motors',             530),
('SH007', 'PL007', 'Honda Manufacturing',        490),
('SH008', 'PL008', 'Stellantis',                450),
('SH009', 'PL009', 'Hyundai Motor Group',        510),
('SH010', 'PL010', 'Renault Group',              475),
('SH011', 'PL011', 'Volvo Cars',                 495),
('SH012', 'PL012', 'Daimler Trucks',             485),
('SH013', 'PL013', 'Audi AG',                    505),
('SH014', 'PL014', 'Porsche AG',                 520),
('SH015', 'PL015', 'Subaru Corporation',         465),
('SH016', 'PL016', 'Mazda Motor Corp',           490),
('SH017', 'PL017', 'Nissan Motor Co',            480),
('SH018', 'PL018', 'Kia Motors',                 500),
('SH019', 'PL019', 'Mitsubishi Motors',          470),
('SH020', 'PL020', 'Suzuki Motor Corp',          460);

COMMIT;
