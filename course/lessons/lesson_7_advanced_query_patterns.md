**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_7_advanced_query_patterns.md)

<h2 align="center">Lesson 7 — Advanced query patterns (beyond basics)</h2>

*Intro:* Many SQL bugs aren’t syntax errors—they’re logic errors that quietly ship to production. You’ll learn query patterns that express intent (existence, missing rows, top-1 per group) and protect you from NULL traps and duplicate fanout, while staying set-based and testable.

**DBMS scope:** [CORE] (portable SQL) + [T-SQL] sections for `APPLY` (SQL Server).

The core idea is to stop “joining until it works” and start writing queries that encode the business question directly. When the intent is explicit, your results are easier to validate, code review becomes simpler, and you’re less tempted to hide symptoms with `DISTINCT`.

You’ll practice a few repeatable templates—semi-joins, anti-joins, deliberate set operators, and safe top-per-group approaches—that you can reuse in real schemas. Along the way, you’ll build the habit of thinking in terms of result grain (“what does one row represent?”) and proving correctness with small, predictable examples before scaling up.

## Goal
Move from “can write queries” to “can write safe and correct queries”, especially around NULL semantics, duplicates, and "exists" logic.

## Prerequisites
- Lessons 1–6
- Basic comfort with `SELECT`, `JOIN`, `GROUP BY`

## Who this lesson is for
- If you’re new to SQL: this teaches *safe defaults* so you don’t get surprised by duplicates and `NULL` behavior.
- If you’re a data analyst: this helps you avoid “looks right” queries that are subtly wrong.
- If you’re a software engineer: this maps directly to common app needs (existence checks, “missing rows”, top-1 per group).

## If you’re coming from another background
- Excel / Power BI: think “tables are sets” — joins can multiply rows just like adding a table with repeated keys.
- Python / JS / C#: avoid “loop thinking”. SQL is set-based: you *describe* the result, you don’t iterate.
- Dataframes (Pandas): `NULL` is not the same as `0` or `''`. Treat it as “unknown / missing”, and comparisons behave differently.

## How to work through the labs (recommended)
1. Run **Lab setup** once.
2. For each lab: read the **task**, run the query, compare to **expected result**.
3. If your output differs: check whether your tables still contain previous test data (rerun setup if needed).
4. Keep a habit: when you use `JOIN`, ask yourself “can this multiply rows?”

## Checkpoints (you should be able to)
- Explain why `EXISTS` doesn’t create duplicates.
- Explain why `NOT IN (subquery)` can return 0 rows when the subquery contains `NULL`.
- Pick between `OUTER APPLY` and window functions for “top-1 per group”, and justify the choice.

## What these patterns are (for beginners)
### Semi-join (EXISTS)
**What it is:** a filter that keeps rows from the left table if *at least one* matching row exists on the right.

**Why it’s used:** you often don’t need the right-table columns — you just need to know “does a related row exist?”.

**Benefits:**
- expresses intent clearly (existence)
- doesn’t multiply rows (unlike a normal join to a one-to-many table)
- avoids the “fix it with DISTINCT” anti-pattern

**Pitfalls:**
- forgetting to correlate the subquery (missing `WHERE o.CustomerID = c.CustomerID`) turns it into “does any order exist at all?”

### Anti-join (NOT EXISTS)
**What it is:** a filter that keeps rows from the left table if *no* matching row exists on the right.

**Why it’s used:** “find customers without orders”, “find products never sold”, “find missing foreign keys”, etc.

**Benefits:**
- correct under `NULL` (unlike `NOT IN` in many real datasets)
- usually reads very close to the business requirement

**Pitfalls:**
- an alternative pattern `LEFT JOIN ... WHERE right.key IS NULL` can work too, but it’s easier to get wrong when extra join predicates are involved

## Key ideas (checked, non-hand-wavy)
- A query can be **correct** but still wrong in production due to:
  - NULL semantics (especially with `NOT IN`)
  - accidental row multiplication (one-to-many joins)
  - over-using `DISTINCT` to hide problems
