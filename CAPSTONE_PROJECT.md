**Language:** English | [Українська](i18n/uk/CAPSTONE_PROJECT.md)

# Capstone — end-to-end data product (OLTP → pipeline → reporting → ops)

This capstone is a realistic, portfolio-grade project that combines everything from the Pro tracks.

Outputs you will build in this repo:
- OLTP schema + seed data scripts
- staging + incremental load scripts (idempotent)
- 10–15 core reporting queries
- performance tuning notes (before/after evidence)
- an ops runbook (how to run, rerun safely, and monitor)

Project folder: [capstone/](capstone/)

## Scenario
You run a small online store. Orders arrive continuously. Your job is to:
1) model the OLTP data (customers, products, orders)
2) build a repeatable pipeline into curated tables
3) publish reporting queries (daily revenue, retention, top products)
4) document operations (reruns, failures, monitoring)

## Acceptance criteria (definition of done)
- All scripts run from a clean database.
- Pipeline is idempotent: you can rerun the same batch without duplicates.
- Reporting queries return stable, correct results.
- You can explain at least 3 performance wins with IO/time + plan evidence.

## What “good” looks like (review checklist)

Use this as a self-review checklist before calling the capstone “done”.

**Data correctness**
- Every query has an explicit grain (“one row per …”).
- No accidental fanout: joins to one-to-many tables are intentional and validated.
- Incremental load logic is safe under retries (no duplicates, no missed rows).

**Maintainability**
- Scripts are runnable in order and have clear sections (schema, seed, load, reporting).
- Key assumptions are documented (time zone, currency, retention definition, late-arriving data).
- Naming is consistent across OLTP, staging, and curated layers.

**Performance evidence**
- At least 3 improvements documented with:
	- baseline vs improved `SET STATISTICS IO, TIME` output
	- a short explanation of plan/operator change
- Indexes are justified by workload and kept minimal (no “index everything”).

**Operations**
- You can rerun the pipeline safely and you know how to detect partial failures.
- Runbook includes: how to run, how to backfill, what to monitor, and what “bad” looks like.

## Mini-assessment (self-check)

1. What does “idempotent” mean for a load batch, and how do you prove it?
2. Where can duplicates enter the pipeline (at least 3 points)?
3. What is your grain for each curated table and each report?
4. What evidence would you show to justify an index in a PR?
5. If a daily revenue query regresses, what would you check first (data vs plan vs resources)?

## Homework (deliverables + rubric)

**Deliverables**
1. OLTP schema + seed data scripts.
2. Staging + incremental load scripts (with a clear rerun/backfill story).
3. 10–15 reporting queries (include at least 2 that use window functions and 1 cohort-style query).
4. Performance tuning notes: [capstone/perf_tuning_notes.md](capstone/perf_tuning_notes.md)
5. Ops runbook: [capstone/ops_runbook.md](capstone/ops_runbook.md)

**Rubric (quick scoring)**
- Correctness (0–5): deterministic results, no silent duplicates, well-defined grains.
- Portability (0–3): core queries avoid unnecessary T-SQL-only features unless justified.
- Performance (0–5): measured improvements + sensible indexing.
- Ops (0–5): clear runbook and safe reruns/backfills.

## Getting started
1. Run schema: [capstone/sql/01_schema.sql](capstone/sql/01_schema.sql)
2. Seed data: [capstone/sql/02_seed_data.sql](capstone/sql/02_seed_data.sql)
3. Run a load batch: [capstone/sql/03_pipeline_load.sql](capstone/sql/03_pipeline_load.sql)
4. Run reports: [capstone/sql/04_reporting_queries.sql](capstone/sql/04_reporting_queries.sql)
5. Read perf notes template: [capstone/perf_tuning_notes.md](capstone/perf_tuning_notes.md)
6. Read ops guide: [capstone/ops_runbook.md](capstone/ops_runbook.md)

