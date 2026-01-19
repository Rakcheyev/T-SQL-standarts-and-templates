# Ops runbook (capstone)

This runbook documents how to operate the capstone pipeline like a real system.

## Run sequence
1. Apply schema: `capstone/sql/01_schema.sql`
2. Seed: `capstone/sql/02_seed_data.sql`
3. Run a batch: `capstone/sql/03_pipeline_load.sql`
4. Reports: `capstone/sql/04_reporting_queries.sql`

## Rerun safety (idempotency)
- A batch is identified by `@BatchId`.
- The pipeline persists batch metadata in `etl.LoadBatch`.
- If you rerun the same `@BatchId`, the script should be safe (no duplicates).

## What to monitor
- Failures: rows in `etl.LoadBatch` with `Status = 'Failed'`.
- Duration: `StartedAt` → `EndedAt` per batch.
- Blocking: active sessions during the batch (see Lesson 16 for DMV queries).
- Tempdb pressure during transforms (hash joins/sorts/spills).

## Recovery workflow
1. Identify the failing step (staging, transform, publish).
2. Inspect error message (if stored) and row counts.
3. Fix root cause (data type mismatch, constraint violation, missing index).
4. Rerun the same `@BatchId`.
5. If you must start over, create a new `@BatchId` and document why.

## Change management
- Any performance change requires evidence (IO/time + plan) recorded in `capstone/perf_tuning_notes.md`.