- Prefer patterns that match intent:
  - **Semi-join**: “return rows from A that have at least one match in B” → `EXISTS`
  - **Anti-join**: “return rows from A that have no match in B” → `NOT EXISTS`

## Patterns

### 1) Semi-join: `EXISTS`
When you’re new to SQL, it’s very common to reach for a `JOIN` whenever two tables are related. But many business questions are not “give me columns from both tables”; they are “does a related row exist?”. A semi-join answers that question directly.

The key idea is that `EXISTS` is a **filter**, not a row-combiner. It does not bring back columns from the right side, and it does not multiply rows even if there are many matches. That’s why it’s a safe default when your intent is “at least one”.

In practice, `EXISTS` is also a communication tool for reviewers. Someone reading your query immediately understands you’re doing an existence check, and they won’t need to ask “why is there a DISTINCT here?”.
Use when you only need to know whether a match exists.

```sql
-- Customers who placed at least one order
SELECT c.CustomerID, c.CustomerName
FROM dbo.Customers AS c
WHERE EXISTS (
  SELECT 1
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
);
```

Why it’s good:
- avoids duplicates without `DISTINCT`
- matches intent

### 2) Anti-join: `NOT EXISTS`
Anti-joins are the mirror image of semi-joins: instead of “has a related row”, you’re asking “has no related row”. This shows up constantly in real systems: customers without orders, products without sales, users who never logged in, and so on.

The reason `NOT EXISTS` is taught so strongly is that it behaves well with real-world data. Missing values (`NULL`) and duplicates are normal in staging tables and messy integrations, and `NOT EXISTS` tends to remain correct where other patterns become fragile.

Performance-wise, anti-joins are usually very index-friendly. If you have an index on the correlated key on the right-hand table, SQL Server can often prove “no match” efficiently without scanning everything.
Use for “A with no related rows in B”.

```sql
-- Customers with no orders
SELECT c.CustomerID, c.CustomerName
FROM dbo.Customers AS c
WHERE NOT EXISTS (
  SELECT 1
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
);
```

### 3) `IN` vs `EXISTS` vs `NOT IN` (NULL pitfall)
This section is here because it causes production bugs that are painful to detect. The query looks correct, it returns “something”, and then later someone discovers it silently excluded rows. The culprit is the way SQL handles `NULL` in comparisons.

SQL is based on **three-valued logic**: comparisons can be TRUE, FALSE, or UNKNOWN. Any comparison to `NULL` becomes UNKNOWN (because “we don’t know the value”). The expression `x NOT IN (subquery)` behaves like “x is not equal to a, and not equal to b, and not equal to c …”. If any element is `NULL`, one of those comparisons becomes UNKNOWN, and the whole AND chain stops being TRUE.

The practical outcome is simple: if the list contains `NULL`, `NOT IN` filters out everything (or behaves surprisingly). That’s why `NOT EXISTS` is the safe default when the right-hand side comes from a table you don’t fully control.
- `NOT IN (subquery)` can produce **no rows** if the subquery returns **any NULL**.
- `NOT EXISTS` avoids this trap.

Practical rule for newbies:
- Use `IN` when you control the list and it’s guaranteed non-NULL.
- Use `EXISTS`/`NOT EXISTS` when the list comes from a table/subquery you don’t fully control.

### 4) Set operators: `UNION ALL` vs `UNION` vs `EXCEPT` vs `INTERSECT`
Set operators look deceptively simple: “combine these two result sets.” The important part is that you’re also choosing whether duplicates are meaningful, and that choice has correctness and performance implications.

`UNION ALL` is the “honest concatenation”: it preserves duplicates, which is often what you want when results represent events or line items. `UNION` is “combine and deduplicate”, which means the engine must do extra work (usually sorting or hashing) to remove duplicates.

For `EXCEPT` and `INTERSECT`, remember they use distinct semantics too. That’s convenient for “set membership” problems, but it can surprise you if you expected counts or duplicates to be preserved.
- `UNION ALL` concatenates results (keeps duplicates) → usually fastest.
- `UNION` removes duplicates (extra work).
- `EXCEPT` returns rows in left not in right (distinct semantics).
- `INTERSECT` returns common rows (distinct semantics).

### 5) `APPLY` (T‑SQL): per-row derived sets
`APPLY` is one of those features that feels strange until you have the right mental model. Think of it as “for each row on the left, run this small query and return its results.” It’s like a table-valued function call, but written inline.

This makes certain patterns very natural. “Top 1 order per customer” is a classic: you want one derived row from `Orders` per row in `Customers`, and that derived row depends on the current customer.

The caution is not that `APPLY` is bad, but that it can invite row-by-row thinking. Always validate that your apply logic is doing a small, indexed lookup per left row (or that the optimizer can transform it), rather than scanning large ranges repeatedly.
`CROSS APPLY` and `OUTER APPLY` let you evaluate a table expression per left-row.
Use cases:
- Top-N per group
- Parsing rows from a string (see note: `STRING_SPLIT` ordering is not guaranteed unless using `ordinal` where supported)

## Labs (run in any SQL Server database)
All labs below use a tiny schema so results are deterministic.

### Lab setup (run once)
Before you start the labs, take a moment to understand the shape of the data. `Customers` is the “one” side, `Orders` is a one-to-many relationship to customers, and `OrderItems` is one-to-many to orders. That’s exactly the shape that creates surprises when you join without thinking about multiplicity.

The dataset is intentionally small and deterministic. That’s a feature: it lets you predict results with pencil-and-paper, and then verify that your query matches your intent. In real debugging, you’ll often build a small repro dataset like this to prove the logic.

Also notice the primary keys. Many of the patterns in this lesson become both safer and faster when keys and indexes exist on the correlation columns.
```sql
DROP TABLE IF EXISTS dbo.OrderItems;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.Customers;
GO

CREATE TABLE dbo.Customers(
  CustomerID int NOT NULL PRIMARY KEY,
  CustomerName nvarchar(50) NOT NULL
);

CREATE TABLE dbo.Orders(
  OrderID int NOT NULL PRIMARY KEY,
  CustomerID int NOT NULL,
  OrderDate date NOT NULL,
  CONSTRAINT FK_Orders_Customers
    FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);

CREATE TABLE dbo.OrderItems(
  OrderID int NOT NULL,
  LineNo int NOT NULL,
  Product nvarchar(50) NOT NULL,
  Qty int NOT NULL,
  Price decimal(10,2) NOT NULL,
  CONSTRAINT PK_OrderItems PRIMARY KEY (OrderID, LineNo),
  CONSTRAINT FK_OrderItems_Orders
    FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID)
);
GO

INSERT INTO dbo.Customers(CustomerID, CustomerName)
VALUES (1, N'Alice'), (2, N'Bob'), (3, N'Carla');

INSERT INTO dbo.Orders(OrderID, CustomerID, OrderDate)
VALUES (10, 1, '2025-01-01'),
       (11, 1, '2025-01-05'),
       (12, 2, '2025-01-07');

INSERT INTO dbo.OrderItems(OrderID, LineNo, Product, Qty, Price)
VALUES (10, 1, N'Keyboard', 1, 50.00),
       (10, 2, N'Mouse',    1, 20.00),
       (11, 1, N'Monitor',  1, 200.00),
       (12, 1, N'Mouse',    2, 20.00);
GO
```

### Lab 1 — Semi-join without duplicates (`EXISTS`)
In this lab you’re training the “exists filter” instinct. The business question is “which customers have at least one order?”, not “show me every customer-order combination”.

If you wrote this with a join, Alice would appear twice because she has two orders (and you’d be tempted to add `DISTINCT`). With `EXISTS`, you get exactly one row per customer because the query is framed as a filter.

