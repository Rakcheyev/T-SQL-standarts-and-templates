**Language:** English | [Українська](../../i18n/uk/course/lessons/16_monitoring_and_troubleshooting.md)

<h2 align="center">Lesson 16 — Monitoring, troubleshooting, and baselines (SQL Server)</h2>

*Intro:* Production problems rarely look like “a slow query”. They show up as timeouts, CPU spikes, blocking chains, tempdb pressure, or a sudden increase in I/O latency. This lesson gives you a practical, repeatable incident workflow and a small set of trustworthy DMVs to answer: “What is happening right now?” and “What changed compared to normal?”

**DBMS scope:** [CROSS] monitoring concepts; examples are [T-SQL] (SQL Server DMVs, Query Store).

## Goal
Learn a minimal monitoring and troubleshooting toolkit:
- a basic incident workflow (symptom → evidence → hypothesis → change → verify)
- current activity inspection (requests, waits, blocking)
- baselining (what “normal” looks like)
- common pain areas: waits, I/O, tempdb, memory grants/spills

## Prerequisites
- Lesson 11 (Indexing and SARGability) recommended.

## Safety notes
- DMVs are a snapshot; take multiple samples over time.
- On busy production servers, avoid running heavy diagnostic queries too frequently.
- Some labs use server-wide views (`sys.dm_os_*`). Use a dev instance if you can.

## Incident workflow (repeatable)
1. Define the symptom precisely (CPU? latency? blocking? error rate?).
2. Capture *current* evidence (active requests, waits, blocking).
3. Compare to baseline (is this new or expected at this time?).
4. Make one controlled change (kill a runaway session, add index, change query, increase resources).
5. Verify and document (what you changed, what improved, what you’ll prevent next).

## Labs

### Lab 1 — Current activity: active requests + wait type
Task: list currently running user requests (excluding your own session) with wait info.

```sql
SELECT TOP (50)
    r.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    r.cpu_time,
    r.total_elapsed_time,
    DB_NAME(r.database_id) AS database_name,
    SUBSTRING(t.text, (r.statement_start_offset/2) + 1,
        CASE WHEN r.statement_end_offset = -1
             THEN (DATALENGTH(t.text) - r.statement_start_offset)/2 + 1
             ELSE (r.statement_end_offset - r.statement_start_offset)/2 + 1
        END) AS running_statement
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s
    ON s.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.is_user_process = 1
  AND r.session_id <> @@SPID
ORDER BY r.total_elapsed_time DESC;
```

Expected result:
- On an idle instance you may see 0 rows.
- On a busy instance you should see wait types like `CXPACKET`, `PAGEIOLATCH_*`, `LCK_M_*`, `SOS_SCHEDULER_YIELD`, etc.

### Lab 2 — Blocking chain: find who blocks whom
Task: show sessions that are blocked and the session that blocks them.

```sql
SELECT
    r.session_id AS blocked_session_id,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    DB_NAME(r.database_id) AS database_name
FROM sys.dm_exec_requests r
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;
```

Expected result:
- If there’s blocking, you’ll see blocked sessions with `LCK_M_*` waits and a non-zero `blocking_session_id`.

### Lab 3 — Wait stats snapshot (baseline building)
Task: capture top waits since last restart (or last reset) and interpret carefully.

```sql
SELECT TOP (20)
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    CAST(100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER(), 0) AS decimal(5,2)) AS pct
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE 'SLEEP%'
  AND wait_type NOT LIKE 'BROKER%'
ORDER BY wait_time_ms DESC;
```

Expected result:
- You’ll see a ranked list. Focus on *dominant* waits (high percentage), not the long tail.

Optional reset (dev only):
```sql
-- WARNING: resets server-wide wait stats.
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
```

### Lab 4 — Tempdb pressure: top sessions by tempdb allocations
Task: find sessions consuming tempdb space.

```sql
SELECT TOP (50)
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    (t.user_objects_alloc_page_count - t.user_objects_dealloc_page_count) AS user_obj_pages,
    (t.internal_objects_alloc_page_count - t.internal_objects_dealloc_page_count) AS internal_obj_pages
FROM sys.dm_db_session_space_usage t
JOIN sys.dm_exec_sessions s
    ON s.session_id = t.session_id
WHERE s.is_user_process = 1
ORDER BY (t.user_objects_alloc_page_count - t.user_objects_dealloc_page_count)
       + (t.internal_objects_alloc_page_count - t.internal_objects_dealloc_page_count) DESC;
```

Expected result:
- If a query spills or uses large hashes/sorts, internal object pages tend to grow.

### Lab 5 — I/O latency quick check by database file
Task: identify files with high read/write latency.

```sql
SELECT
    DB_NAME(vfs.database_id) AS database_name,
    mf.type_desc,
    mf.physical_name,
    vfs.num_of_reads,
    vfs.io_stall_read_ms,
    CAST(vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) AS decimal(12,2)) AS avg_read_ms,
    vfs.num_of_writes,
    vfs.io_stall_write_ms,
    CAST(vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) AS decimal(12,2)) AS avg_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf
    ON mf.database_id = vfs.database_id
   AND mf.file_id = vfs.file_id
ORDER BY (vfs.io_stall_read_ms + vfs.io_stall_write_ms) DESC;
```

Expected result:
- Look for outliers: very high `avg_read_ms` or `avg_write_ms` compared to other files.

### Lab 6 — Query Store: find regressed queries (if enabled)
Task: list queries with the highest average duration recently.

```sql
-- Requires Query Store enabled on the current database.
SELECT TOP (20)
    qsq.query_id,
    qsp.plan_id,
    rs.avg_duration,
    rs.count_executions,
    rs.last_execution_time,
    LEFT(qst.query_sql_text, 4000) AS query_text
FROM sys.query_store_runtime_stats rs
JOIN sys.query_store_plan qsp
    ON qsp.plan_id = rs.plan_id
JOIN sys.query_store_query qsq
    ON qsq.query_id = qsp.query_id
JOIN sys.query_store_query_text qst
    ON qst.query_text_id = qsq.query_text_id
ORDER BY rs.avg_duration DESC;
```

Expected result:
- On a database with Query Store activity, you should see the “heavy hitters” quickly.

## Common mistakes (and how to debug)
- Treating one snapshot as truth: sample over time.
- Ignoring `blocking_session_id` and only staring at wait stats.
- Blaming one query when the symptom is actually resource contention.
- Overusing `NOLOCK`: it hides symptoms and can return incorrect results.

## Summary
- Troubleshooting is a loop: define symptom, capture evidence, compare to baseline, change one thing, verify.
- Start with current activity (requests + waits + blocking), then expand to wait stats and I/O.
- Use baselines to avoid chasing “normal” nightly batch workload as if it’s an incident.

References:
- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views
- https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-and-tune-for-performance

*Conclusion:* Monitoring is not about collecting everything—it’s about having a small set of queries you trust under pressure and a workflow that keeps you calm and evidence-driven.
