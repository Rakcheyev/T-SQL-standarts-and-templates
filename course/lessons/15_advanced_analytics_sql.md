**Language:** English | [Українська](../../i18n/uk/course/lessons/15_advanced_analytics_sql.md)

<h2 align="center">Lesson 15 — Advanced analytics SQL (GROUPING SETS, PIVOT, cohorts)</h2>

*Intro:* After you know JOINs, aggregates, and window functions, the next step is expressing multi-level analytics cleanly: subtotals, cross-tabs, and cohort/retention style queries. This lesson focuses on “analytics-grade” SQL patterns that analysts use daily, but that many engineers only learn through painful trial and error.

**DBMS scope:** [CORE] grouping concepts + [CROSS] pivot/unpivot concepts; examples are [T-SQL] (SQL Server).

## Goal
Learn practical patterns for:
- multiple aggregation levels in one query (`GROUPING SETS`, `ROLLUP`, `CUBE`)
- crosstab reports (`PIVOT`, `UNPIVOT`)
- cohort/retention queries (first purchase month → retention by month offset)

## Prerequisites
- Lessons 6–7 (window functions and safe query patterns)

## Why this matters in production

Analytics SQL is where “mostly correct” queries cause real damage: mis-labeled subtotals become double-counted KPIs, pivoted reports drift as categories change, and cohort/retention metrics get debated for weeks because the cohort definition was implicit instead of encoded.

The goal of this lesson is not fancy syntax — it’s building reports that are reproducible, reviewable, and hard to misinterpret. If you can label subtotal rows, choose portable patterns when possible, and define cohorts precisely, you’ll ship analytics that stakeholders can trust.

## Key terms
- **Subtotal / grand total:** extra aggregation rows beyond the “base” grouping.
- **Grouping set:** one explicit grouping level in `GROUPING SETS`.
- **Crosstab (pivot):** turning rows into columns for reporting.
- **Cohort:** group of entities that share a start event (signup month / first purchase month).

## Common mistakes
- Confusing `ROLLUP` output rows with real data rows (always label subtotal rows).
- Using `PIVOT` when conditional aggregation is simpler (and more portable).
- Creating “retention” metrics without defining the cohort event precisely.

## Labs

### Lab setup (shared dataset)
This dataset is intentionally small and deterministic.

```sql
DROP TABLE IF EXISTS dbo.Sales;
GO

CREATE TABLE dbo.Sales
(
    SaleId     int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerId int               NOT NULL,
    SaleDate   date              NOT NULL,
    Amount     decimal(12,2)     NOT NULL,
    Channel    varchar(10)       NOT NULL
);
GO

INSERT INTO dbo.Sales (CustomerId, SaleDate, Amount, Channel)
VALUES
-- Customer 1: first purchase in Jan, then Feb and Mar
(1, '2025-01-10', 120.00, 'web'),
(1, '2025-02-02',  80.00, 'web'),
(1, '2025-03-15',  60.00, 'store'),

-- Customer 2: first purchase in Jan, then Jan again
(2, '2025-01-05',  50.00, 'store'),
(2, '2025-01-20',  30.00, 'web'),

-- Customer 3: first purchase in Feb, then Mar
(3, '2025-02-11', 200.00, 'web'),
(3, '2025-03-01',  40.00, 'web'),

-- Customer 4: first purchase in Mar only
(4, '2025-03-22',  70.00, 'store');
GO
```

### Lab 1 — `GROUPING SETS` for multi-level aggregates
Task: show revenue by (Month, Channel), plus subtotals by Month, plus a grand total.

```sql
SELECT
    DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
    Channel,
    SUM(Amount) AS Revenue,
    GROUPING(DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)) AS IsMonthTotal,
    GROUPING(Channel) AS IsChannelTotal
FROM dbo.Sales
GROUP BY GROUPING SETS
(
    (DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1), Channel),
    (DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)),
    ()
)
ORDER BY
    SalesMonth,
    Channel;
```

Expected shape:
- detailed rows: `IsMonthTotal = 0` and `IsChannelTotal = 0`
- month subtotal rows: `IsChannelTotal = 1`
- grand total row: `IsMonthTotal = 1` and `IsChannelTotal = 1`

### Lab 2 — `ROLLUP` + labeling subtotal rows
Task: produce a clean report that labels subtotal rows.

```sql
WITH Base AS
(
    SELECT
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
        Channel,
        Amount
    FROM dbo.Sales
)
SELECT
    SalesMonth,
    CASE
        WHEN GROUPING(Channel) = 1 AND GROUPING(SalesMonth) = 0 THEN '(month total)'
        WHEN GROUPING(Channel) = 1 AND GROUPING(SalesMonth) = 1 THEN '(grand total)'
        ELSE Channel
    END AS ChannelLabel,
    SUM(Amount) AS Revenue
FROM Base
GROUP BY ROLLUP (SalesMonth, Channel)
ORDER BY SalesMonth, ChannelLabel;
```

