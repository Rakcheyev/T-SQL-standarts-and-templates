**Language:** English | [Українська](../../i18n/uk/course/lessons/12_etl_patterns_staging_upsert.md)

<h2 align="center">Lesson 12 — ETL/ELT patterns: staging, upserts, batching</h2>

*Intro:* ETL is mostly about discipline: land data safely, validate it, then apply changes in a controlled, repeatable way. You’ll practice staging tables, upsert patterns, watermarks, and batching so reruns are safe, failures are contained, and large loads don’t become one giant transaction.

**DBMS scope:** [CORE] staging/idempotency mindset + [CROSS] upsert patterns; examples are [T-SQL] (SQL Server bulk/batching scripts).

The hard part of ETL is rarely the “happy path”. The hard part is what happens on the edges: duplicates, late-arriving updates, partial files, schema drift, and reruns after a crash. This lesson focuses on building pipelines that remain correct when reality is messy.

We’ll separate concerns on purpose: staging is for landing and checking; the target layer is for curated truth. You’ll practice upsert approaches that make the outcome predictable, and you’ll learn why batching and clear transaction boundaries make operations safer (less log pressure, fewer long-held locks, smaller blast radius on failure).

You’ll also build a small operational mindset: capture a watermark, make runs idempotent, and design your scripts so “run it again” is a normal, safe answer—not a catastrophe.

## Goal
Learn practical loading patterns: staging tables, incremental loads, upserts, and batching.

## Prerequisites
- Lessons 8–11

## Who this lesson is for
- Data engineers: classic staging + upsert patterns you’ll use everywhere.
- Backend engineers: helps you load reference data safely and idempotently.
- Analysts who maintain “manual ETL” SQL scripts.

## If you’re coming from another background
- Python ETL: staging tables are similar to “raw landing” files — keep them simple and reloadable.
- Application upserts: think “update what exists, insert what doesn’t, and make retries safe”.

## How to work through the labs
1. Create target + staging tables.
2. Load staging with a small batch.
3. Apply changes to target inside a transaction.
4. Re-run the lab: ensure the pattern behaves predictably.

## Concepts
- [CROSS] **Staging table**: raw/landing area (often truncated and reloaded).
- [CROSS] **Target table**: curated/serving table.
- [CROSS] **Watermark**: last processed value (e.g., datetime).

## What staging + upsert is (beginner-friendly)
### Staging
**What it is:** a temporary “landing zone” table where you load incoming data *as-is*.

**Why it’s used:** it lets you validate and transform data before it affects the curated target table.

**Benefits:**
- [CROSS] easier retries (you can truncate/reload staging)
- [CROSS] simpler debugging (you can inspect raw incoming rows)

**Pitfalls:**
- [CROSS] duplicates in staging can cause wrong upserts unless you dedupe
- [CROSS] schema drift (source columns change) needs a process

### Upsert
**What it is:** apply changes by updating existing rows and inserting missing rows.

**Why it’s used:** most real loads are incremental: some entities change, some are new.

**Benefits:**
- [CROSS] idempotent-friendly when designed carefully (safe retries)

**Pitfalls:**
- [CROSS] race conditions under concurrency if the target is being written elsewhere; handle with proper keys and transactions

## Temporary objects and procedural tools (beginner-friendly)
ETL scripts often need “scratch space” and control-flow. In SQL Server you’ll commonly see these symbols:

### `#TempTable` (local temporary table)
**What it is:** a temporary table stored in `tempdb`, visible only within your current session (connection).

**Why it’s used:**
- [T-SQL] to store intermediate results between steps
- [T-SQL] to index intermediate data (`CREATE INDEX` on the temp table)
- [T-SQL] to improve performance when you reuse the same intermediate set multiple times

**Benefits:**
- [T-SQL] can have indexes and statistics (often helps the optimizer)
- [T-SQL] good for “bigger” intermediate result sets

**Pitfalls:**
- [T-SQL] lives in `tempdb` → heavy use can become a bottleneck
- [T-SQL] scope is the session; if you use dynamic SQL (`EXEC(...)`), you must manage scope carefully

### `##GlobalTempTable` (global temporary table)
**What it is:** a temp table in `tempdb` visible to all sessions.

**Why it’s used:** usually only for admin/debug or cross-session demos.

**Pitfalls (big ones):**
- [T-SQL] name collisions between sessions
- [T-SQL] lifecycle is tricky (it remains until the creating session ends *and* no other session is using it)
- [T-SQL] avoid in production ETL unless you have a strong reason

### `@Variable` and `@TableVariable`
**`@Variable`:** a scalar variable (e.g., `@Watermark datetime2`), great for parameters and control-flow.

**`@TableVariable`:** a table variable declared with `DECLARE @t TABLE(...)`.

**Why table variables are used:** simple, scoped scratch tables (especially inside stored procedures).

**Benefits:**
- very clear scope (only inside the current batch/proc)
- convenient for small intermediate sets

**Pitfalls:**
- the optimizer may have poorer row-count estimates in some cases (depends on SQL Server version/features)
- for larger sets, `#temp` often performs better because statistics/indexing options are richer