Pay attention to the correlated predicate `o.CustomerID = c.CustomerID`. That one line is what turns `EXISTS` from “does any order exist?” into “does an order exist for *this* customer?”.
Task: list customers who have orders.

Expected result:
- Alice
- Bob

```sql
SELECT c.CustomerName
FROM dbo.Customers AS c
WHERE EXISTS (
  SELECT 1
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
)
ORDER BY c.CustomerName;
```

### Lab 2 — Anti-join (`NOT EXISTS`)
This is the “missing rows” version of Lab 1. In production, missing relationships are often what you’re hunting: customers who never converted, products that never sold, records that didn’t land in a downstream table.

`NOT EXISTS` is a safe default because it’s explicit about intent and robust under `NULL`. Compare it mentally to the common alternative `LEFT JOIN ... WHERE right.key IS NULL`: that can be correct too, but it’s easier to break accidentally when additional predicates are added.

As a habit, always ask: “What is the grain of my result?” Here it should still be one row per customer, which is exactly what the anti-join delivers.
Task: list customers with no orders.

Expected result:
- Carla

```sql
SELECT c.CustomerName
FROM dbo.Customers AS c
WHERE NOT EXISTS (
  SELECT 1
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
)
ORDER BY c.CustomerName;
```

### Lab 3 — Demonstrate the `NOT IN` + NULL trap
This lab is intentionally uncomfortable because it demonstrates a failure mode that looks like a “valid empty result”. If you run a report and get 0 rows, that can look plausible — and that’s why this bug survives.

The key lesson is: `NULL` inside the IN-list changes the truth value of the entire predicate. You are not seeing “no customers match”; you are seeing “the predicate can’t be proven TRUE for any row.”

When you fix it with `NOT EXISTS`, you’re changing the logic to something that stays correct even if the subquery contains missing values. An alternative fix is to filter out NULLs inside the subquery, but `NOT EXISTS` is usually clearer.
Task: observe that introducing a NULL into the subquery breaks `NOT IN`.

```sql
-- Build a subquery that contains a NULL
WITH CustomerIDs AS (
  SELECT CustomerID FROM dbo.Orders
  UNION ALL
  SELECT NULL
)
SELECT c.CustomerName
FROM dbo.Customers AS c
WHERE c.CustomerID NOT IN (SELECT CustomerID FROM CustomerIDs);
```

Expected result:
- returns 0 rows (because of NULL in the IN-list)

Fix:
```sql
WITH CustomerIDs AS (
  SELECT CustomerID FROM dbo.Orders
  UNION ALL
  SELECT NULL
)
SELECT c.CustomerName
FROM dbo.Customers AS c
WHERE NOT EXISTS (
  SELECT 1
  FROM CustomerIDs AS x
  WHERE x.CustomerID = c.CustomerID
);
```

### Lab 4 — `UNION ALL` vs `UNION`
This lab reinforces a simple but important rule: preserve duplicates by default. In many datasets, duplicates are meaningful facts (two purchases of the same product are not “one purchase”).

Use `UNION` only when you can justify deduplication as part of the business definition. If you’re building a “list of unique products ever purchased”, `UNION` makes sense. If you’re building an event stream or a sales list, `UNION ALL` is almost always the right choice.

It’s also a performance habit. `UNION ALL` can often stream results, while `UNION` needs to do extra work to remove duplicates.
Task: compare duplicates.

```sql
SELECT Product FROM dbo.OrderItems WHERE OrderID = 10
UNION ALL
SELECT Product FROM dbo.OrderItems WHERE OrderID = 12
ORDER BY Product;
```

Expected: `Mouse` appears twice (order 10 and order 12).

```sql
SELECT Product FROM dbo.OrderItems WHERE OrderID = 10
UNION
SELECT Product FROM dbo.OrderItems WHERE OrderID = 12
ORDER BY Product;
```

Expected: each product appears once.

