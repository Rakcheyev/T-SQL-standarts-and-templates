**Language:** English | [Українська](../../i18n/uk/course/lessons/07b_window_functions_deep_dive.md)

<h2 align="center">Lesson 7B — Window functions deep dive</h2>

*Intro:* Window functions let you keep row detail while computing rankings, running totals, and “latest row per group”. This lesson builds a precise mental model—PARTITION, ORDER, FRAME—so you can write deterministic queries, handle ties, and avoid accidental grain changes.

**DBMS scope:** [CORE] window functions; [CROSS] frame semantics and tie-handling can differ across DBMS.

The discipline here is subtle: the query may “work” without a fully-defined order, but your results become non-repeatable the moment ties appear (same timestamp, same amount, same status). You’ll learn to add stable tie-breakers and to say out loud what the ordering means, so the output is explainable and reproducible.

We’ll also treat frames as first-class logic. A running total over `ROWS` is not the same as a total over `RANGE`, and the difference matters when values repeat. By the end, you’ll be able to choose the right function (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, windowed aggregates) and predict how it behaves before you run it.

Finally, we connect correctness to performance: windowing often pays for sorting. You’ll get an intuition for why indexes that align with your `PARTITION BY` and `ORDER BY` can change the plan shape dramatically.

## Goal
Build reliable “analytics SQL” skills: deduplication, top-N per group, running totals, and sequence logic.

## Prerequisites
- Lesson 6 (intro to window functions)

## Who this lesson is for
- Analysts: you’ll use these patterns constantly for dedupe, rankings, and running totals.
- Software engineers: this is the “SQL way” to do top-N per group and sequencing without procedural loops.
- Anyone who struggles with “why did my GROUP BY change the row count?” — window functions preserve row-grain.

## If you’re coming from another background
- Excel: `ROW_NUMBER()` is like adding a calculated “row index” within each group.
- Pandas: think `groupby(...).rank()` / `cumcount()` / `cumsum()` — but with explicit ordering rules.
- Programming languages: always define a **deterministic tie-breaker** when you rely on row order.

## How to study this lesson
1. Run the setup.
2. For each lab: don’t just look at the output — explain in words what `PARTITION BY` and `ORDER BY` do.
3. When results surprise you: check ties and ordering first.

## Checkpoints
- You can explain the difference between `ROW_NUMBER`, `RANK`, and `DENSE_RANK`.
- You can implement top-1/top-2 per customer with a deterministic tie-break.
- You can explain what `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` means.

## What window functions are (beginner-friendly)
**What it is:** a way to compute values *per row* while looking at related rows.

**Why it’s used:** you can get rankings, running totals, and “latest row per group” without collapsing rows like `GROUP BY` does.

**Benefits:**
- keeps the original row detail (row-grain)
- removes the need for procedural loops
- often produces very readable “analytics SQL” once you learn the patterns

**Pitfalls to watch for:**
- ties: if two rows have the same ordering value, you must add extra columns to `ORDER BY` to make results deterministic when using `ROW_NUMBER()`.
- frames: for running totals, prefer an explicit `ROWS ...` frame when you mean row-by-row accumulation.
- performance: large partitions and sorts can be expensive; indexes that match `PARTITION BY` + `ORDER BY` often help.

## Core mental model (no magic)
A window function computes a value **per row**, while looking at a defined “window” of rows.
- `PARTITION BY` defines groups (like grouping keys)
- `ORDER BY` defines row sequence inside the partition

## Setup for labs
This setup is intentionally small, but it’s not “toy” data. It contains the situations that most window-function bugs come from: repeated customers, multiple rows on the same date, and ties in ordering values.

Notice customer 1 has two sales on the same day with the same amount. That is not an accident — it forces you to think about deterministic ordering. In real systems, ties happen all the time (same timestamp, same amount, same status), and the only reliable fix is to define a tie-break.

