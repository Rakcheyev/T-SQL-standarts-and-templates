**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_10_udf_tvf_and_views.md)

<h2 align="center">Lesson 10 — Views, UDFs, TVFs: when to use what</h2>

*Intro:* Reusability in SQL is not free: the way you package logic changes what the optimizer can see. You’ll compare views, scalar UDFs, inline TVFs, and multi-statement TVFs, focusing on visibility, estimates, and plan shape—so you can choose abstraction without surprises.

**DBMS scope:** [CROSS] views/functions concepts; examples are [T-SQL] (SQL Server TVFs + UDF inlining notes).

This is the lesson where “clean code” and “good plans” meet. Two solutions can be functionally identical, but the database engine may treat them very differently depending on whether the logic is inlined or hidden behind a black box.

We’ll frame each construct as a trade-off: readability and reuse versus optimization and predictability. You’ll learn why inline TVFs often behave like parameterized views, why scalar UDFs can be risky, and why multi-statement TVFs can surprise you with row estimates.

The goal is not to ban tools—it’s to pick the right one with eyes open. You’ll leave with practical selection rules and a habit: confirm your choice with the actual execution plan on representative data.

## Goal
Learn the tradeoffs between views, scalar functions, inline TVFs, and multi-statement TVFs.

## Prerequisites
- Lesson 7B (window function patterns help with alternatives)

## Who this lesson is for
- Developers who want reusable SQL components without creating performance surprises.
- Analysts who keep copying/pasting the same query logic.
- Anyone maintaining a codebase with lots of “helper functions”.

## If you’re coming from another background
- Application code: a SQL function *looks* like a normal function, but it can change how the optimizer reasons about the query.
- BI tools: views can make consumption easier, but they don’t automatically make queries faster.

## How to work through the labs
1. Create the objects (tables, then view/function).
2. Run the sample queries and verify results.
3. Optional (recommended): view the **actual execution plan** and note whether the logic is “inlined” into the query shape.

## Quick map
- [CROSS] **View**: stored `SELECT` definition (logical abstraction).
- [CROSS] **Scalar UDF**: returns a single value per call.
- [T-SQL] **Inline TVF**: returns a table, defined as a single `SELECT` (often optimizer-friendly).
- [T-SQL] **Multi-statement TVF**: returns a table built via multiple statements (can have performance pitfalls).

## What each construct is (and why you should care)
### Views
**What it is:** a saved query definition. It doesn’t store data by itself (it’s like a named `SELECT`).

**Why it’s used:** hide complexity and standardize definitions (e.g., “invoice totals”).

**Benefits:**
- [CROSS] readable reuse
- [CROSS] one place to fix logic

**Pitfalls:**
- [CROSS] a view is not automatically faster; it’s still a query the optimizer has to execute
- [CROSS] stacking many views can make troubleshooting harder

### Scalar UDF
**What it is:** a function that returns a single value.

**Why it’s used:** encapsulate repeated calculations.

**Benefits:**
- [CROSS] reusability
- [CROSS] can improve readability for small calculations

**Pitfalls:**
- [CROSS] can be executed per-row and hurt performance if used on large result sets
- [T-SQL] plan behavior depends on SQL Server version and whether it can inline the function

### Inline TVF vs multi-statement TVF
**Inline TVF:** essentially a parameterized view (single `SELECT`). Often integrates well into the caller query.

**Multi-statement TVF:** builds a table variable internally.

Beginner rule of thumb:
- If you need a table-returning function, prefer an **inline TVF** unless you have a strong reason not to.

Note: SQL Server 2019+ can inline some scalar UDFs (Scalar UDF Inlining), but not all.

## Labs

### Lab setup
Before we compare constructs, we need a small domain that makes the tradeoffs visible. Invoices and line items are perfect for this: they naturally produce aggregations (totals) and they naturally create repeated calculations (line amount).

Notice that the schema is intentionally minimal. The goal is not to model a full accounting system, but to create a dataset that allows you to ask realistic questions: “give me invoice totals”, “give me totals for one customer”, and “compute a repeated expression”.

