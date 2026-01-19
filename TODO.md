# Course TODO / Roadmap (updated after Lessons 7–14)

This file tracks the roadmap and remaining backlog for the course.

Assumptions (current repo state):
- Default locale: English in root docs and `course/lessons/`
- Secondary locale: Ukrainian under `i18n/uk/`

Current state (already implemented):
- Lessons 7–14 and bonus Lesson X exist in both locales.
- Navigation model is stable: simple `navigation.md` per locale + generated detailed indexes.
- Verification workflow exists: `scripts/verify_repo.ps1` (regen detailed nav + sanity checks) + VS Code task.

DBMS scope labels used in this file:
- `[CORE]` portable SQL (concepts work across major DBMS)
- `[CROSS]` cross-DB concept, but syntax/behavior differs (document per DB)
- `[T-SQL]` SQL Server / Azure SQL specific (T-SQL syntax or engine behavior)
- `[PG]` PostgreSQL specific

---

## 0) Meta

- [x] Decide target DBMS focus per track
  - [ ] **Core**: SQL concepts (portable) (optional)
  - [x] **T-SQL / SQL Server**: production focus
  - [ ] Optional: PostgreSQL notes where relevant
    - [ ] [T-SQL] `CROSS APPLY` / `OUTER APPLY` ↔ [PG] `LATERAL` joins
    - [ ] [T-SQL] `PIVOT` / `UNPIVOT` ↔ [PG] conditional aggregation / `crosstab` (extension)
    - [ ] [T-SQL] filtered indexes ↔ [PG] partial indexes
    - [ ] [T-SQL] computed columns + indexing ↔ [PG] generated columns + indexes
    - [ ] [T-SQL] Query Store (optional) ↔ [PG] `pg_stat_statements` + `auto_explain` (optional)
    - [ ] [CROSS] identity / sequences: [T-SQL] `IDENTITY` ↔ [PG] `GENERATED AS IDENTITY`

- [x] Decide format standards for new lessons
  - [x] Consistent structure: intro → concepts → patterns → labs → summary
  - [x] Add “Performance notes” where relevant
  - [x] Add “Common mistakes” section

- [x] Define supported SQL Server targets (so labs are reproducible)
  - [x] Recommended baseline: SQL Server 2022 Developer Edition (compat level 160)
  - [ ] Also test (optional): SQL Server 2019 (compat 150) and Azure SQL Database
  - [ ] Call out any version-sensitive features per lesson (e.g., scalar UDF inlining, `STRING_SPLIT` ordinal)

- [x] Choose a standard lab dataset strategy
  - [ ] Option A: AdventureWorks (clear, widely used)
  - [x] Option B: tiny custom schema per lesson (deterministic)
  - [x] Rule: every lab provides schema + seed data (or a generator) so results match

- [x] Standardize performance measurement in labs (to avoid “cargo-cult tuning”)
  - [x] Require: Actual execution plan + `SET STATISTICS IO, TIME ON` (where performance is the topic)
  - [x] Require: note rows processed vs rows returned
  - [ ] Optional: Query Store plan regression demo in Lesson 11

- [x] Add Ukrainian versions for planning docs
  - [x] Create `i18n/uk/TODO.md` (mirror + language switcher)

- [x] Add repo integrity tooling
  - [x] Add `scripts/sanity_check_lessons.ps1` (pairing + structure checks)
  - [x] Add `scripts/verify_repo.ps1` (one-command workflow)
  - [x] Add VS Code task in `.vscode/tasks.json`

