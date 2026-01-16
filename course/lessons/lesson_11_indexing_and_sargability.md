**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_11_indexing_and_sargability.md)

<h2 align="center">Lesson 11 — Indexing, SARGability, and execution plans (intro)</h2>

*Intro:* Performance stops being mysterious once you connect predicates to indexes and plans. This lesson teaches a repeatable tuning loop—measure, inspect the actual plan, change one thing, re-measure—while explaining SARGability, seeks vs scans, and covering indexes in practical terms.

We’ll treat tuning as an experiment, not a superstition. You’ll learn to start from a correct query, capture evidence (actual plan + IO/time), and make one controlled change at a time so you can attribute improvements to a specific cause.

The key skill is learning what your predicates *allow* the optimizer to do. A seekable predicate is not “faster by magic”—it’s simply shaped so an index can jump to the relevant range instead of scanning and filtering. We’ll also connect covering indexes to real pain points like key lookups, so you know when INCLUDE is worth the extra storage.

By the end, you’ll have a mental checklist you can apply to almost any slow query: access path, predicate shape, ordering/grouping needs, and whether your indexes match the workload.

## Goal
Learn to reason about performance using (1) predicates, (2) indexes, and (3) actual execution plans.

## Prerequisites
- Lessons 7–10

## Who this lesson is for
- Analysts: helps you understand why the same query is fast one day and slow the next.
- Engineers: gives you a structured way to tune (measure → change → re-measure).
- Beginners: introduces plans without assuming you already know the optimizer internals.

## Tooling (recommended)
- SSMS or Azure Data Studio.
- Enable **Actual Execution Plan**.
- Optional: `SET STATISTICS IO, TIME ON;` for repeatable measurements.

## A safe workflow for tuning
1. Start from a correct query.
2. Capture **actual plan** + IO/TIME.
3. Change one thing (predicate shape, index, query rewrite).
4. Re-measure and compare.

## Key terms
- **SARGable predicate**: a predicate that can efficiently use an index seek.
- **Seek vs Scan**: seek navigates to relevant keys; scan reads many/all rows.
- **Covering index**: includes all columns needed to avoid key lookups.

## What an index is (beginner-friendly)
**What it is:** a data structure that helps SQL Server find rows faster (like a book index).

**Why it’s used:** without an index, SQL Server may need to read many pages (scan) to find a small set of rows.

**Benefits:**
- faster lookups and filtering
- can support sorting (`ORDER BY`) efficiently

**Pitfalls:**
- indexes speed up reads but can slow down writes (INSERT/UPDATE/DELETE)
- too many indexes waste space and maintenance time

## What “SARGable” means in plain language
**SARGable = seekable.** A predicate is SARGable when SQL Server can use it to navigate the index.

Common non-SARGable shapes:
- applying a function to the column: `CONVERT(date, EventTime) = ...`
- mismatched data types that force implicit conversion

Beginner workaround patterns:
- use a range predicate on the raw column (>= and < for datetimes)
- cast the *parameter/literal* to the column type, not the column to the parameter type

## Safety note
Performance depends on data volume and distribution. The labs below demonstrate *behavior*; to see big timing differences, increase row counts.

## Labs

### Lab setup
This setup creates a small event table with a predictable shape: timestamps, a user identifier, an event type, and a payload. Think of it as a simplified version of analytics clickstream data or application telemetry, where most queries filter by user and time.

The row count is intentionally modest so you can run everything quickly, even on a laptop. If you want timing differences that are impossible to miss, increase the `TOP (5000)` to something larger (for example 500,000) and repeat the labs.

The most important part of this lab is not the specific table—it’s the habit of building a reproducible dataset. Tuning without reproducibility is guesswork, because you can’t tell whether a change helped or the data simply changed.
```sql
DROP TABLE IF EXISTS dbo.Events;
GO

CREATE TABLE dbo.Events(
  EventID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  EventTime datetime2(0) NOT NULL,
  UserID int NOT NULL,
  EventType varchar(20) NOT NULL,
  Payload varchar(100) NULL
);
GO

;WITH n AS (
  SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
  FROM sys.all_objects
)
INSERT INTO dbo.Events(EventTime, UserID, EventType, Payload)
SELECT DATEADD(second, n.n, '2025-01-01T00:00:00'),
       (n.n % 100) + 1,
       CASE WHEN n.n % 10 = 0 THEN 'purchase' ELSE 'view' END,
       'x'
FROM n;
GO
```

### Lab 1 — Baseline query + actual plan
Start with the simplest correct query and observe what SQL Server chooses to do. This “baseline” is your reference point: if you don’t measure before changing anything, you will eventually tune the wrong thing.

When you look at the actual plan, focus on two questions. First: did the engine **scan** the table or did it **seek** into an index? Second: how much work did it do—rows read vs rows returned? Those two signals explain a large fraction of real-world performance issues.

If you enabled `SET STATISTICS IO, TIME ON;`, keep a note of the logical reads. In many OLTP-style queries, logical reads correlate better with performance than elapsed time, because time can fluctuate with caching and system load.
```sql
SELECT COUNT(*)
FROM dbo.Events
WHERE UserID = 42;
```
Step: enable **Actual Execution Plan** in SSMS/Azure Data Studio.