### Lab 5 — Top 1 order per customer (APPLY)
Top-1-per-group is a classic query shape, and it’s one that reveals whether you’re thinking in sets. Here the intent is “for each customer, find their latest order”.

`OUTER APPLY` is a very readable way to express this: for each customer row, run a small “give me top 1 order for this customer” query. The `ORDER BY` includes a tie-breaker (`OrderID`) so the result is deterministic even if two orders share the same date.

This is also a good moment to compare alternatives. Window functions (`ROW_NUMBER() OVER (PARTITION BY ...)`) can produce the same result and are often preferred when you already need columns from the right table at scale. `APPLY` shines when you want a compact “per left row” lookup.
Task: return each customer with their latest order date.

```sql
SELECT c.CustomerName,
       o1.OrderID,
       o1.OrderDate
FROM dbo.Customers AS c
OUTER APPLY (
  SELECT TOP (1) o.OrderID, o.OrderDate
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
  ORDER BY o.OrderDate DESC, o.OrderID DESC
) AS o1
ORDER BY c.CustomerName;
```

Expected:
- Alice → order 11
- Bob → order 12
- Carla → NULLs (because OUTER APPLY)

## Common mistakes
Most mistakes in this area come from the same root cause: the query does not match the intent. When the intent is “existence”, people write a join and then try to patch the output with `DISTINCT`. When the intent is “missing rows”, people write `NOT IN` and accidentally inherit a `NULL` from upstream.

Another theme is forgetting that SQL has a “grain”. Every join and every set operator changes (or preserves) that grain. If you keep asking “what is one row supposed to represent?”, you’ll catch many bugs before they reach production.

Treat the list below as a review checklist. When a query behaves oddly, these are the first traps to eliminate.
- Using `NOT IN (subquery)` without guarding against NULLs.
- Using `DISTINCT` to hide fanout caused by a join.
- Using `LEFT JOIN ... WHERE right.id IS NULL` without understanding duplicate amplification.

## Summary
The patterns in this lesson are not “advanced syntax”; they’re advanced *intent*. The goal is to write SQL that makes your business question obvious and keeps you out of correctness traps.

If you adopt only one habit, make it this: pick the pattern that matches the question (existence → `EXISTS`, missing → `NOT EXISTS`, combine sets → choose `UNION ALL` vs `UNION` consciously). Doing that reduces the need for cleanup operators like `DISTINCT`.

From there, performance usually follows. When the engine can see your intent, it can often use indexes and short-circuit logic efficiently.
- Use `EXISTS` / `NOT EXISTS` for existence logic.
- Use set operators deliberately (`UNION ALL` by default unless you need distinct semantics).
- Use `APPLY` for per-row derived sets, but validate it doesn’t create RBAR explosions.

- Microsoft Docs: [EXISTS (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/language-elements/exists-transact-sql), [Set operators: UNION (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/language-elements/set-operators-union-transact-sql), [Set operators: EXCEPT and INTERSECT (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql), [FROM ... APPLY (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/queries/from-using-apply-transact-sql)

*Conclusion:* Correctness starts with intent: choose EXISTS/NOT EXISTS for existence logic and use set operators deliberately. Once the engine can “see” your intent, performance tuning becomes simpler and more predictable.

## Homework
Homework is where these patterns become instinctive. The goal is not to write more SQL, but to force yourself to connect intent → query shape → index shape.

When you add an index for Lab 5, you’re training the habit of designing indexes around access patterns. When you rewrite the query using window functions, you’re learning that many “top 1 per group” problems have multiple correct formulations, each with different readability and performance trade-offs.

Do both, and then explain to yourself (or a teammate) which version you would standardize on in your codebase and why.
1. Add an index that makes Lab 5 efficient (hint: `(CustomerID, OrderDate DESC)` or `(CustomerID, OrderDate, OrderID)` depending on engine).
2. Rewrite Lab 5 using window functions and compare readability.