- [ ] Optional: incorporate Itzik Ben-Gan “canon” (source of patterns + labs)
  - [ ] Use for: set-based thinking, correctness edge cases, window-function patterns, table expressions
  - [ ] Keep it as inspiration/reference only (don’t copy text; build original explanations + labs)
  - [ ] Trustworthy starting points:
    - [ ] Microsoft Press Store search results (books list): https://www.microsoftpressstore.com/search/index.aspx?query=Ben-Gan
    - [ ] T-SQL Fundamentals, 4th Edition: https://www.microsoftpressstore.com/store/t-sql-fundamentals-9780138102104
    - [ ] T-SQL Window Functions (2nd Ed): https://www.microsoftpressstore.com/store/t-sql-window-functions-for-data-analysis-and-beyond-9780135861448
    - [ ] T-SQL Querying: https://www.microsoftpressstore.com/store/t-sql-querying-9780735685048
    - [ ] (Historical, still useful concepts) MSDN Magazine archive: APPLY / CTE / PIVOT/UNPIVOT / TRY/CATCH / SNAPSHOT
      https://learn.microsoft.com/en-us/archive/msdn-magazine/2004/february/powerful-t-sql-syntax-gives-sql-server-a-programmability-boost
  - [ ] Course integration ideas (high ROI):
    - [ ] Add a dedicated “Window functions deep dive” block (or split Lesson 7) with labs: running totals, gaps-and-islands, top-N-per-group, dedupe with `ROW_NUMBER()`
    - [ ] Add a “table expressions” lab pack: derived tables vs CTEs vs APPLY; correctness + plan shape comparisons

---

## 1) Core roadmap (recommended linear sequence after Lesson 6)

### Lesson 7 — Advanced query patterns (beyond basics)
Goal: move from “can write queries” to “can write safe and correct queries”.

Topics:
- [CORE] Semi/anti joins: `EXISTS`, `NOT EXISTS`, anti-join patterns
- [CORE] `IN` vs `EXISTS` pitfalls (NULL semantics)
- [CORE] Set operators: `UNION ALL` vs `UNION`, `EXCEPT`, `INTERSECT`
- [T-SQL] APPLY patterns: `CROSS APPLY`, `OUTER APPLY` (Top-N per group, parsing)

Deliverables:
- [x] Create EN lesson file: `course/lessons/07_advanced_query_patterns.md`
- [x] Create UK lesson file: `i18n/uk/course/lessons/07_advanced_query_patterns.md`
- [x] Add labs with expected outputs
- [x] Update learning path + navigation indexes

### Lesson 7B — Window functions deep dive (Ben-Gan style, high ROI)
Goal: go from “I know `ROW_NUMBER()` exists” to “I can systematically solve analytics and sequencing tasks”.

Topics:
- [CORE] `OVER (PARTITION BY ... ORDER BY ...)` mental model
- [CORE] Ranking vs row numbering: `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`
- [CORE] Aggregate window functions vs grouped aggregates (and common misuses)
- [CORE] Frames: `ROWS` vs `RANGE` (basic intuition + when it matters)
- [CORE] Running totals, moving averages
- [CORE] Dedupe patterns using window functions (keep latest, keep highest priority)
- [CROSS] Top-N-per-group: window function approach vs APPLY approach (tradeoffs)
- [CORE] Gaps-and-islands (intro patterns)

Deliverables:
- [x] EN: `course/lessons/07b_window_functions_deep_dive.md`
- [x] UK: `i18n/uk/course/lessons/07b_window_functions_deep_dive.md`
- [x] Labs: pattern library (multiple labs)
- [x] Include a mini “pattern index” section for quick lookup

### Lesson 8 — Transactions, concurrency, locking, deadlocks
Goal: teach reliability and “why prod behaves differently than dev”.

Topics (SQL Server oriented):
- [CORE] ACID, implicit vs explicit transactions
- [CORE] Isolation levels: `READ COMMITTED`, `SERIALIZABLE`
- [T-SQL] Isolation levels (SQL Server): `SNAPSHOT`, Read Committed Snapshot (RCSI)
- [CROSS] Blocking vs deadlocks; reading deadlock basics
- [CORE] Idempotency patterns for DML

Deliverables:
- [x] EN: `course/lessons/08_transactions_concurrency.md`
- [x] UK: `i18n/uk/course/lessons/08_transactions_concurrency.md`
- [x] Labs: blocking/deadlock patterns + safe retry guidance

