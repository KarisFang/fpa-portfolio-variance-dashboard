-- =====================================================================
-- Variance Analysis Query Library — Budget vs. Actual
-- IMPORTANT PATTERN USED THROUGHOUT: aggregate the budget side and the
-- actual side in SEPARATE CTEs first, then join the two pre-aggregated
-- results. Joining budget directly to a many-row fact table and THEN
-- grouping causes a fan-out (the budget figure gets summed once per
-- matching transaction row, wildly overstating it). This bit me during
-- development — see docs/VARIANCE_METHODOLOGY.md for the full story —
-- and every query below is written the safe way on purpose.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. REVENUE VARIANCE BY REGION — FULL YEAR (the headline exec view)
-- ---------------------------------------------------------------------
WITH actual_by_region AS (
    SELECT f.region_id, SUM(f.net_revenue) AS actual_revenue
    FROM fact_sales f JOIN dim_date d ON f.date_key = d.date_key
    WHERE d.year = 2025
    GROUP BY f.region_id
),
budget_by_region AS (
    SELECT region_id, SUM(budgeted_revenue) AS budget_revenue
    FROM budget_revenue
    GROUP BY region_id
)
SELECT
    r.region_name,
    ROUND(b.budget_revenue, 0) AS budget,
    ROUND(a.actual_revenue, 0) AS actual,
    ROUND(a.actual_revenue - b.budget_revenue, 0) AS variance_dollar,
    ROUND(100.0 * (a.actual_revenue - b.budget_revenue) / b.budget_revenue, 1) AS variance_pct,
    CASE WHEN ABS(100.0 * (a.actual_revenue - b.budget_revenue) / b.budget_revenue) > 10
         THEN 'FLAG' ELSE 'OK' END AS exception_flag
FROM budget_by_region b
JOIN actual_by_region a ON a.region_id = b.region_id
JOIN dim_region r ON r.region_id = b.region_id
ORDER BY variance_pct ASC;


-- ---------------------------------------------------------------------
-- 2. REVENUE VARIANCE BY REGION x MONTH — the drill-down view
-- ---------------------------------------------------------------------
WITH actual_by_region_month AS (
    SELECT f.region_id, d.month, SUM(f.net_revenue) AS actual_revenue
    FROM fact_sales f JOIN dim_date d ON f.date_key = d.date_key
    WHERE d.year = 2025
    GROUP BY f.region_id, d.month
)
SELECT
    r.region_name,
    b.month,
    ROUND(b.budgeted_revenue, 0) AS budget,
    ROUND(COALESCE(a.actual_revenue, 0), 0) AS actual,
    ROUND(COALESCE(a.actual_revenue, 0) - b.budgeted_revenue, 0) AS variance_dollar,
    ROUND(100.0 * (COALESCE(a.actual_revenue, 0) - b.budgeted_revenue) / b.budgeted_revenue, 1) AS variance_pct
FROM budget_revenue b
JOIN dim_region r ON r.region_id = b.region_id
LEFT JOIN actual_by_region_month a ON a.region_id = b.region_id AND a.month = b.month
ORDER BY r.region_name, b.month;


-- ---------------------------------------------------------------------
-- 3. OPEX VARIANCE BY DEPARTMENT — FULL YEAR
-- Note the sign convention: for costs, ACTUAL > BUDGET is UNFAVORABLE
-- (positive variance_pct = overspend), the opposite of revenue.
-- ---------------------------------------------------------------------
WITH budget_by_dept AS (
    SELECT department_id, SUM(budgeted_amount) AS budget_amount
    FROM budget_opex GROUP BY department_id
),
actual_by_dept AS (
    SELECT department_id, SUM(actual_amount) AS actual_amount
    FROM actual_opex GROUP BY department_id
)
SELECT
    d.department_name,
    d.cost_center,
    ROUND(b.budget_amount, 0) AS budget,
    ROUND(a.actual_amount, 0) AS actual,
    ROUND(a.actual_amount - b.budget_amount, 0) AS variance_dollar,
    ROUND(100.0 * (a.actual_amount - b.budget_amount) / b.budget_amount, 1) AS variance_pct,
    CASE WHEN 100.0 * (a.actual_amount - b.budget_amount) / b.budget_amount > 5
         THEN 'OVERSPEND - FLAG'
         WHEN 100.0 * (a.actual_amount - b.budget_amount) / b.budget_amount < -5
         THEN 'UNDERSPEND'
         ELSE 'ON PLAN' END AS exception_flag
FROM budget_by_dept b
JOIN actual_by_dept a ON a.department_id = b.department_id
JOIN dim_department d ON d.department_id = b.department_id
ORDER BY variance_pct DESC;


