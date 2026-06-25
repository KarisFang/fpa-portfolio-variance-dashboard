-- =====================================================================
-- Variance Analysis Schema — extends the Project 2 sales database with
-- budget tables (revenue, by region) and a department OpEx budget vs.
-- actual table. This is what turns a sales database into a budget-vs-
-- actual variance dashboard.
-- =====================================================================

DROP TABLE IF EXISTS budget_revenue;
DROP TABLE IF EXISTS dim_department;
DROP TABLE IF EXISTS budget_opex;
DROP TABLE IF EXISTS actual_opex;

-- ---------------------------------------------------------------------
-- BUDGET_REVENUE: the FY2025 revenue plan, set by region/month BEFORE
-- the year started (i.e. it does NOT know about the Greater Asia
-- decline that actually happened — that's the whole point of a
-- variance analysis).
-- ---------------------------------------------------------------------
CREATE TABLE budget_revenue (
    budget_id       INTEGER PRIMARY KEY,
    region_id       INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    budgeted_revenue REAL NOT NULL,
    FOREIGN KEY (region_id) REFERENCES dim_region(region_id)
);
CREATE INDEX idx_budget_revenue ON budget_revenue(region_id, year, month);

-- ---------------------------------------------------------------------
-- DIM_DEPARTMENT
-- ---------------------------------------------------------------------
CREATE TABLE dim_department (
    department_id   INTEGER PRIMARY KEY,
    department_name TEXT NOT NULL,
    cost_center     TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- BUDGET_OPEX / ACTUAL_OPEX: monthly operating expense plan vs. actual
-- by department for FY2025.
-- ---------------------------------------------------------------------
CREATE TABLE budget_opex (
    budget_id       INTEGER PRIMARY KEY,
    department_id   INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    budgeted_amount REAL NOT NULL,
    FOREIGN KEY (department_id) REFERENCES dim_department(department_id)
);

CREATE TABLE actual_opex (
    actual_id       INTEGER PRIMARY KEY,
    department_id   INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    actual_amount   REAL NOT NULL,
    FOREIGN KEY (department_id) REFERENCES dim_department(department_id)
);
CREATE INDEX idx_budget_opex ON budget_opex(department_id, year, month);
CREATE INDEX idx_actual_opex ON actual_opex(department_id, year, month);