### Lab 3 — Conditional aggregation as a portable alternative to `PIVOT`
Task: get a crosstab of revenue per month with columns `web_revenue` and `store_revenue`.

**PostgreSQL note:** conditional aggregation is the default approach. PostgreSQL also supports a very readable `FILTER` form:

```sql
-- PostgreSQL style (equivalent idea)
SELECT
    date_trunc('month', sale_date)::date AS sales_month,
    SUM(amount) FILTER (WHERE channel = 'web') AS web_revenue,
    SUM(amount) FILTER (WHERE channel = 'store') AS store_revenue,
    SUM(amount) AS total_revenue
FROM sales
GROUP BY 1
ORDER BY 1;
```
See: [POSTGRESQL_NOTES.md](../../POSTGRESQL_NOTES.md)

```sql
SELECT
    DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
    SUM(CASE WHEN Channel = 'web'   THEN Amount ELSE 0 END) AS web_revenue,
    SUM(CASE WHEN Channel = 'store' THEN Amount ELSE 0 END) AS store_revenue,
    SUM(Amount) AS total_revenue
FROM dbo.Sales
GROUP BY DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)
ORDER BY SalesMonth;
```

Expected output:
- 2025-01-01: web=30, store=170, total=200
- 2025-02-01: web=280, store=0, total=280
- 2025-03-01: web=40, store=130, total=170

### Lab 4 — `PIVOT` for a fixed set of columns
Same report, using `PIVOT` (T-SQL specific). This is best when you truly need columns (e.g., export/reporting).

```sql
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
        Channel,
        Amount
    FROM dbo.Sales
)
SELECT
    SalesMonth,
    ISNULL([web], 0) AS web_revenue,
    ISNULL([store], 0) AS store_revenue
FROM Monthly
PIVOT
(
    SUM(Amount) FOR Channel IN ([web], [store])
) p
ORDER BY SalesMonth;
```

### Lab 5 — Cohorts: first purchase month → retention by month offset
Definition:
- cohort month = customer’s first purchase month
- retention month = purchase month
- month_offset = months between cohort month and retention month

```sql
WITH Purchases AS
(
    SELECT
        CustomerId,
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS PurchaseMonth
    FROM dbo.Sales
    GROUP BY CustomerId, DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)
),
Cohorts AS
(
    SELECT
        CustomerId,
        MIN(PurchaseMonth) AS CohortMonth
    FROM Purchases
    GROUP BY CustomerId
),
Activity AS
(
    SELECT
        c.CohortMonth,
        p.PurchaseMonth,
        DATEDIFF(MONTH, c.CohortMonth, p.PurchaseMonth) AS MonthOffset,
        p.CustomerId
    FROM Cohorts c
    JOIN Purchases p
        ON p.CustomerId = c.CustomerId
)
SELECT
    CohortMonth,
    MonthOffset,
    COUNT(DISTINCT CustomerId) AS ActiveCustomers
FROM Activity
GROUP BY CohortMonth, MonthOffset
ORDER BY CohortMonth, MonthOffset;

## Mini-assessment (self-check)

1. Why is labeling subtotal rows important when using `ROLLUP`/`GROUPING SETS`?
2. When would you prefer conditional aggregation over `PIVOT`?
3. What’s one reason cohort metrics become misleading in production?
4. In the cohort query, why do we `GROUP BY CustomerId, PurchaseMonth` in `Purchases`?
5. If you add a new `Channel` value, which of the labs will adapt automatically and which will not?

## Homework (tradeoffs: correctness vs portability vs readability)

1. Extend Lab 1 to also output a **grand total per channel** and label each subtotal row.
2. Rewrite Lab 4 (`PIVOT`) into a conditional aggregation report and compare:
   - portability across DBMS
   - how easy it is to add a new channel
   - how easy it is to read in code review
3. Cohorts: change the cohort definition to **first purchase channel** (web vs store) and produce retention by MonthOffset per cohort-channel.
```

Expected output (by reasoning from the seed data):
- Cohort 2025-01-01: offset 0 → 2 customers (1,2); offset 1 → 1 customer (1); offset 2 → 1 customer (1)
- Cohort 2025-02-01: offset 0 → 1 customer (3); offset 1 → 1 customer (3)
- Cohort 2025-03-01: offset 0 → 1 customer (4)

## Summary
- `GROUPING SETS` is the most explicit way to request multiple aggregation levels in one query.
- `ROLLUP` is convenient, but you must label subtotal rows to avoid confusing them with real data.
- For crosstabs, conditional aggregation is the most portable approach; `PIVOT` is fine when the column set is fixed.
- Cohort queries depend more on precise definitions (cohort event, time grain) than on fancy SQL.

References (SQL Server):
- https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql
- https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot

*Conclusion:* Advanced analytics SQL is about expressing the *business question* clearly (subtotals, dimensions, cohorts) and then choosing the simplest query shape that stays correct as data grows.
