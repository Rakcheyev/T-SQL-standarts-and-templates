**Language:** English | [Українська](i18n/uk/PRO_DE_TRACK_GUIDE.md)

# Pro DE (Data Engineer) — track guide

This guide turns the Pro DE TODO (“strong emphasis: transactions/idempotency, load patterns, performance for pipelines”) into concrete learning goals and checklists.

## Recommended prerequisites
- Follow the main order in [LEARNING_PATH.md](LEARNING_PATH.md) through Lesson 6.

## Core lessons for Pro DE
Recommended sequence (with the “why”):
1. Lesson 7 — safe query patterns (correctness before speed)
2. Lesson 7B — window functions deep dive (de-dupe, sequencing, top-N per group)
3. Lesson 8 — transactions & concurrency (reliability under load)
4. Lesson 9 — stored procedures + error handling (production-grade DML)
5. Lesson 11 — indexing & SARGability (repeatable tuning)
6. Lesson 12 — ETL patterns (staging → upsert → batching)

## What to emphasize (the Pro DE focus)

### 1) Transactions and reliability
Checklist:
- Use explicit transactions when a unit of work must be atomic.
- Keep transactions short (avoid interactive prompts inside a transaction).
- Understand isolation level tradeoffs (blocking vs consistency).
- Handle retries safely (only when the operation is idempotent or guarded).

Practical patterns:
- “Write-ahead” audit rows and status transitions (Pending → Applied → Failed).
- Exactly-once *effect* via constraints + `NOT EXISTS` guards.

### 2) Idempotency (the #1 ETL survival skill)
Checklist:
- Every load should be safe to rerun.
- Separate *extract* time and *effective* time.
- Use deterministic natural keys or stable surrogate mapping.
- Enforce uniqueness with constraints (don’t rely on “best effort” logic).

Common approaches:
- Stage raw rows, then upsert into a curated table.
- Record source watermark + batch id; persist outcomes.

### 3) Load patterns (staging → transform → publish)
Checklist:
- Validate schema drift and nullability in staging.
- Always include audit columns (`load_batch_id`, `loaded_at`, `source_file`, etc.).
- Prefer set-based upsert; batch large modifications.

### 4) Performance for pipelines
Checklist:
- Write SARGable watermark predicates (range on raw datetime/date columns).
- Avoid implicit conversions between staging and target.
- Watch tempdb usage for hash joins/sorts/spills.
- Measure with `SET STATISTICS IO, TIME ON` when performance is claimed.

Operational tips:
- If a load grows, first add the right indexes on staging/targets (often on business keys + watermark).
- Reduce row width early (project only needed columns).

## Mini self-assessment (10 questions)
1. What makes an operation idempotent?
2. Why do long transactions increase blocking risk?
3. When is `MERGE` risky, and what safer patterns exist?
4. What’s the difference between “rows processed” and “rows returned”?
5. Why is `CONVERT(date, EventTime)` often non-SARGable?
6. What is a watermark, and what are its common failure modes?
7. Why do hash joins and sorts often pressure tempdb?
8. What is an “exactly-once effect” in a pipeline?
9. What should you persist to support safe retries?
10. What evidence do you collect before and after a performance change?

## Suggested capstone direction (DE-flavored)
If you want to build a Pro DE portfolio piece, implement:
- a staging table
- a curated dimension + fact table
- an incremental load with a watermark
- an upsert strategy + batching
- a small ops runbook (how to rerun safely, what to monitor)

## References
- https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql
- https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-and-tune-for-performance

