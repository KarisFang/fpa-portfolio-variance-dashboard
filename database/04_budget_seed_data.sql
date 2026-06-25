-- =====================================================================
-- Budget vs. Actual seed data — FY2025
-- Revenue budget = naive +10% YoY plan applied uniformly to every
-- region (i.e. the plan did NOT foresee the Greater Asia decline or
-- North America's outperformance — that gap IS the variance story).
-- OpEx budget/actual is built with five distinct, realistic variance
-- patterns by department (see docs/VARIANCE_METHODOLOGY.md).
-- =====================================================================

-- ---------------------------------------------------------------------
-- BUDGET_REVENUE: FY2025 plan = FY2024 actual monthly revenue x 1.10,
-- by region. Pulled straight from the actuals already in fact_sales.
-- ---------------------------------------------------------------------
INSERT INTO budget_revenue (region_id, year, month, budgeted_revenue)
SELECT
    f.region_id,
    2025 AS year,
    d.month,
    ROUND(SUM(f.net_revenue) * 1.10, 2) AS budgeted_revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2024
GROUP BY f.region_id, d.month;

-- ---------------------------------------------------------------------
-- DIM_DEPARTMENT
-- ---------------------------------------------------------------------
INSERT INTO dim_department (department_id, department_name, cost_center) VALUES
(1, 'Sales & Marketing', 'CC-100'),
(2, 'Research & Development', 'CC-200'),
(3, 'General & Administrative', 'CC-300'),
(4, 'Operations & Logistics', 'CC-400'),
(5, 'Customer Support', 'CC-500');

-- ---------------------------------------------------------------------
-- BUDGET_OPEX & ACTUAL_OPEX — FY2025, 5 departments x 12 months
-- Story per department:
--   Sales & Marketing : budget ramps for planned Q4 push; actual blows
--                        through budget in Nov/Dec (campaign overspend)
--   R&D                : tightly managed, small noise around budget
--   G&A                 : flat budget, but actual creeps up every month
--                        (classic "nobody noticed" overspend pattern)
--   Operations & Logistics : budget scales with planned volume; actual
--                        spikes in Nov/Dec (holiday shipping/logistics
--                        surge), favorable the rest of the year
--   Customer Support    : consistently favorable (automation savings)
-- ---------------------------------------------------------------------
WITH RECURSIVE month_seq(month) AS (
    SELECT 1 UNION ALL SELECT month + 1 FROM month_seq WHERE month < 12
)
INSERT INTO budget_opex (department_id, year, month, budgeted_amount)
SELECT 1, 2025, month, ROUND(170000 + month * 4500 + (CASE WHEN month >= 10 THEN 25000 ELSE 0 END), 2) FROM month_seq
UNION ALL
SELECT 2, 2025, month, ROUND(120000 + month * 800, 2) FROM month_seq
UNION ALL
SELECT 3, 2025, month, 90000.00 FROM month_seq
UNION ALL
SELECT 4, 2025, month, ROUND(125000 + month * 1800 + (CASE WHEN month >= 10 THEN 15000 ELSE 0 END), 2) FROM month_seq
UNION ALL
SELECT 5, 2025, month, ROUND(70000 + month * 500, 2) FROM month_seq;

WITH RECURSIVE month_seq(month) AS (
    SELECT 1 UNION ALL SELECT month + 1 FROM month_seq WHERE month < 12
)
INSERT INTO actual_opex (department_id, year, month, actual_amount)
SELECT
    1, 2025, month,
    ROUND((170000 + month * 4500 + (CASE WHEN month >= 10 THEN 25000 ELSE 0 END))
          * (CASE WHEN month IN (11,12) THEN 1.32 WHEN month = 10 THEN 1.12 ELSE 1.015 END), 2)
FROM month_seq
UNION ALL
SELECT
    2, 2025, month,
    ROUND((120000 + month * 800) * (0.97 + (ABS(RANDOM()) % 60) / 1000.0), 2)
FROM month_seq
UNION ALL
SELECT
    3, 2025, month,
    ROUND(90000 * (1.0 + 0.018 * month), 2)
FROM month_seq
UNION ALL
SELECT
    4, 2025, month,
    ROUND((125000 + month * 1800 + (CASE WHEN month >= 10 THEN 15000 ELSE 0 END))
          * (CASE WHEN month IN (11,12) THEN 1.28 WHEN month = 10 THEN 1.08 ELSE 0.94 END), 2)
FROM month_seq
UNION ALL
SELECT
    5, 2025, month,
    ROUND((70000 + month * 500) * 0.90, 2)
FROM month_seq;