Run this setup whenever your results look strange. For window-function learning, repeatability is everything: you want to be sure you’re observing the query shape, not leftover data.
```sql
DROP TABLE IF EXISTS dbo.Sales;
GO

CREATE TABLE dbo.Sales(
  SaleID int NOT NULL PRIMARY KEY,
  CustomerID int NOT NULL,
  SaleDate date NOT NULL,
  Amount decimal(10,2) NOT NULL
);

INSERT INTO dbo.Sales(SaleID, CustomerID, SaleDate, Amount)
VALUES
  (1, 1, '2025-01-01', 10.00),
  (2, 1, '2025-01-02', 15.00),
  (3, 1, '2025-01-02', 15.00),
  (4, 2, '2025-01-01', 50.00),
  (5, 2, '2025-01-03', 20.00),
  (6, 3, '2025-01-05', 5.00);
GO
```

## Patterns + labs

### Lab 1 — `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`
This lab is about choosing the right “ranking semantic”. All three functions produce numbers, but they answer different questions.

`ROW_NUMBER()` is about **picking a single row** — it always produces 1,2,3,... even when values tie. `RANK()` and `DENSE_RANK()` are about **ranking values** — they treat ties as the same rank, and differ only in whether they leave gaps.

As you read the output, don’t just look at the numbers. Ask: if I used this to keep “top 1”, which rows would survive, and would that match the business intent?
```sql
SELECT CustomerID, SaleDate, Amount,
       ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY Amount DESC) AS rn,
       RANK()       OVER (PARTITION BY CustomerID ORDER BY Amount DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY CustomerID ORDER BY Amount DESC) AS drnk
FROM dbo.Sales
ORDER BY CustomerID, Amount DESC, SaleID;
```
What to observe:
- ties produce gaps in `RANK` but not in `DENSE_RANK`

### Lab 2 — Dedupe: keep latest row per customer
Deduplication is where window functions pay for themselves. The problem is common: you have multiple rows per entity (multiple updates, multiple events), and you want to keep only “the latest” per entity.

The hard part is defining “latest” precisely. Here we use `(SaleDate DESC, SaleID DESC)` so the rule is deterministic: if two rows share the same date, the higher `SaleID` wins. Without a tie-breaker, “latest” becomes ambiguous and results can change over time.

This pattern generalizes extremely well: replace `CustomerID` with any entity key, and replace the ordering with your “freshness” rule.
```sql
WITH x AS (
  SELECT s.*, 
         ROW_NUMBER() OVER (
           PARTITION BY s.CustomerID
           ORDER BY s.SaleDate DESC, s.SaleID DESC
         ) AS rn
  FROM dbo.Sales AS s
)
SELECT CustomerID, SaleID, SaleDate, Amount
FROM x
WHERE rn = 1
ORDER BY CustomerID;
```
Expected output:

| CustomerID | SaleID | SaleDate | Amount |
|---:|---:|:---|---:|
| 1 | 3 | 2025-01-02 | 15.00 |
| 2 | 5 | 2025-01-03 | 20.00 |
| 3 | 6 | 2025-01-05 | 5.00 |

### Lab 3 — Top 2 sales per customer
Top-N per group is one of the most frequent analytics tasks: top 2 products per category, top 3 orders per customer, highest 5 days per region. The trick is always the same: assign a per-group row number, then filter.

The ordering clause here is intentionally richer: amount first, then date, then ID. This is not overkill — it’s the difference between “top 2 is stable and explainable” and “top 2 sometimes swaps when ties happen.”

Once you’re comfortable with this, you can apply the same shape to “bottom N”, “latest N”, and “first N after a condition”.
```sql
WITH x AS (
  SELECT s.*, 
         ROW_NUMBER() OVER (
           PARTITION BY s.CustomerID
           ORDER BY s.Amount DESC, s.SaleDate DESC, s.SaleID DESC
         ) AS rn
  FROM dbo.Sales AS s
)
SELECT CustomerID, SaleID, SaleDate, Amount
FROM x
WHERE rn <= 2
ORDER BY CustomerID, rn;
```