### Lesson 9 — Programmability: Stored procedures + error handling
Goal: production-grade DML, safe deployments, and supportability.

Topics:
- [CROSS] Stored procedures vs ad-hoc SQL
- [T-SQL] Error handling: `TRY...CATCH`, `THROW`, `XACT_STATE()`, transaction patterns
- [CORE] Logging/auditing tables (minimal viable)
- [CORE] Parameterization basics
- [T-SQL] Production hygiene: `SET NOCOUNT ON`
- [CORE] Production hygiene: schema-qualify object names, predictable result shapes

Deliverables:
- [x] EN: `course/lessons/09_stored_procedures_error_handling.md`
- [x] UK: `i18n/uk/course/lessons/09_stored_procedures_error_handling.md`
- [x] Labs: procedure + audit + rollback pattern

### Lesson 10 — UDF / TVF (pros/cons and when to use)
Goal: reusable logic without performance traps.

Topics:
- [CROSS] Scalar UDF
  - pros: reuse/clarity
  - cons: historically RBAR; optimizer limits
  - [T-SQL] SQL Server 2019+ scalar UDF inlining (what qualifies)
- [T-SQL] TVF
  - [T-SQL] inline TVF (best default)
  - [T-SQL] multi-statement TVF (cardinality/perf caveats)
- [CROSS] Alternatives: views, temp tables (where relevant)
- [T-SQL] Alternatives: iTVF over mTVF, table variables
- [T-SQL] Table variables: where they shine, where they don’t (and why estimates matter)

Deliverables:
- [x] EN: `course/lessons/10_udf_tvf_and_views.md`
- [x] UK: `i18n/uk/course/lessons/10_udf_tvf_and_views.md`
- [x] Labs: UDF/TVF/views patterns and tradeoffs

### Lesson 11 — Indexing & query optimization (deep, flagship)
Goal: systematic performance tuning (not “tips”).

Topics:
- [CORE] Index fundamentals: clustered vs nonclustered
- [CROSS] Covering indexes (INCLUDE), key design patterns
- [CROSS] Filtered indexes / partial indexes; unique indexes/constraints
- [CROSS] Computed columns / generated columns + indexing
- [CROSS] Statistics: why plans change, stale stats symptoms
- [CORE] SARGability (SARGable queries): what it is, why it matters, and how to write them
  - Common SARGability killers: implicit conversions, functions on columns, wildcard patterns
  - Practical date filtering patterns (range predicates)
- [CROSS] Reading execution plans: scan/seek, lookup, spills, memory grants
- [T-SQL] Parameter sniffing basics (intro), Query Store overview (optional)

Recommended structure inside the lesson:
- A repeatable tuning workflow (symptom → hypothesis → measure → change → verify → regressions)
- A “plan reading glossary” for the operators used in labs

Deliverables:
- [x] EN: `course/lessons/11_indexing_and_sargability.md`
- [x] UK: `i18n/uk/course/lessons/11_indexing_and_sargability.md`
- [x] Labs: index/seek/scan + SARGability + covering index patterns
- [x] Provide a “tuning report template” for learners (optional): `templates/tuning_report_template.md`

### Lesson 12 — Data engineering patterns (staging → transform → publish)
Goal: real pipeline patterns on SQL Server.

Topics:
- [CORE] Staging tables, audit columns, schema drift checks
- [CROSS] Incremental loads: watermarking
- [T-SQL] Incremental loads: CDC overview (optional)
- [CROSS] Safer upsert patterns (and `MERGE` caveats)
- [T-SQL] Bulk load options: `BULK INSERT` (overview), minimal logging basics
- [T-SQL] Batching patterns for large modifications (`TOP (N)` loops; lock/log control)
- [CORE] Performance hygiene for pipelines
  - SARGability in incremental loads (watermark predicates)
  - Avoiding implicit conversions between source and target

