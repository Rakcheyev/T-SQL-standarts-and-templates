# Validation checks (capstone)

These checks are meant to be copy-paste friendly and safe to run repeatedly.

The capstone SQL scripts already include dedicated **Validation** / **Sanity checks** blocks.
Use this document as a quick index for where to find them and what they prove.

## Where the checks live

1. Schema checks: `capstone/sql/01_schema.sql`
   - Confirms required schemas exist (`etl`, `stg`, `dw`).
   - Confirms required objects exist (tables in each layer).

2. Seed data checks: `capstone/sql/02_seed_data.sql`
   - Row counts for OLTP tables.
   - Orphan checks (referential integrity).

3. Pipeline load checks: `capstone/sql/03_pipeline_load.sql`
   - Batch status for the current `@BatchId`.
   - Stage row counts for the batch.
   - DW row counts (dims/fact).
   - Expected vs actual fact rows for the batch.
   - Duplicate fact check and orphan dimension reference check.

4. Reporting checks: `capstone/sql/04_reporting_queries.sql`
   - Quick DW row counts.
   - Recent batch history.
   - Orphan facts check.

## Minimal “definition of correct”

After running the pipeline:
- `etl.LoadBatch` shows your batch as `Succeeded`.
- Orphan checks return `0`.
- Rerunning `capstone/sql/03_pipeline_load.sql` with the same `@BatchId` does not change:
  - stage row counts for that `@BatchId`
  - DW row counts
  - expected vs actual fact rows

## Tips

- Treat every data quality check as a unit test for your pipeline logic.
- If a check fails, write down:
  - what changed (data, code, indexes, stats)
  - how you reproduced it
  - how you verified the fix