As you work through the labs, keep one mental rule: you are not only learning syntax, you are learning what kind of *shape* you are giving the optimizer. Views and inline TVFs tend to preserve the original query shape; scalar UDFs and MSTVFs can hide details.
```sql
DROP TABLE IF EXISTS dbo.LineItems;
DROP TABLE IF EXISTS dbo.Invoices;
GO

CREATE TABLE dbo.Invoices(
  InvoiceID int NOT NULL PRIMARY KEY,
  CustomerID int NOT NULL,
  InvoiceDate date NOT NULL
);

CREATE TABLE dbo.LineItems(
  InvoiceID int NOT NULL,
  LineNo int NOT NULL,
  Qty int NOT NULL,
  UnitPrice decimal(10,2) NOT NULL,
  CONSTRAINT PK_LineItems PRIMARY KEY (InvoiceID, LineNo)
);
GO

INSERT INTO dbo.Invoices(InvoiceID, CustomerID, InvoiceDate)
VALUES (1, 10, '2025-01-01'), (2, 10, '2025-01-03'), (3, 20, '2025-01-04');

INSERT INTO dbo.LineItems(InvoiceID, LineNo, Qty, UnitPrice)
VALUES (1, 1, 1, 100.00),
       (1, 2, 2, 10.00),
       (2, 1, 1, 50.00),
       (3, 1, 5, 5.00);
GO
```

### Lab 1 — A view as a reusable query
Start with the simplest “abstraction”: a view. A view is essentially a named `SELECT`, which means it is most valuable when it reduces duplication and creates a shared definition that multiple consumers rely on.

The example view computes invoice totals. This is a classic use case because totals are easy to get wrong (missing a join, forgetting a filter, grouping incorrectly). Putting the canonical definition behind a view reduces the chance that each report implements its own version.

After creating the view, it’s worth looking at the actual plan of a query that selects from the view. In most cases, you will see the view definition “expanded” into the calling query. That is the correct mental model: a view is a query rewrite, not a stored result.
```sql
CREATE OR ALTER VIEW dbo.vInvoiceTotals
AS
SELECT i.InvoiceID,
       i.CustomerID,
       i.InvoiceDate,
       SUM(li.Qty * li.UnitPrice) AS InvoiceTotal
FROM dbo.Invoices AS i
JOIN dbo.LineItems AS li ON li.InvoiceID = i.InvoiceID
GROUP BY i.InvoiceID, i.CustomerID, i.InvoiceDate;
GO

SELECT * FROM dbo.vInvoiceTotals ORDER BY InvoiceID;
```
Expected totals:
- Invoice 1 → 120.00
- Invoice 2 → 50.00
- Invoice 3 → 25.00

### Lab 2 — Scalar function (simple)
Scalar UDFs are attractive because they look like clean application code: you name a calculation and call it as if it were a built-in function. For small, repeated expressions, they can make queries more readable.

But this is also where many performance surprises begin. If the function is executed once per row over a large set, it can turn a set-based query into something that behaves more like row-by-row processing.

Run this lab and then consider a thought experiment: what if `LineItems` had 10 million rows? The syntax would be identical, but the cost of per-row invocation might become visible. This is why the “same code” can behave very differently at scale.
```sql
CREATE OR ALTER FUNCTION dbo.fn_LineAmount(@Qty int, @UnitPrice decimal(10,2))
RETURNS decimal(10,2)
AS
BEGIN
  RETURN CAST(@Qty * @UnitPrice AS decimal(10,2));
END;
GO

SELECT InvoiceID, LineNo,
       dbo.fn_LineAmount(Qty, UnitPrice) AS LineAmount
FROM dbo.LineItems
ORDER BY InvoiceID, LineNo;
```

### Lab 3 — Inline TVF (often preferred over MSTVF)
An inline TVF is best understood as a parameterized view. It returns a table, but it is defined as a single `SELECT`, which allows the optimizer to incorporate it into the outer query as if you had pasted the `SELECT` inline.

This matters because it keeps the optimizer in control: it can reorder joins, push predicates, and choose indexes with full visibility of the logic. In other words, you gain reuse without losing the engine’s ability to reason about the query.

When you run this lab, compare it mentally to the view. The difference is not “function vs view”; the difference is “can I parameterize the logic?”. Inline TVFs give you reuse *and* parameterization.
```sql
CREATE OR ALTER FUNCTION dbo.itvf_InvoiceTotals(@CustomerID int)
RETURNS TABLE
AS
RETURN
  SELECT i.InvoiceID, i.InvoiceDate,
         SUM(li.Qty * li.UnitPrice) AS InvoiceTotal
  FROM dbo.Invoices AS i
  JOIN dbo.LineItems AS li ON li.InvoiceID = i.InvoiceID
  WHERE i.CustomerID = @CustomerID
  GROUP BY i.InvoiceID, i.InvoiceDate;
GO

SELECT *
FROM dbo.itvf_InvoiceTotals(10)
ORDER BY InvoiceID;
```