Deliverables:
- [x] EN: `course/lessons/12_etl_patterns_staging_upsert.md`
- [x] UK: `i18n/uk/course/lessons/12_etl_patterns_staging_upsert.md`
- [x] Labs: staging + upsert + watermark + batching

### Lesson 13 — DBA essentials: backup/restore + HA/DR basics
Goal: operational literacy (RPO/RTO mindset).

Topics:
- [T-SQL] Recovery models, backup chain
- [CROSS] Restore verification and point-in-time restore
- [T-SQL] HA/DR overview: log shipping / availability groups (conceptual)

Deliverables:
- [x] EN: `course/lessons/13_backup_restore_basics.md`
- [x] UK: `i18n/uk/course/lessons/13_backup_restore_basics.md`

### Lesson 14 — Security & governance
Goal: least privilege + safe access patterns.

Topics:
- [T-SQL] Logins vs users
- [CORE] Schemas, roles
- [CORE] Least privilege patterns for analysts vs ETL
- [CORE] Auditing basics

Deliverables:
- [x] EN: `course/lessons/14_security_permissions.md`
- [x] UK: `i18n/uk/course/lessons/14_security_permissions.md`

---

## 2) optimisation_patterns (special-case query optimizations)

This block is a collection of “unique case” performance patterns and rewrites that can be *dramatic wins* in the right scenario, and *total misses* (or regressions) in the wrong one.

Rule: every pattern below must be taught with:
- what problem it solves (symptoms)
- when it helps vs when it doesn’t
- how to validate (actual plan + runtime metrics)

Validation checklist (minimum):
- Compare actual execution plans (not only estimated)
- Compare logical reads (per table) and CPU/time
- Watch for spills, memory grant issues, and row-goal side effects
- If available: validate stability in Query Store (same query text, multiple executions)

Rule for teaching these patterns:
- Provide a minimal reproducible schema + seed data that demonstrates the win/loss clearly
- Explicitly call out correctness risks (duplicates, NULL semantics, changed result cardinality)

### Pattern A — `APPLY` as a controlled rewrite tool

`APPLY` evaluates the right side per left-row. That makes it powerful for per-row “lookups” and per-row derived sets — but it also makes it easy to accidentally create RBAR.

#### A1) Rewrite wide-to-tall (UNPIVOT) using `CROSS APPLY (VALUES ...)`
Use case:
- You have a *wide* row (many columns) and need a *tall* representation (attribute/value rows)
- You need custom labeling, custom filtering, or you want predictable null handling

When it can drastically help:
- Replacing repeated `UNPIVOT` usage inside complex queries (repeated `PIVOT/UNPIVOT` within a single statement can negatively impact performance)
- When it lets you filter early on the generated attribute names/values and avoid extra joins

When it usually does NOT help (or hurts):
- Very wide tables (hundreds of columns) where VALUES expansion becomes huge
- When the result must be aggregated anyway (you might just move the cost around)

#### A2) Replace `PIVOT` with conditional aggregation (`SUM/COUNT(CASE WHEN...)`)
Use case:
- Cross-tab style output, fixed set of output columns

When it can drastically help:
- When you can avoid multiple `PIVOT` operators and do one grouped scan
- When it enables better predicate pushdown and simpler plan shapes

When it usually does NOT help:
- When the `PIVOT` is already clean and the plan is optimal (the optimizer often produces similar plans)
- When you need many pivoted columns and readability/maintenance becomes the bottleneck

#### A3) Top-N per group via `CROSS APPLY (SELECT TOP (N) ... ORDER BY ...)`
Use case:
- “Latest row per customer”, “top 1 per group”, “next event after X”, etc.

When it can drastically help:
- There is a supporting index that matches the seek + order (for example, `(GroupKey, OrderKey DESC)`)
- Outer rows are moderate and each seek is cheap

When it usually does NOT help (or hurts):
- No supporting index (becomes nested loops + sorts / scans)
- Outer input is huge (millions) → per-row evaluation explodes

#### A4) Correlated “lookup” without duplicates (APPLY vs JOIN)
Use case:
- You need one derived row per outer row (e.g., computed aggregates, existence checks, shaped JSON)

When it can help:
- Makes intent explicit (1-to-1 shape) and can avoid accidental fanout duplicates

When it does NOT help:
- When the same logic can be expressed as a set-based join/aggregation once

### Pattern B — OR-expansion into `UNION ALL` (index-seek unlock)

Use case:
- Predicate like `A = @x OR B = @y` prevents good index usage

When it can drastically help:
- Each branch becomes SARGable and gets its own index seek + narrow scan

When it usually does NOT help:
- Branches overlap heavily (you then pay de-dup cost)
- You actually want one plan that adapts (many different parameter shapes)

Must teach:
- Correctness (duplicates): when you need `UNION` vs `UNION ALL` + explicit de-dup

### Pattern C — Semi/anti join shape control (`EXISTS` / `NOT EXISTS`)

Use case:
- You only need to know whether a match exists (or doesn’t)

When it can drastically help:
- Replacing `LEFT JOIN ... WHERE right.col IS NULL` patterns that cause large joins
- Avoiding duplicate amplification from one-to-many joins

When it usually does NOT help:
- If you actually need columns from the right side (you need a join)
- Optimizer may already transform to a semi-join (no gain)

### Pattern D — Pre-aggregation / two-phase queries (reduce rows early)

Use case:
- Large fact table, but final result needs aggregated/grain-reduced data

When it can drastically help:
- First phase shrinks rows by 10x–1000x, making later joins cheap

When it usually does NOT help:
- If it forces extra scans of the same big table
- If the big reduction could already be done in a single grouped query

### Pattern E — Break a monster query into steps (temp tables as an optimizer tool)

Use case:
- The optimizer guesses wrong due to complex predicates, parameter sensitivity, or multi-join fanout

When it can drastically help:
- Materializing intermediate results produces accurate stats and stable join order choices
- Allows you to index intermediate sets for subsequent joins

When it usually does NOT help:
- Small queries (overhead dominates)
- High concurrency with tempdb pressure

### Pattern F — Window functions replacing self-joins / correlated subqueries

Use case:
- “previous/next row”, gap-and-islands, running totals, latest per group

When it can drastically help:
- Replacing repeated correlated subqueries (especially top-1 lookups without good indexes)

When it usually does NOT help:
- If the window requires large sorts and the input is already well-indexed for a top-N APPLY solution

### Pattern G — Make predicates SARGable with computed persisted columns

Use case:
- You must filter by `Expression(Column)` and can’t change the consuming query shape

When it can drastically help:
- Persisted computed column + index turns a scan into a seek

When it usually does NOT help:
- Expression isn’t deterministic or not worth the storage/write overhead

### Pattern H — Filtered indexes for skewed predicates

Use case:
- Common filter like `Status = 'Active'` hits a small subset

When it can drastically help:
- Dramatically smaller index, faster seeks, better cache behavior

When it usually does NOT help:
- Highly variable predicates (many different statuses)
- Parameterization/implicit conversions prevent matching the filter definition

### Pattern I — “Lookup elimination” via covering indexes vs key lookups

Use case:
- Plan shows many key lookups (expensive random IO)

When it can drastically help:
- Turning many lookups into a single covering seek/scan via INCLUDE

When it usually does NOT help:
- When lookups are already few (low row count) and INCLUDE bloats the index unnecessarily

### Pattern J — Join/predicate rewrite to avoid implicit conversions

Use case:
- Execution plan shows `CONVERT_IMPLICIT` and you lose seeks

When it can drastically help:
- Fixing types/parameters can turn scans into seeks instantly

When it usually does NOT help:
- If the dominating cost is elsewhere (big hash join, huge sort/spill)

---

## 3) Specialized module (optional elective)

### Lesson X — Spatial data (geography/geometry) + indexing
Goal: real-world spatial queries, correct SRID usage, and performance via spatial indexes.

