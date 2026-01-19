**Language:** English | [Українська](../../i18n/uk/course/lessons/17_table_expressions_lab_pack.md)

<h2 align="center">Lesson 17 — Table expressions lab pack (derived tables, CTEs, APPLY)</h2>

*Intro:* Table expressions are the “shape tools” of SQL: they change *how you write* a query and sometimes influence how the optimizer can reason about it. This lab pack teaches you to choose between derived tables, CTEs, and `APPLY` deliberately—based on correctness (ties, duplicates, NULLs), readability, and plan shape.

**DBMS scope:** [CORE] derived tables + CTEs; [T-SQL] `CROSS APPLY` / `OUTER APPLY`; [PG] `LATERAL` is a close analog.

## Goal

- Know when derived tables, CTEs, and APPLY are equivalent (and when they’re not).
- Avoid correctness bugs caused by duplicates, ties, and accidental row multiplication.
- Build intuition for plan shape: when a rewrite becomes a join, a spool, a sort, or a per-row evaluation.

## Prerequisites

- Lesson 7: Advanced query patterns (especially `EXISTS` / `NOT EXISTS` and APPLY)
- Lesson 7B is helpful if you’re rusty on window functions

## Why this matters in production

Most teams don’t “fail” because they don’t know syntax. They fail because:

- a query looks right but becomes wrong once ties/duplicates appear;
- a “small refactor” silently changes row-grain;
- a correlated subquery turns into RBAR under load;
- a CTE is assumed to be “materialized” (but it isn’t), causing expensive repeated work.

This lab pack gives you repeatable patterns (and counterexamples) so you can prove correctness first, then reason about performance.

## Setup for labs

This dataset is designed to surface the classic edge cases:

- two orders for the same customer at the same timestamp (ties)
- duplicated “event” rows (dedupe needed)
- customers with 0 orders (outer join behavior)

```sql
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.OrderEvents;
GO

CREATE TABLE dbo.Customers(
  CustomerID int NOT NULL PRIMARY KEY,
  CustomerName nvarchar(100) NOT NULL
);

CREATE TABLE dbo.Orders(
  OrderID int NOT NULL PRIMARY KEY,
  CustomerID int NOT NULL,
  OrderDateTime datetime2(0) NOT NULL,
  Amount decimal(10,2) NOT NULL,
  CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);

CREATE TABLE dbo.OrderEvents(
  OrderEventID int NOT NULL PRIMARY KEY,
  OrderID int NOT NULL,
  EventType varchar(20) NOT NULL,
  EventTime datetime2(0) NOT NULL,
  CONSTRAINT FK_OrderEvents_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID)
);

INSERT INTO dbo.Customers(CustomerID, CustomerName)
VALUES
  (1, N'Ada'),
  (2, N'Boris'),
  (3, N'Chloe');

-- Customer 1 has a tie on OrderDateTime (same timestamp for two orders)
INSERT INTO dbo.Orders(OrderID, CustomerID, OrderDateTime, Amount)
VALUES
  (101, 1, '2025-01-01 10:00:00', 40.00),
  (102, 1, '2025-01-01 10:00:00', 55.00),
  (103, 1, '2025-01-03 09:00:00', 12.00),
  (201, 2, '2025-01-02 11:00:00', 20.00);

-- Duplicate event rows are intentional (same type/time)
INSERT INTO dbo.OrderEvents(OrderEventID, OrderID, EventType, EventTime)
VALUES
  (1, 101, 'PLACED', '2025-01-01 10:00:00'),
  (2, 101, 'PAID',   '2025-01-01 10:05:00'),
  (3, 101, 'PAID',   '2025-01-01 10:05:00'),
  (4, 102, 'PLACED', '2025-01-01 10:00:00'),
  (5, 102, 'PAID',   '2025-01-01 10:04:00'),
  (6, 103, 'PLACED', '2025-01-03 09:00:00'),
  (7, 201, 'PLACED', '2025-01-02 11:00:00');
GO
```

Recommended when performance is the topic:

```sql
SET STATISTICS IO, TIME ON;
-- In SSMS/Azure Data Studio: include Actual Execution Plan.
```

## Core idea: what a “table expression” really is