Expected output:

| CustomerID | SaleID | SaleDate | Amount |
|---:|---:|:---|---:|
| 1 | 3 | 2025-01-02 | 15.00 |
| 1 | 2 | 2025-01-02 | 15.00 |
| 2 | 4 | 2025-01-01 | 50.00 |
| 2 | 5 | 2025-01-03 | 20.00 |
| 3 | 6 | 2025-01-05 | 5.00 |

### Lab 4 — Running total per customer (ROWS frame)
Running totals are the canonical example of why window functions exist. You want each row to stay visible, but you also want a cumulative metric alongside it.

The crucial concept is the **window frame**. `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` means “sum all prior rows in this order, including the current row.” It’s row-based, so it doesn’t accidentally group equal values together.

If you want your running total to be deterministic, your `ORDER BY` inside the window must be deterministic too. That’s why we include `SaleID` in addition to `SaleDate`.
Use `ROWS` to make the running total strictly row-based.

```sql
SELECT CustomerID, SaleID, SaleDate, Amount,
       SUM(Amount) OVER (
         PARTITION BY CustomerID
         ORDER BY SaleDate, SaleID
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total
FROM dbo.Sales
ORDER BY CustomerID, SaleDate, SaleID;
```

### Lab 5 — Customer share of total (window aggregate without partition)
This lab shows a different superpower: window aggregates can compute a “global total” while still returning one row per group.

The pattern `SUM(SUM(Amount)) OVER ()` looks weird the first time you see it, but the idea is clean: the inner `SUM(Amount)` computes per-customer totals, and the outer window sum computes the total across all customers.

This is a common reporting trick for percentages and shares. It keeps the query set-based and avoids joining the result back to a separate “total” subquery.
```sql
SELECT CustomerID,
       SUM(Amount) AS customer_total,
       SUM(Amount) * 1.0 / SUM(SUM(Amount)) OVER () AS pct_of_total
FROM dbo.Sales
GROUP BY CustomerID
ORDER BY CustomerID;
```

### Lab 6 — `NTILE` for bucketing
Bucketing is how you turn a continuous distribution into categories: top 10%, middle 10%, bottom 10%, or “tiers” like gold/silver/bronze.

`NTILE(n)` assigns bucket numbers after sorting. That means it’s always relative to the dataset you’re looking at — if the dataset changes, bucket assignments can change too.

In practice, this is useful for quick segmentation and for teaching. For serious percentile reporting, you may also look at functions like `PERCENTILE_CONT`, but `NTILE` is a great starting point.
```sql
SELECT SaleID, Amount,
       NTILE(3) OVER (ORDER BY Amount DESC) AS bucket
FROM dbo.Sales
ORDER BY Amount DESC, SaleID;
```

### Lab 7 — Gaps-and-islands (intro)
Gaps-and-islands is a whole family of problems that look hard if you think procedurally: “find streaks”, “find sessions”, “group consecutive events”. Window functions make these problems approachable.

The trick in this lab is to create a grouping key (`grp`) that stays constant inside a streak. Subtracting the row number from the date turns consecutive dates into the same “anchor” value — that anchor becomes your group.

Once you see the pattern, it becomes a reusable technique. You can adapt it to sequences in integers, time gaps, or status changes.
Problem: find “streaks” of consecutive days with purchases per customer.

```sql
WITH d AS (
  SELECT DISTINCT CustomerID, SaleDate
  FROM dbo.Sales
), x AS (
  SELECT d.*,
         DATEADD(day, -ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY SaleDate), SaleDate) AS grp
  FROM d
)
SELECT CustomerID,
       MIN(SaleDate) AS start_date,
       MAX(SaleDate) AS end_date,
       COUNT(*)      AS days_in_streak
FROM x
GROUP BY CustomerID, grp
ORDER BY CustomerID, start_date;
```