Must-cover (SQL Server):
- Constructors/parsers:
  - `geography::Point(lat, lon, SRID)`
  - `geometry::Point(x, y, SRID)`
  - `geography::STGeomFromText(WKT, SRID)` / `geometry::STGeomFromText(WKT, SRID)`
  - `geography::Parse()` / `geometry::Parse()`
- Common methods:
  - `STEquals()`
  - `STIntersects()`
  - `STContains()` / `STWithin()`
  - `STDistance()` (geography: meters)
  - `STBuffer()`
  - `STUnion()`, `STDifference()`, `STIntersection()`
  - `STArea()`, `STLength()`
  - `STAsText()` (WKT)
  - `STSrid` (property)
  - `MakeValid()` (geometry)
- Performance:
  - `SPATIAL INDEX`
  - candidate selection via spatial index vs exact filter
  - index-friendly filtering patterns (especially for `STIntersects`, `STContains`, sometimes `STDistance`)

Deliverables:
- [x] EN: `course/lessons/x_spatial_types_and_indexing.md`
- [x] UK: `i18n/uk/course/lessons/x_spatial_types_and_indexing.md`
- [x] Labs: intro patterns + indexing template

---

## 4) Track mapping (what each “Pro” path includes)

### Pro DA (Data Analyst)
- [x] Lesson 7 (advanced query patterns)
- [x] Lesson 7B (window functions deep dive)
- [x] Lesson 10 (UDF/TVF awareness)
- [x] Lesson 11 (indexing basics + SARGability)
- [x] Add DA-only lesson: Advanced analytics SQL
  - [CORE] `GROUPING SETS` / `ROLLUP` / `CUBE`
  - [T-SQL] `PIVOT` / `UNPIVOT`
  - [CORE] cohort/retention patterns

### Pro DE (Data Engineer)
- [x] Lessons 7–12 (and strongly recommended: Lesson 7B)
- [ ] Strong emphasis: transactions/idempotency, load patterns, performance for pipelines

### Pro DBA
- [x] Lessons 7–11 + 13–14 (and recommended: Lesson 7B)
- [x] Add DBA-only lesson: monitoring & troubleshooting
  - waits/IO/tempdb, baselines, incident workflow

### Pro Engineer (full-stack data product)
- [ ] Capstone: end-to-end project (OLTP schema + pipeline + reporting + ops runbook)
  - [ ] Capstone outputs: schema scripts, load scripts, 10–15 core queries, performance tuning notes, and an ops runbook

---

## 5) Repo integration tasks (must do for every new lesson)

- [x] Add language switcher line at top (EN ↔ UK)
- [x] Update:
  - `LEARNING_PATH.md`
  - `i18n/uk/LEARNING_PATH.md`
  - `navigation.md` and `navigation_detailed.md`
  - `i18n/uk/navigation.md` and `i18n/uk/navigation_detailed.md`
- [x] Re-run generators if needed:
  - `scripts/generate_navigation_en.ps1`
  - `scripts/generate_navigation_uk.ps1`
- [x] Run verification:
  - `scripts/verify_repo.ps1`
- [x] Ensure images (if any) live under `assets/images/` and paths resolve in both locales
  - [x] Automated check: `scripts/check_markdown_links.ps1` (runs in `scripts/verify_repo.ps1`)
- [x] Ensure anchors match navigation generation (avoid manual anchor maintenance)
  - [x] Automated warning: anchored links in `navigation.md` and `i18n/uk/navigation.md`

---

## 6) Quality bar (professional tutor perspective)

For each lesson, require:
- [ ] “Why it matters in production” (1–2 paragraphs)
- [ ] At least 5 hands-on labs with expected results
- [ ] A short checklist: common mistakes + how to debug
- [ ] Include SARGability notes where applicable (what breaks index usage and how to fix it)
- [ ] If the lesson claims performance impact: include IO/time measurements and a plan-based explanation
- [ ] One mini-assessment (5–10 questions)
- [ ] Homework that forces tradeoff thinking (correctness vs performance vs maintainability)