A table expression is anything that behaves like a table in `FROM`, but is produced by a query:

- derived table: `FROM (SELECT ...) AS d`
- CTE: `WITH cte AS (...) SELECT ... FROM cte`
- APPLY: `FROM A CROSS APPLY (SELECT ...) AS x`

The tricky part is not syntax — it’s **semantics**:

- Does the expression run once or “per row”?
- Can it be reordered/merged by the optimizer?
- Does it change row-grain?
- Is the ordering deterministic when ties exist?

---

## Lab 1 — Derived table vs CTE (same result)

Task: compute total order amount per customer.

```sql
-- Derived table
SELECT d.CustomerID, SUM(d.Amount) AS TotalAmount
FROM (
  SELECT o.CustomerID, o.Amount
  FROM dbo.Orders AS o
) AS d
GROUP BY d.CustomerID
ORDER BY d.CustomerID;

-- CTE
WITH d AS (
  SELECT o.CustomerID, o.Amount
  FROM dbo.Orders AS o
)
SELECT d.CustomerID, SUM(d.Amount) AS TotalAmount
FROM d
GROUP BY d.CustomerID
ORDER BY d.CustomerID;
```

Expected result:

| CustomerID | TotalAmount |
|-----------:|------------:|
| 1 | 107.00 |
| 2 | 20.00 |

Checkpoint:
- In most cases, these are just two spellings of the same logical query.

---

## Lab 2 — CTE is not “a temp table” (repeated reference)

Task: use the same filtered subset twice: (a) count rows and (b) sum amounts.

```sql
WITH BigOrders AS (
  SELECT o.OrderID, o.CustomerID, o.Amount
  FROM dbo.Orders AS o
  WHERE o.Amount >= 20.00
)
SELECT
  COUNT(*) AS BigOrderCount,
  SUM(Amount) AS BigOrderAmount
FROM BigOrders;
```

Now change it to use `BigOrders` twice (two aggregates with different grouping):

```sql
WITH BigOrders AS (
  SELECT o.OrderID, o.CustomerID, o.Amount
  FROM dbo.Orders AS o
  WHERE o.Amount >= 20.00
)
SELECT
  (SELECT COUNT(*) FROM BigOrders) AS BigOrderCount,
  (SELECT SUM(Amount) FROM BigOrders) AS BigOrderAmount;
```

Discussion:
- CTEs are *query text* — the optimizer may inline them.
- If you reference a CTE multiple times, the engine might choose a plan that repeats work or spools results.

---

## Lab 3 — Top-1 order per customer: window function approach (deterministic)

Task: return one latest order per customer.

Rule: Latest means the maximum `(OrderDateTime, OrderID)`.

```sql
WITH Ranked AS (
  SELECT
    o.CustomerID,
    o.OrderID,
    o.OrderDateTime,
    o.Amount,
    ROW_NUMBER() OVER (
      PARTITION BY o.CustomerID
      ORDER BY o.OrderDateTime DESC, o.OrderID DESC
    ) AS rn
  FROM dbo.Orders AS o
)
SELECT CustomerID, OrderID, OrderDateTime, Amount
FROM Ranked
WHERE rn = 1
ORDER BY CustomerID;
```

Expected rows:

| CustomerID | OrderID | OrderDateTime | Amount |
|-----------:|--------:|:--------------|------:|
| 1 | 103 | 2025-01-03 09:00:00 | 12.00 |
| 2 | 201 | 2025-01-02 11:00:00 | 20.00 |

Checkpoint:
- The tie-breaker (`OrderID`) is what makes this deterministic.

---

## Lab 4 — Top-1 order per customer: APPLY approach

Task: return one latest order per customer using `OUTER APPLY`.

```sql
SELECT
  c.CustomerID,
  c.CustomerName,
  x.OrderID,
  x.OrderDateTime,
  x.Amount
FROM dbo.Customers AS c
OUTER APPLY (
  SELECT TOP (1)
    o.OrderID,
    o.OrderDateTime,
    o.Amount
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
  ORDER BY o.OrderDateTime DESC, o.OrderID DESC
) AS x
ORDER BY c.CustomerID;
```

Expected rows:

| CustomerID | CustomerName | OrderID | OrderDateTime | Amount |
|-----------:|:-------------|--------:|:--------------|------:|
| 1 | Ada | 103 | 2025-01-03 09:00:00 | 12.00 |
| 2 | Boris | 201 | 2025-01-02 11:00:00 | 20.00 |
| 3 | Chloe | NULL | NULL | NULL |

Tradeoff notes:
- APPLY can be a great fit when you truly need “one row per left row” and can support it with indexes.
- It can also devolve into per-row evaluation if you’re not careful (RBAR risk).

---

## Lab 5 — “Join until it works” creates duplicates (fix with APPLY)

Task: add the **latest PAID event time** per order.

First, try a naive join (it duplicates rows because events can repeat):

```sql
SELECT o.OrderID, o.Amount, e.EventTime
FROM dbo.Orders AS o
LEFT JOIN dbo.OrderEvents AS e
  ON e.OrderID = o.OrderID
 AND e.EventType = 'PAID'
ORDER BY o.OrderID, e.EventTime;
```

Now fix it: one row per order, latest paid time.

```sql
SELECT
  o.OrderID,
  o.Amount,
  x.LatestPaidTime
FROM dbo.Orders AS o
OUTER APPLY (
  SELECT MAX(e.EventTime) AS LatestPaidTime
  FROM dbo.OrderEvents AS e
  WHERE e.OrderID = o.OrderID
    AND e.EventType = 'PAID'
) AS x
ORDER BY o.OrderID;
```

Expected result:

| OrderID | Amount | LatestPaidTime |
|--------:|------:|:---------------|
| 101 | 40.00 | 2025-01-01 10:05:00 |
| 102 | 55.00 | 2025-01-01 10:04:00 |
| 103 | 12.00 | NULL |
| 201 | 20.00 | NULL |

---

## Lab 6 — Correlated subquery vs APPLY (explain plan shape)

Task: for each customer, return the count of orders.

Correlated subquery:

```sql
SELECT
  c.CustomerID,
  c.CustomerName,
  (
    SELECT COUNT(*)
    FROM dbo.Orders AS o
    WHERE o.CustomerID = c.CustomerID
  ) AS OrderCount
FROM dbo.Customers AS c
ORDER BY c.CustomerID;
```

APPLY version:

```sql
SELECT
  c.CustomerID,
  c.CustomerName,
  x.OrderCount
FROM dbo.Customers AS c
OUTER APPLY (
  SELECT COUNT(*) AS OrderCount
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
) AS x
ORDER BY c.CustomerID;
```

What to look for in the plan:
- Does the engine execute the right side per row (nested loops + seeks), or does it transform to a join + aggregate?
- Add an index and re-check:

```sql
CREATE INDEX IX_Orders_Customer_OrderDateTime ON dbo.Orders(CustomerID, OrderDateTime DESC, OrderID DESC) INCLUDE (Amount);
```

---

## Checklist: safe defaults

- Define row-grain before writing the query (“one row per …”).
- When doing top-1/top-N: always add a deterministic tie-breaker.
- Avoid fixing duplicates with `DISTINCT` unless you can explain *why* duplicates are logically impossible.
- Use APPLY when you truly need “per left row” derived sets — and prove it won’t become RBAR under load.

## Mini-quiz (quick self-check)

1. When can a CTE behave like it’s “inlined” into the outer query?
2. Why is `ORDER BY OrderDateTime` alone not safe for top-1 when ties exist?
3. When does APPLY help correctness compared to a join?
4. If you reference a CTE twice, what plan shape might SQL Server choose to avoid repeated work?

## Summary

- Derived tables and CTEs are often equivalent; pick the one that is clearest.
- CTEs are not a storage guarantee; they’re a query expression.
- APPLY is powerful for “one derived set per left row”, but it must be used intentionally.
- Correctness comes first: ties/duplicates/NULLs decide whether your query is safe.

For deeper background reading (classic patterns):
- https://learn.microsoft.com/en-us/archive/msdn-magazine/2004/february/powerful-t-sql-syntax-gives-sql-server-a-programmability-boost

*Conclusion:* If you can state row-grain, choose a deterministic ordering, and explain whether a table expression runs once or per-row, you can review and refactor complex SQL safely.