### Lab 8 — Top-1-per-group: window function vs APPLY (compare)
This lab is about engineering judgment. There are multiple correct ways to express “top 1 per group”, and you should be comfortable choosing between them.

The window approach is fully set-based and often easiest to reason about when you already have a large fact table. The apply approach can be very fast when the outer set is small/moderate and you have an index that supports “top 1 by order” lookups.

The lesson is not “APPLY is faster” or “window is better”. The lesson is: pick the shape that matches your workload, and verify with an actual plan.
Window approach (set-based, often clear):
```sql
WITH x AS (
  SELECT s.*, ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY SaleDate DESC, SaleID DESC) AS rn
  FROM dbo.Sales AS s
)
SELECT CustomerID, SaleID, SaleDate, Amount
FROM x
WHERE rn = 1
ORDER BY CustomerID;
```

APPLY approach (can be faster with the right index and moderate outer rows):
```sql
SELECT c.CustomerID, top1.SaleID, top1.SaleDate, top1.Amount
FROM (SELECT DISTINCT CustomerID FROM dbo.Sales) AS c
CROSS APPLY (
  SELECT TOP (1) s.SaleID, s.SaleDate, s.Amount
  FROM dbo.Sales AS s
  WHERE s.CustomerID = c.CustomerID
  ORDER BY s.SaleDate DESC, s.SaleID DESC
) AS top1
ORDER BY c.CustomerID;
```

## Common mistakes
Most window-function bugs are not syntax bugs — they are *definition* bugs. The query runs, it returns rows, and it can be subtly wrong because the business meaning wasn’t pinned down.

The two biggest sources are (1) mixing up grain (do you want one row per entity or one row per event?) and (2) relying on an order that isn’t deterministic. If you’re using `ROW_NUMBER()` to pick winners, you must be able to explain the ordering rule.

Treat the bullets below as your first review checklist when a window query behaves unexpectedly.
- Using window functions when a grouped aggregate is intended (wrong grain).
- Forgetting deterministic tie-breakers (`ORDER BY` must fully define order when you rely on row numbers).

## Summary
Window functions are one of the biggest “step changes” in SQL skill because they let you write analytics logic without losing row detail. Once you internalize the mental model (partition + order + frame), many problems stop requiring procedural tricks.

The practical way to get fluent is to memorize a small set of patterns: dedupe (Lab 2), top-N per group (Lab 3/8), running totals (Lab 4), and “global totals alongside groups” (Lab 5). Then apply them repeatedly until they feel natural.

As you move to real datasets, keep one performance idea in mind: window functions are often dominated by sorting. Indexes that match your partition/order keys can make a huge difference.
- Window functions are a “row-preserving” tool; they don’t change the number of rows by themselves.
- Learn a small set of patterns and apply them consistently.

- Microsoft Docs: [OVER clause (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/queries/select-over-clause-transact-sql), [ROW_NUMBER (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/functions/row-number-transact-sql), [Ranking functions (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/functions/ranking-functions-transact-sql)

*Conclusion:* Define your ordering rules, then let the window do the work. With a stable tie-breaker and an explicit frame when needed, window queries become readable, correct, and fast enough to standardize.

## Homework
Homework here is meant to connect query shape to index shape. The fastest way to level up is to stop thinking “indexes are separate DBA work” and start thinking “my query has an access pattern, so I should predict an index.”

For Lab 8, you want an index that supports “find the latest row for a given customer” efficiently. For gaps-and-islands, the goal is to take a known pattern and add a business rule (minimum streak length) without turning it into a procedural loop.

If you do these two exercises carefully, you’ll start to feel why window functions are both a correctness tool and a performance tool.
- Add an index to support Lab 8 efficiently and explain why it helps.
- Extend gaps-and-islands to find streaks with minimum length of 2 days.

