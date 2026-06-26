# Power BI Build Guide — Budget vs. Actual Variance Dashboard

**Same situation as Project 2:** I built this portfolio on a MacBook — Power BI Desktop is Windows-only, I
don't have a work/school email for the free Power BI tenant signup, and a Windows VM is constrained by
limited disk space on this machine. So instead of a `.pbix` file or a published dashboard, this is the exact
thought process and steps I'd execute the moment I have Windows access: the data model, every DAX measure,
and the report layout (including the drill-through setup), written precisely enough to reproduce the same
working dashboard in about 15 minutes. The HTML dashboard with the conditional-formatting heatmaps is what
stands in for it for now.

## 1. Import the data

Import from `exports/`: `dim_region.csv`, `dim_department.csv`, `budget_revenue.csv`,
`actual_revenue_by_region_month.csv`, `budget_opex.csv`, `actual_opex.csv`.

Set data types: all `*_id` columns → Whole Number; `budgeted_revenue`/`actual_revenue`/`budgeted_amount`/
`actual_amount` → Fixed Decimal Number; `month`/`year` → Whole Number.

## 2. Data model relationships

| From | To |
|---|---|
| `dim_region[region_id]` | `budget_revenue[region_id]` |
| `dim_region[region_id]` | `actual_revenue_by_region_month[region_id]` |
| `dim_department[department_id]` | `budget_opex[department_id]` |
| `dim_department[department_id]` | `actual_opex[department_id]` |

Note this model deliberately keeps budget and actual as **separate tables** rather than pre-joined — this
is the standard Power BI pattern for budget-vs-actual (it avoids the same fan-out risk the SQL queries had
to guard against, and it's what lets DAX measures recompute correctly at any slicer/filter level).

## 3. DAX measures

```dax
-- Revenue side
Budget Revenue = SUM(budget_revenue[budgeted_revenue])
Actual Revenue = SUM(actual_revenue_by_region_month[actual_revenue])
Revenue Variance $ = [Actual Revenue] - [Budget Revenue]
Revenue Variance % = DIVIDE([Revenue Variance $], [Budget Revenue], 0)
Revenue Exception Flag = IF(ABS([Revenue Variance %]) > 0.10, "FLAG", "")

-- OpEx side (note the flipped sign convention: actual > budget = unfavorable)
Budget OpEx = SUM(budget_opex[budgeted_amount])
Actual OpEx = SUM(actual_opex[actual_amount])
OpEx Variance $ = [Actual OpEx] - [Budget OpEx]
OpEx Variance % = DIVIDE([OpEx Variance $], [Budget OpEx], 0)
OpEx Exception Flag =
    IF([OpEx Variance %] > 0.05, "OVERSPEND",
       IF([OpEx Variance %] < -0.05, "UNDERSPEND", ""))

-- Combined net variance vs. plan (revenue upside + cost favorability)
Net Variance vs Plan = [Revenue Variance $] - [OpEx Variance $]
```

## 4. Conditional formatting (the "drill-downs by department/region, flagging automatically" requirement)

On the **Region_Variance** and **Department_Variance** matrix/table visuals:

1. Select the `Revenue Variance %` (or `OpEx Variance %`) column → **Format visual → Cell elements → Background color → Format by rules**.
2. Rule for revenue: Field value `< -10%` → red; `-10% to 10%` → yellow/white; `> 10%` → green.
   (Reverse this for OpEx: `> 5%` → red since overspend is bad, `< -5%` → green.)
3. Alternatively, use **Conditional formatting → Icon set** bound to the Exception Flag measure for a quick
   red/yellow/green traffic-light column — this reads faster on an exec dashboard than a color scale.

## 5. Drill-down / drill-through

1. Build a **summary page** with a matrix: rows = `dim_region[region_name]`, values = `[Budget Revenue]`,
   `[Actual Revenue]`, `[Revenue Variance %]`.
2. Build a **detail page** with the same matrix but rows = `month`, filtered to a single region.
3. Right-click the detail page in the Page pane → **Set up a drill-through** on `dim_region[region_name]`.
4. Now right-clicking any region on the summary page → "Drill through → Region Detail" jumps straight to
   that region's monthly breakdown — this is the literal "drill-down by region" the project brief asks for,
   and it's a much better demo of Power BI's actual strength than a static dashboard.
5. Repeat the same pattern for `dim_department[department_name]` on the OpEx side.

## 6. Report page layout

| Visual | Type | Fields |
|---|---|---|
| KPI cards (x5) | Card | `[Revenue Variance $]`, `[Revenue Variance %]`, `[OpEx Variance $]` (negate for "favorable" framing), `[OpEx Variance %]`, count of flagged rows |
| Region variance | Matrix w/ conditional formatting | Rows: `dim_region[region_name]`; Values: Budget, Actual, Variance % |
| Department variance | Matrix w/ conditional formatting | Rows: `dim_department[department_name]`; Values: Budget, Actual, Variance % |
| Trend | Line chart | Axis: month; Values: `[Budget Revenue]` vs `[Actual Revenue]` |
| Drill-through detail pages | Matrix | Month-level detail, one page per dimension (see Section 5) |

## 7. Publish & share (the plan, once I have Windows access)

**File → Publish → Power BI Service** (free workspace is fine). Once published, I'd:
- Use **File → Embed report → Publish to web** (the data is synthetic and non-sensitive, so this is safe here)
  to get a public link for this portfolio/resume.
- Or, failing that, just share the workspace link directly — recruiters with a free Power BI account could open it.

## A note on threshold noise (worth raising in an interview)

At the **region x month** grain, several cells show >100% variance — not because anything is actually wrong,
but because some region/month combinations have a small transaction count, so a handful of large wholesale
orders landing (or not landing) in a given month swings the percentage wildly. A single ±10% threshold
applied uniformly to both monthly-regional and annual-regional views produces a lot of false-positive noise
at the monthly grain. In a real build, the fix is grain-aware thresholds: a tighter band (e.g. ±10%) at the
annual/company level where the base is large and stable, and either a wider band (e.g. ±25-30%) or a
rolling-3-month view at the monthly/regional grain where small-sample noise is expected. This dashboard
applies a single threshold everywhere on purpose, specifically so this kind of false-positive pattern shows
up — and so it's worth fixing as a deliberate v2 improvement, not something to silently "tune away."