### `@@Something` (system functions)
**What it is:** built-in “session state” values, for example:
- [T-SQL] `@@ROWCOUNT` — how many rows were affected by the last statement
- [T-SQL] `@@TRANCOUNT` — current transaction nesting level

**Pattern:** check `@@ROWCOUNT` in batching loops (as in Lab 5), but remember it changes after *every* statement.

## Cursors in ETL: when to use (and when not)
**What a cursor is:** a way to iterate row-by-row.

**Why people reach for it:** some tasks feel sequential (per-row API calls, per-row dynamic SQL, complex per-row side effects).

**Why it’s usually a last resort:** row-by-row is often much slower than set-based SQL (“RBAR” — row-by-agonizing-row).

**Preferred alternatives:** set-based `INSERT/UPDATE`, window functions, `APPLY`, and batching.

**If you must use a cursor, prefer this pattern:**
- [T-SQL] `LOCAL FAST_FORWARD READ_ONLY` (simple, forward-only)
- [T-SQL] always `CLOSE` and `DEALLOCATE`
- [T-SQL] keep the cursor work small and fast; avoid long transactions inside the loop

Example skeleton:
```sql
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
SELECT CustomerID
FROM dbo.StageCustomers;

OPEN c;

DECLARE @CustomerID int;
FETCH NEXT FROM c INTO @CustomerID;

WHILE @@FETCH_STATUS = 0
BEGIN
  -- do minimal per-row work here
  FETCH NEXT FROM c INTO @CustomerID;
END

CLOSE c;
DEALLOCATE c;
```

## Labs

### Lab setup
Before you upsert anything, you need two things: a **target** that represents your curated truth, and a **staging** area that represents what just arrived. The key idea is that staging is allowed to be “messy” (duplicates, unexpected values, partial batches), while the target should remain consistent and query-friendly.

In this setup, `CustomerID` plays the role of a business key. That’s why it is the primary key on the target: upsert logic becomes deterministic only if you have a reliable way to match “the same entity” across loads.

The `DROP TABLE IF EXISTS` lines are not “ETL code” per se—they’re just a safe reset so you can rerun the labs many times and get the exact same behavior. In production you’d typically keep target tables, but you may still truncate/recreate staging.
```sql
DROP TABLE IF EXISTS dbo.StageCustomers;
DROP TABLE IF EXISTS dbo.Customers;
GO

CREATE TABLE dbo.Customers(
  CustomerID int NOT NULL PRIMARY KEY,
  CustomerName nvarchar(50) NOT NULL,
  UpdatedAt datetime2(0) NOT NULL
);

CREATE TABLE dbo.StageCustomers(
  CustomerID int NOT NULL,
  CustomerName nvarchar(50) NOT NULL,
  UpdatedAt datetime2(0) NOT NULL
);
GO

INSERT INTO dbo.Customers(CustomerID, CustomerName, UpdatedAt)
VALUES (1, N'Alice', '2025-01-01T00:00:00'),
       (2, N'Bob',   '2025-01-01T00:00:00');
GO
```

### Lab 1 — Load staging (reproducible batch)
Treat staging as a landing zone that you can rebuild. In many pipelines, staging is populated from files, Kafka topics, API pulls, or upstream tables. Here we model an incoming batch with a tiny, reproducible insert.

Notice that we `TRUNCATE` staging first. This is a common pattern for “full refresh into staging” because it keeps staging predictable: whatever is in staging right now is exactly the batch you’re about to process.

Also note the intent behind the rows: `CustomerID = 2` changes (update case) and `CustomerID = 3` is new (insert case). Good ETL test data should cover both paths on purpose.
```sql
TRUNCATE TABLE dbo.StageCustomers;
INSERT INTO dbo.StageCustomers(CustomerID, CustomerName, UpdatedAt)
VALUES (2, N'Bob Jr', '2025-01-02T00:00:00'),
       (3, N'Carla',  '2025-01-02T00:00:00');
```

### Lab 2 — Upsert via `UPDATE` then `INSERT`
An upsert is not “one statement”; it’s a **contract**: after the load finishes, your target must contain the correct latest version for existing keys, and must include new keys exactly once. The simplest way to make that contract explicit is a two-step pattern: `UPDATE` what matches, then `INSERT` what’s missing.

We wrap both steps in a transaction so the target never ends up in a half-applied state. That matters not only for correctness, but also for operational resilience: if something fails mid-load, you want a clean rollback, not a target that is half old/half new.

One more practical note: this pattern assumes you have a **unique** way to identify a row in the target (`CustomerID` here). In real pipelines, enforce that uniqueness with a primary key or unique index—otherwise concurrency and duplicates will eventually surprise you.
```sql
BEGIN TRAN;

UPDATE t
SET t.CustomerName = s.CustomerName,
    t.UpdatedAt     = s.UpdatedAt
FROM dbo.Customers AS t
JOIN dbo.StageCustomers AS s
  ON s.CustomerID = t.CustomerID;

INSERT INTO dbo.Customers(CustomerID, CustomerName, UpdatedAt)
SELECT s.CustomerID, s.CustomerName, s.UpdatedAt
FROM dbo.StageCustomers AS s
WHERE NOT EXISTS (
  SELECT 1 FROM dbo.Customers AS t WHERE t.CustomerID = s.CustomerID
);

COMMIT;

SELECT * FROM dbo.Customers ORDER BY CustomerID;
```
Expected output:

| CustomerID | CustomerName | UpdatedAt |
|---:|:---|:---|
| 1 | Alice | 2025-01-01 00:00:00 |
| 2 | Bob Jr | 2025-01-02 00:00:00 |
| 3 | Carla | 2025-01-02 00:00:00 |

### Lab 3 — Detect deletes (optional)
Upserts are about inserts and updates, but real loads sometimes need to reflect deletions as well. The tricky part is that a missing row in staging can mean different things: “the source deleted it”, “the source didn’t send it this batch”, or “your extract failed”. You need business semantics before you delete anything.

This query shows the canonical *anti-join* check: “which target keys are not present in staging?”. It’s often used to generate a review report first, rather than immediately deleting.

If you do apply deletions, consider using a **soft delete** (an `IsActive` flag or `ValidTo` date) for auditability—especially in analytics and compliance-heavy systems.
```sql
SELECT t.CustomerID
FROM dbo.Customers AS t
WHERE NOT EXISTS (
  SELECT 1 FROM dbo.StageCustomers AS s WHERE s.CustomerID = t.CustomerID
);
```

### Lab 4 — Incremental load with watermark (pattern)
Most production pipelines are incremental. Instead of reloading everything, you process only changes since the last successful run. A “watermark” is the simplest representation of that: a stored value that says “I have processed up to here”.

The watermark can be a timestamp (`UpdatedAt`), an increasing ID, or even a compound key. The exact choice depends on the source system’s guarantees. If the source does not guarantee monotonic ordering or can send late-arriving updates, you must design your watermark strategy accordingly.

This lab shows the filtering idea only. In a real pipeline you store the watermark in a control table and update it only after the transaction commits successfully.
Assume you store a last processed timestamp.
```sql
DECLARE @Watermark datetime2(0) = '2025-01-01T12:00:00';

SELECT *
FROM dbo.StageCustomers
WHERE UpdatedAt > @Watermark;
```

### Lab 5 — Batching pattern (template)
Batching is a performance and operational safety technique: instead of touching millions of rows in one giant transaction, you do smaller chunks. That reduces lock durations, log pressure, and the blast radius of failures.

The `TOP (@BatchSize)` pattern here is intentionally simple, but remember the hidden requirement: you need a **stable ordering** (typically a key) so that each batch is well-defined. Without a stable order, “the next 1000 rows” is not a deterministic concept.

Finally, pay attention to the loop exit condition. `@@ROWCOUNT` refers to the *previous statement*, so it must be checked immediately after the statement you want to monitor. If you add any statements between the update and the `IF`, you will break the loop logic.
For large tables, update in chunks.
```sql
DECLARE @BatchSize int = 1000;

WHILE 1 = 1
BEGIN
  ;WITH b AS (
    SELECT TOP (@BatchSize) CustomerID
    FROM dbo.Customers
    ORDER BY CustomerID
  )
  UPDATE c
    SET UpdatedAt = UpdatedAt
  FROM dbo.Customers AS c
  JOIN b ON b.CustomerID = c.CustomerID;

  IF @@ROWCOUNT = 0 BREAK;
END;
```

## Notes on `MERGE`
`MERGE` looks appealing because it reads like a single “mathematical” statement: match rows, update when matched, insert when not matched. For demos and small tasks, that can be very convenient.

In production ETL, many teams still choose explicit `UPDATE` + `INSERT` because it is easier to reason about, easier to test in isolation, and easier to troubleshoot when something goes wrong. You can measure each step, log counts, and handle exceptions in a very controlled way.

If you do use `MERGE`, treat it as a tool that deserves careful review: make sure your join condition is truly unique, verify concurrency behavior, and write tests for duplicates and edge cases.

## Summary
Staging and upserts are less about syntax and more about discipline: isolate incoming data, validate it, and apply changes to the curated layer in a controlled way. When this is done well, reruns become safe and debugging becomes possible.

In practice, you’ll spend most of your ETL effort on *the edges*: duplicates, late-arriving updates, schema drift, and concurrency. The patterns in this lesson give you stable building blocks for those realities.

Your next step is to apply these patterns to your own domain: pick a real entity, define a reliable key, decide on watermark semantics, and make the pipeline idempotent before optimizing anything.

- Microsoft Docs: [MERGE (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/merge-transact-sql), [OUTPUT clause (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/queries/output-clause-transact-sql), [INSERT (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/insert-transact-sql)

*Conclusion:* Design for idempotency first, then for speed. With a stable key, clear watermark semantics, and batching, your pipeline becomes predictable to rerun, debug, and operate.