### Lab 2 — Add an index and observe seek
Now you introduce a narrow, selective access path: an index on `UserID`. Conceptually, you are telling SQL Server: “I will often ask for rows by user; please keep them organized so you can jump to the right region quickly.”

After creating the index, rerun the exact same query. If the plan changes to an index seek, that is not magic—it’s the optimizer realizing that it can read far fewer pages to answer the same question.

Be careful with the interpretation: using an index is not always faster. On tiny tables, scans can be cheaper. Your goal is to learn *why* the plan changed and what it means for larger volumes.
```sql
CREATE INDEX IX_Events_UserID ON dbo.Events(UserID);
GO

SELECT COUNT(*)
FROM dbo.Events
WHERE UserID = 42;
```
Expected: plan changes from scan to seek (or at least uses the index).

### Lab 3 — SARGable vs non-SARGable datetime predicate
Datetime filtering is where many “it should be fast” expectations go to die. Beginners often write queries that *look* correct, but force SQL Server to compute something per row, which prevents efficient index navigation.

The range form (`>=` and `<`) is the workhorse because it keeps the predicate on the raw column. It is also safer than `BETWEEN` for datetimes, because the upper bound is exclusive and avoids off-by-one issues with fractional seconds.

In contrast, `CONVERT(date, EventTime)` applies a function to the column. Even if the result is logically correct, it often means SQL Server can’t seek on an index on `EventTime`—it has to evaluate the function for many rows and then filter.
SARGable:
```sql
SELECT COUNT(*)
FROM dbo.Events
WHERE EventTime >= '2025-01-01T00:10:00'
  AND EventTime <  '2025-01-01T00:20:00';
```
Non-SARGable (function on column):
```sql
SELECT COUNT(*)
FROM dbo.Events
WHERE CONVERT(date, EventTime) = '2025-01-01';
```
Expected: non-SARGable form often prevents seek on an index on `EventTime`.

### Lab 4 — Composite index and key order
Single-column indexes are a great start, but real queries rarely filter on just one column. Here you create a composite index `(UserID, EventTime)` to match a very common pattern: “for a given user, show me recent events.”

The order of keys inside a composite index matters. With `(UserID, EventTime)`, the engine can first narrow down to one user, and then walk event times in order. If you reversed the order to `(EventTime, UserID)`, different queries might benefit, but this specific query would often be less ideal.

Notice how the `ORDER BY EventTime DESC` aligns with the second key. This is where you start seeing index design as a conversation between predicates (filtering) and required ordering (sorting).
```sql
CREATE INDEX IX_Events_UserID_EventTime ON dbo.Events(UserID, EventTime);
GO

SELECT TOP (20) EventID, EventTime, EventType
FROM dbo.Events
WHERE UserID = 42
ORDER BY EventTime DESC;
```
Expected: index supports predicate + ordering.

### Lab 5 — Covering with INCLUDE
Even when you have a good seek, SQL Server may still need extra work to fetch columns that are not in the index. That extra work is commonly called a **key lookup**: the engine finds matching keys in the nonclustered index, then goes back to the base table (or clustered index) to retrieve the remaining columns.

`INCLUDE` columns let you build a covering index: the index still uses `(UserID, EventTime)` as the navigation keys, but also stores `EventType` and `Payload` alongside them. For this query, that can remove lookups and reduce random IO.

The tradeoff is maintenance and size. Covering indexes are powerful, but each included column increases index storage and can slow down writes. In practice, you cover only what you must, based on measured workload.
```sql
CREATE INDEX IX_Events_UserID_EventTime_Incl
ON dbo.Events(UserID, EventTime)
INCLUDE (EventType, Payload);
GO

SELECT TOP (20) EventTime, EventType, Payload
FROM dbo.Events
WHERE UserID = 42
ORDER BY EventTime DESC;
```
Expected: fewer/zero lookups.

### Lab 6 — Implicit conversion trap (concept)
Implicit conversion is a subtle performance killer because the query still “works” and returns correct results, but the optimizer may be forced into a plan that scans and converts instead of seeking and comparing.

The important mental model is: SQL Server must pick one data type for the comparison. If it chooses to convert the column values, you effectively apply a function to the column, which often breaks SARGability. If you convert the literal/parameter instead, the column can remain seekable.

In real systems this shows up when parameters are declared with the wrong type (for example, an `nvarchar` parameter compared to an `int` column). The fix is often simple: use correct parameter types and avoid comparing unlike types in predicates.
If a column is `int` but you compare to a string literal, SQL Server may do an implicit conversion.
Rule: match data types.

## Summary checklist
Performance tuning becomes much less mysterious when you treat it as a repeatable experiment. You start from a correct query, you observe the plan and IO, and you make one change at a time.

The two biggest levers you practiced here are (1) writing predicates that let SQL Server navigate indexes, and (2) designing indexes that match how the query filters and orders. These are the same levers you’ll use in most production systems.

When you move beyond the lab, keep one principle in mind: do not optimize in the abstract. Measure on representative data, document why you made a change, and keep your indexes as small as your workload allows.

- Microsoft Docs: [SQL Server index design guide](https://learn.microsoft.com/sql/relational-databases/sql-server-index-design-guide), [CREATE INDEX (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/create-index-transact-sql)

*Conclusion:* Start from a correct query, then optimize with evidence. Write seekable predicates, build indexes that match filter+order, and use the actual plan as your feedback loop—not guesses.
