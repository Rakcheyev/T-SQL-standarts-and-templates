# SQL Server Tuning Report Template

Use this template to document a performance investigation so it’s reproducible and reviewable.

---

## 1) Context

- **Query name / feature:**
- **Environment:** (local / dev / prod)
- **SQL Server version / edition:**
- **Database / schema:**
- **When it happens:** (time window / frequency)
- **User impact:** (timeout / slow page / batch SLA missed)

## 2) Repro details

- **Exact query text:** (include parameters)
- **How to reproduce:**
- **Dataset notes:** row counts, date ranges, skew, cardinality hot spots

## 3) Baseline measurements (BEFORE)

Record at least 3 runs (cold/warm if relevant).

- **Settings used:**
  - `SET STATISTICS IO, TIME ON;`
  - Actual execution plan enabled
- **Wall time (ms):**
- **CPU time (ms):**
- **Logical reads (per table):**
- **Rows returned:**
- **Rows processed (if visible in actual plan):**

## 4) Observations from the Actual Plan

- **Access path:** seek / scan (which index/table)
- **Key operators:** (Nested Loops / Hash Match / Merge Join / Sort / Spool)
- **Red flags:**
  - Key Lookup (many?)
  - Sort (big?)
  - Spills (tempdb)
  - Missing index suggestions (treat as hints, not truth)
  - `CONVERT_IMPLICIT` / implicit conversions

## 5) Hypothesis

What is the likely root cause?

Examples:
- Non-SARGable predicate prevents index seek
- Wrong join order due to bad estimates
- Parameter sniffing sensitivity
- Missing covering index causes many key lookups
- Sorting dominates due to missing supporting index

## 6) Change proposal (ONE change at a time)

- **Change #1:**
  - Type: query rewrite / index / statistics / schema change
  - SQL (exact script):
  - Risk / rollback plan:

## 7) Measurements (AFTER)

- **Wall time (ms):**
- **CPU time (ms):**
- **Logical reads:**
- **Plan change summary:**

## 8) Correctness check

- Did results stay identical? (row count + spot checks)
- Any edge cases affected? (NULL semantics, duplicates, time boundaries)

## 9) Operational notes

- Impact on writes / ETL: (index maintenance, update cost)
- Deployment considerations: (ONLINE=ON?, locking, maintenance window)
- Monitoring to add: (timeouts, deadlocks, regressions)

## 10) Final decision

- Outcome: accepted / rejected / needs more data
- Follow-ups:
