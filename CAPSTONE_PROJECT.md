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

## Getting started
1. Run schema: [capstone/sql/01_schema.sql](capstone/sql/01_schema.sql)
2. Seed data: [capstone/sql/02_seed_data.sql](capstone/sql/02_seed_data.sql)
3. Run a load batch: [capstone/sql/03_pipeline_load.sql](capstone/sql/03_pipeline_load.sql)
4. Run reports: [capstone/sql/04_reporting_queries.sql](capstone/sql/04_reporting_queries.sql)
5. Read ops guide: [capstone/ops_runbook.md](capstone/ops_runbook.md)