-- ---------------------------------------------------------------------
-- 4. OPEX VARIANCE BY DEPARTMENT x MONTH — drill-down + automatic flag
-- ---------------------------------------------------------------------
SELECT
    d.department_name,
    bo.month,
    ROUND(bo.budgeted_amount, 0) AS budget,
    ROUND(ao.actual_amount, 0) AS actual,
    ROUND(ao.actual_amount - bo.budgeted_amount, 0) AS variance_dollar,
    ROUND(100.0 * (ao.actual_amount - bo.budgeted_amount) / bo.budgeted_amount, 1) AS variance_pct,
    CASE WHEN ABS(100.0 * (ao.actual_amount - bo.budgeted_amount) / bo.budgeted_amount) > 10
         THEN 'FLAG' ELSE '' END AS exception_flag
FROM budget_opex bo
JOIN actual_opex ao ON bo.department_id = ao.department_id AND bo.month = ao.month
JOIN dim_department d ON d.department_id = bo.department_id
ORDER BY d.department_name, bo.month;


-- ---------------------------------------------------------------------
-- 5. COMPANY-WIDE MONTHLY VARIANCE SUMMARY (revenue favorable/unfavorable
-- netted against opex favorable/unfavorable — the single "how are we
-- doing this month" number a CFO actually wants)
-- ---------------------------------------------------------------------
WITH rev_actual AS (
    SELECT d.month, SUM(f.net_revenue) AS actual_revenue
    FROM fact_sales f JOIN dim_date d ON f.date_key = d.date_key WHERE d.year = 2025
    GROUP BY d.month
),
rev_budget AS (
    SELECT month, SUM(budgeted_revenue) AS budget_revenue FROM budget_revenue GROUP BY month
),
opex_actual AS (
    SELECT month, SUM(actual_amount) AS actual_opex FROM actual_opex GROUP BY month
),
opex_budget AS (
    SELECT month, SUM(budgeted_amount) AS budget_opex FROM budget_opex GROUP BY month
)
SELECT
    rb.month,
    ROUND(rb.budget_revenue, 0) AS budget_revenue,
    ROUND(ra.actual_revenue, 0) AS actual_revenue,
    ROUND(ra.actual_revenue - rb.budget_revenue, 0) AS revenue_variance,
    ROUND(ob.budget_opex, 0) AS budget_opex,
    ROUND(oa.actual_opex, 0) AS actual_opex,
    ROUND(ob.budget_opex - oa.actual_opex, 0) AS opex_variance_favorable,
    ROUND((ra.actual_revenue - rb.budget_revenue) + (ob.budget_opex - oa.actual_opex), 0) AS net_variance_vs_plan
FROM rev_budget rb
JOIN rev_actual ra ON ra.month = rb.month
JOIN opex_budget ob ON ob.month = rb.month
JOIN opex_actual oa ON oa.month = rb.month
ORDER BY rb.month;


-- ---------------------------------------------------------------------
-- 6. EXCEPTIONS-ONLY REPORT — every region/department/month combination
-- that breached its variance threshold, ranked by severity. This is
-- the query an automated Slack/email alert would actually run.
-- ---------------------------------------------------------------------
WITH rev_var AS (
    SELECT
        'Revenue' AS area, r.region_name AS unit, b.month,
        100.0 * (COALESCE(a.actual_revenue,0) - b.budgeted_revenue) / b.budgeted_revenue AS variance_pct
    FROM budget_revenue b
    JOIN dim_region r ON r.region_id = b.region_id
    LEFT JOIN (
        SELECT f.region_id, d.month, SUM(f.net_revenue) AS actual_revenue
        FROM fact_sales f JOIN dim_date d ON f.date_key = d.date_key WHERE d.year = 2025
        GROUP BY f.region_id, d.month
    ) a ON a.region_id = b.region_id AND a.month = b.month
),
opex_var AS (
    SELECT
        'OpEx' AS area, d.department_name AS unit, bo.month,
        100.0 * (ao.actual_amount - bo.budgeted_amount) / bo.budgeted_amount AS variance_pct
    FROM budget_opex bo
    JOIN actual_opex ao ON bo.department_id = ao.department_id AND bo.month = ao.month
    JOIN dim_department d ON d.department_id = bo.department_id
)
SELECT area, unit, month, ROUND(variance_pct, 1) AS variance_pct
FROM (SELECT * FROM rev_var UNION ALL SELECT * FROM opex_var)
WHERE ABS(variance_pct) > 10
ORDER BY ABS(variance_pct) DESC;
