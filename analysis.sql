-- ============================================================
-- Cadence Pricing Screen A/B Test — Analysis
-- Author: Haleema Mahmood
-- ============================================================

USE cadence_test;

-- ------------------------------------------------------------
-- 1. Create tables
-- ------------------------------------------------------------
CREATE TABLE assignments (
    visitor_id  VARCHAR(20),
    variant     CHAR(1),
    assigned_at DATETIME,
    device      VARCHAR(20),
    channel     VARCHAR(20),
    country     VARCHAR(10)
);

CREATE TABLE conversions (
    visitor_id   VARCHAR(20),
    converted_at DATETIME,
    plan         VARCHAR(20),
    amount_usd   DECIMAL(6,2)
);

-- Data loaded via MySQL Workbench Table Data Import Wizard from
-- assignments.csv and conversions.csv.

-- ------------------------------------------------------------
-- 2. Clean the device column (inconsistent capitalisation:
--    Web / web / WEB / Mobile / mobile etc.)
-- ------------------------------------------------------------
SET SQL_SAFE_UPDATES = 0;

UPDATE assignments
SET device = LOWER(device);

-- ------------------------------------------------------------
-- 3. Collapse to one row per visitor: their FIRST assignment.
--    A visitor who returns during the test can get a fresh
--    assignment row — only the earliest one counts.
-- ------------------------------------------------------------
CREATE TABLE first_assignment AS
SELECT a.*
FROM assignments a
JOIN (
    SELECT visitor_id, MIN(assigned_at) AS first_assigned
    FROM assignments
    GROUP BY visitor_id
) b
  ON a.visitor_id = b.visitor_id
  AND a.assigned_at = b.first_assigned;

-- Sanity check: should be fewer (or equal) rows than raw assignments,
-- and equal to COUNT(DISTINCT visitor_id) from assignments.
SELECT COUNT(*) FROM first_assignment;                 -- 58,000
SELECT COUNT(*) FROM assignments;                      -- raw row count (has duplicates)

-- ------------------------------------------------------------
-- 4. Q3 — Unique visitors assigned to each variant
--    (also the denominator for conversion rates)
-- ------------------------------------------------------------
SELECT variant, COUNT(*) AS total_visitors
FROM first_assignment
GROUP BY variant;
-- A = 30,000 | B = 28,000  (NOT a 50/50 split — first red flag)

-- ------------------------------------------------------------
-- 5. Overall conversions inside the test window only.
--    A conversion counts only if:
--      converted_at >= visitor's first assigned_at
--      converted_at <= 2026-06-30 23:59:59
-- ------------------------------------------------------------
SELECT fa.variant, COUNT(DISTINCT fa.visitor_id) AS converted_visitors
FROM first_assignment fa
INNER JOIN conversions c
  ON fa.visitor_id = c.visitor_id
  AND c.converted_at >= fa.assigned_at
  AND c.converted_at <= '2026-06-30 23:59:59'
GROUP BY fa.variant;
-- A = 2,603 | B = 3,342

-- Q1: Overall pp lift
--   A: 2603/30000 = 8.6767%
--   B: 3342/28000 = 11.9357%
--   Lift = 11.9357 - 8.6767 = +3.3pp   <-- the headline number

-- ------------------------------------------------------------
-- 6. Segment by device: mobile
-- ------------------------------------------------------------
SELECT variant, COUNT(*) AS total_visitors
FROM first_assignment
WHERE device = 'mobile'
GROUP BY variant;
-- A = 8,427 | B = 17,366   <-- massive device-mix imbalance

SELECT fa.variant, COUNT(DISTINCT fa.visitor_id) AS converted_visitors
FROM first_assignment fa
INNER JOIN conversions c
  ON fa.visitor_id = c.visitor_id
  AND c.converted_at >= fa.assigned_at
  AND c.converted_at <= '2026-06-30 23:59:59'
WHERE fa.device = 'mobile'
GROUP BY fa.variant;
-- A = 1,562 | B = 2,879

-- Q2: Mobile-only pp lift
--   A mobile: 1562/8427   = 18.5357%
--   B mobile: 2879/17366  = 16.5784%
--   Lift = 16.5784 - 18.5357 = -2.0pp   <-- B LOSES on mobile

-- ------------------------------------------------------------
-- 7. Segment by device: web
-- ------------------------------------------------------------
SELECT variant, COUNT(*) AS total_visitors
FROM first_assignment
WHERE device = 'web'
GROUP BY variant;
-- A = 21,573 | B = 10,634

SELECT fa.variant, COUNT(DISTINCT fa.visitor_id) AS converted_visitors
FROM first_assignment fa
INNER JOIN conversions c
  ON fa.visitor_id = c.visitor_id
  AND c.converted_at >= fa.assigned_at
  AND c.converted_at <= '2026-06-30 23:59:59'
WHERE fa.device = 'web'
GROUP BY fa.variant;
-- A = 1,041 | B = 463

-- Web rates:
--   A web: 1041/21573 = 4.8255%
--   B web: 463/10634  = 4.3540%
--   B also loses on web (-0.47pp)

-- ------------------------------------------------------------
-- Q4: Holding device mix constant, which variant wins?
--   Mobile: A (18.54%) beats B (16.58%)
--   Web:    A (4.83%)  beats B (4.35%)
--   => Variant A wins in both segments.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Q5: Standardise both variants to the SAME (pooled) device mix,
--     then compare.
--   Pooled split across all 58,000 unique visitors:
--     mobile = (8427+17366)/58000 = 25,793/58,000 = 44.47%
--     web    = (21573+10634)/58000 = 32,207/58,000 = 55.53%
--
--   Standardised A = 18.5357%*44.47% + 4.8255%*55.53% = 10.92%
--   Standardised B = 16.5784%*44.47% + 4.3540%*55.53% =  9.79%
--
--   Standardised lift = 9.79 - 10.92 = -1.1pp
--   => Once device mix is equalised, A leads B by ~1.1pp.
-- ------------------------------------------------------------
