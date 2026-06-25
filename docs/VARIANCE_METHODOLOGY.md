# Variance Analysis Methodology

## How the budget was built (and why it's deliberately "wrong")

The FY2025 revenue budget (`budget_revenue`) is FY2024 actual monthly revenue **x a flat +10% for every
region**, set as if planned before the year started. That's not a contrived setup for the demo — it's how a
lot of real annual planning actually works: a single top-down growth assumption gets applied uniformly
across the business because building a fully bottoms-up, region-by-region plan is expensive, and the
prior year's actuals are the best available baseline. The variance analysis is what exposes where that
simplification broke down: Greater Asia was budgeted for +10% and delivered **-37.8%** (a swing the
uniform-growth plan had no way to see coming), while North America was budgeted the same +10% and delivered
**+23.8%**. The point of a variance dashboard isn't to say "the plan was wrong" — it's to find out *where*
and *by how much*, fast enough to act on it.

The FY2025 OpEx budget (`budget_opex`) is built department-by-department with five distinct, intentional
patterns (see code comments in `database/04_budget_seed_data.sql` for the exact formulas):

| Department | Pattern | Why it's a realistic scenario |
|---|---|---|
| Sales & Marketing | On-plan most of the year, blows through budget in Oct-Dec | A real Q4 campaign overspend — the kind of thing that's easy to approve in November and easy to regret in the January variance review |
| Research & Development | Small random noise around budget all year | Well-managed, predictable cost center — the "nothing to see here" baseline |
| General & Administrative | Flat budget, but actual creeps up ~1.8%/month, every month | The most dangerous variance pattern: never large enough in any single month to trigger an alert, but compounds to +11.7% by year-end |
| Operations & Logistics | Favorable (efficient) most months, sharp Oct-Dec spike | Holiday shipping/logistics volume surge — a cost that scales with the same Q4 revenue seasonality from Project 2 |
| Customer Support | Consistently ~10% under budget | Automation/efficiency gains — the "good news" variance that's easy to forget to report because nobody complains about good news |

## A real bug, worth understanding rather than hiding

The first version of every variance query in this project joined the budget table directly to the
transaction-level fact table, then grouped to get a total. That's wrong, and it produced budget figures
inflated by 100-200x. The mechanism: `budget_revenue` has exactly one row per region/month, but
`fact_sales` has hundreds of transaction rows per region/month. A direct join between them is a one-to-many
join — every one of those hundreds of fact rows gets matched against the *same* single budget row, so
`SUM(budget_amount)` after grouping adds that one budget number in hundreds of times over.

**The fix, used in every query in `sql/variance_queries.sql`:** aggregate each side completely on its own
(budget in one CTE, actual in another, each already at the region/month grain) and only **then** join the
two already-aggregated one-row-per-key results together. This is the standard, safe pattern for any
budget-vs-actual (or any "two tables at different grains") comparison in SQL — when joining tables at
different natural grains, aggregate to a common grain *before* joining, not after.

## Threshold design, and where it deliberately falls short

A single ±10% variance threshold is applied to both revenue and (a ±5% threshold) to OpEx, at every level of
the data — company-wide, by region, by month. That single threshold flags **85 of 180** region/department
x month cells in this dataset, which is far too many to be a useful "exceptions only" report in practice.

The reason: variance percentage is far noisier at a small base than a large one. A region/month cell with
only a handful of transactions can swing ±100%+ on what amounts to one or two extra wholesale orders landing
in a given month, while the same threshold applied to a full-year, company-wide number is far more
meaningful because the base is large and stable. This dashboard intentionally keeps one threshold everywhere
so that this noise is visible rather than hidden — see the Power BI guide for the grain-aware fix (tighter
thresholds where the base is large/stable, wider thresholds or rolling averages where it isn't). Surfacing
a methodology limitation like this, rather than quietly tuning the threshold until the output "looks clean,"
is itself part of what a good FP&A variance review is supposed to do.