### Lab 4 — Multi-statement TVF (shows the shape)
Multi-statement TVFs look like a comfortable middle ground: you can build up a result step-by-step, perhaps with conditional logic, and return a table at the end. That style feels natural if you come from procedural programming.

The hidden cost is that the optimizer often has less information about the resulting row counts and distribution, because the function materializes into an internal table variable. Poor row-estimation can lead to poor join choices and unexpectedly slow plans.

This lab is not telling you “never use MSTVFs”. It is teaching you to treat them as a conscious tradeoff. If you place MSTVFs on hot query paths, you must validate their plans and performance under realistic volumes.
```sql
CREATE OR ALTER FUNCTION dbo.mstvf_InvoiceTotals(@CustomerID int)
RETURNS @t TABLE(
  InvoiceID int NOT NULL,
  InvoiceDate date NOT NULL,
  InvoiceTotal decimal(10,2) NOT NULL
)
AS
BEGIN
  INSERT @t(InvoiceID, InvoiceDate, InvoiceTotal)
  SELECT i.InvoiceID, i.InvoiceDate,
         SUM(li.Qty * li.UnitPrice) AS InvoiceTotal
  FROM dbo.Invoices AS i
  JOIN dbo.LineItems AS li ON li.InvoiceID = i.InvoiceID
  WHERE i.CustomerID = @CustomerID
  GROUP BY i.InvoiceID, i.InvoiceDate;

  RETURN;
END;
GO

SELECT *
FROM dbo.mstvf_InvoiceTotals(10)
ORDER BY InvoiceID;
```

### Lab 5 — Compare alternatives to scalar UDF usage
This lab demonstrates an important discipline: before you wrap a simple expression into a scalar UDF, try the set-based equivalent inline. Many calculations are perfectly readable as expressions, especially when you name them via aliases.

The point is not that scalar UDFs are “bad”; the point is that they have a cost model that is easy to underestimate. If an inline expression gives you the same clarity, it also gives the optimizer full visibility and often a more predictable plan.

When you teach or review SQL code, this is a practical guideline: default to inline expressions, and introduce scalar UDFs only when you’re truly reducing complexity—not merely moving it.
Rewrite “line amount” without a scalar function:
```sql
SELECT InvoiceID, LineNo,
       CAST(Qty * UnitPrice AS decimal(10,2)) AS LineAmount
FROM dbo.LineItems
ORDER BY InvoiceID, LineNo;
```

## Guidance (pragmatic)
Think of these constructs as tools with different “optimization transparency”. Views and inline TVFs tend to be transparent: the optimizer can see through them. Scalar UDFs and MSTVFs can be opaque: they can hide work and distort estimates.

That doesn’t mean you avoid the opaque tools entirely. It means you apply them where their benefit (encapsulation, procedural composition) outweighs the risk, and you validate with actual plans and representative volumes.

As a team convention, it helps to define a few rules of thumb (“inline TVF preferred”, “scalar UDF must be reviewed on large queries”), because consistent practice beats individual heroics.
- [CROSS] Prefer **views** for readable reuse (especially for BI/reporting).
- [T-SQL] Prefer **inline TVFs** when you need parameterized table logic.
- [T-SQL] Use **scalar UDFs** sparingly; validate plans on your target SQL Server version.
- [T-SQL] Avoid **MSTVFs** in performance-critical paths unless you have a strong reason.

## Summary
The big lesson is that reusability is not free. In SQL Server, the way you package logic changes what the optimizer can see, and what it can see determines which plans it can choose.

If you remember one practical rule: prefer constructs that keep the logic visible (views and inline TVFs), and be deliberate when you choose constructs that can hide work (scalar UDFs and MSTVFs). Then confirm with actual plans rather than assumptions.

As you move forward, try to build a personal library of patterns: a canonical view for common metrics, an inline TVF for parameterized filters, and a carefully-reviewed procedure for multi-step operations. Over time, that library becomes your “SQL API” in the best sense.

- Microsoft Docs: [CREATE VIEW (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/create-view-transact-sql), [CREATE FUNCTION (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/create-function-transact-sql)

*Conclusion:* Prefer transparent abstractions (views, inline TVFs) by default, and be deliberate with opaque ones (scalar UDFs, MSTVFs). Validate with actual plans on real volumes before you standardize.
