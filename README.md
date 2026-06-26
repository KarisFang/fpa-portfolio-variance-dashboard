# Budget vs. Actual Variance Dashboard — SQL + Excel + Power BI

A budget-vs-actual variance analysis for "Meridian Retail Co." (the same fictional company from Project 2),
covering both **revenue variance by region** and **OpEx variance by department**, with automatic exception
flagging and drill-downs.

**Portfolio project #3 of 3** mapping directly to FP&A job descriptions.
([Project 1: 3-statement model](https://github.com/KarisFang/fpa-portfolio-3-statement-model) ·
[Project 2: automated reporting pipeline](https://github.com/KarisFang/fpa-portfolio-reporting-pipeline))

## See it live

**[→ Open the interactive dashboard](https://karisfang.github.io/fpa-portfolio-variance-dashboard/)** — no Power BI
account or download needed, just a browser. The two heatmap grids (region × month, department × month) use the
exact same red/yellow/green logic as the Excel conditional formatting, just rendered natively in HTML/CSS.
Hosted free on GitHub Pages from `docs/index.html`.

**A note on Power BI:** same situation as Project 2 — built on a MacBook, no Windows machine, no work/school
email for the free Power BI tenant, limited space to run one through a VM. `powerbi/POWER_BI_BUILD_GUIDE.md`
documents my actual thought process instead: the data model, every DAX measure, and the drill-through report
layout, written precisely enough to execute the moment I have Windows access. The HTML dashboard above is
what replaces it for now.

## The headline finding

The FY2025 plan assumed a uniform **+10% revenue growth** across every region. It didn't play out that way:

| Region | Budget | Actual | Variance |
|---|---:|---:|---:|
| Greater Asia | $5.48M | $3.10M | **-43.5%** |
| Europe | $5.09M | $4.55M | -10.6% |
| APAC | $2.75M | $2.57M | -6.4% |
| North America | $6.30M | $7.09M | **+12.6%** |
| Latin America | $1.20M | $1.41M | +17.2% |

Greater Asia's miss alone offsets most of North America's and Latin America's combined outperformance — the
exact kind of insight a flat company-wide growth number hides and a regional variance breakdown reveals.

On the cost side, **General & Administrative** overspend never exceeded ~2% in any single month but crept
up every month all year, reaching **+11.7%** by year-end — invisible to a "did we blow the monthly budget"
check, visible immediately in a YTD trend.

## What's in this repo

| Folder | Contents |
|---|---|
| `database/` | Extends the Project 2 SQLite database with `budget_revenue`, `dim_department`, `budget_opex`, `actual_opex` tables |
| `sql/variance_queries.sql` | 6 queries: regional/department variance (annual + monthly drill-down), automatic exception flagging, a combined revenue+OpEx "how are we doing this month" view, and a single exceptions-only report |
| `excel/Variance_Dashboard.xlsx` | KPI cards, budget-vs-actual bar charts, and two full variance grids with **live conditional formatting** (3-color scales + rule-based red/green flagging) |
| `docs/index.html` | A standalone interactive dashboard (Chart.js budget-vs-actual bars + two HTML/CSS conditional-formatting heatmap grids, region×month and department×month), hosted free on GitHub Pages |
| `powerbi/POWER_BI_BUILD_GUIDE.md` | DAX variance measures, conditional-formatting rules, and step-by-step **drill-through** setup (Power BI's actual answer to "drill down by region/department") |
| `architecture/architecture_diagram.svg` | Pipeline architecture |
| `docs/VARIANCE_METHODOLOGY.md` | How the budget was built, a real SQL fan-out bug hit during development (and the fix), and an honest discussion of where a single variance threshold creates false-positive noise |

## A bug worth knowing about

Every variance query in this project aggregates the budget side and the actual side **separately**, then
joins the two pre-aggregated results — not because that's the "clever" way to write it, but because joining
budget directly to the many-row transaction table and grouping afterward caused a real fan-out bug during
development that inflated budget totals by 100x+. Full writeup in `docs/VARIANCE_METHODOLOGY.md`.

## Rebuilding it from scratch

```bash
cd database
sqlite3 variance.db < 01_base_schema.sql
sqlite3 variance.db < 02_base_seed_data.sql
sqlite3 variance.db < 03_variance_schema.sql
sqlite3 variance.db < 04_budget_seed_data.sql

# re-run the exports in sql/variance_queries.sql via sqlite3 -header -csv ...

cd ../excel
python3 build_variance_dashboard.py   # only Python use: writing the .xlsx file, not the analysis
```

---
Built by Karis Fang as a portfolio project for FP&A roles.
