**Мова:** [English](../../../../course/lessons/16_monitoring_and_troubleshooting.md) | Українська

<h2 align="center">Урок 16 — Моніторинг, troubleshooting та baselines (SQL Server)</h2>

*Вступ:* У проді проблеми рідко виглядають як “повільний запит”. Частіше це таймаути, стрибки CPU, довгі ланцюги блокувань, тиск на tempdb або раптове зростання I/O latency. У цьому уроці — практичний incident workflow і мінімальний набір DMV-запитів, щоб швидко відповісти: “Що відбувається зараз?” і “Що змінилося відносно норми?”.

**Сфера DBMS:** [CROSS] концепти моніторингу; приклади — [T-SQL] (DMV SQL Server, Query Store).

## Мета
Навчитися базовому набору для troubleshooting:
- incident workflow (симптом → докази → гіпотеза → зміна → перевірка)
- аналіз поточної активності (requests, waits, blocking)
- baselines (що таке “норма” для вашої системи)
- часті точки болю: waits, I/O, tempdb, memory grants/spills

## Передумови
- Рекомендовано: Урок 11 (індекси та SARGability).

## Чому це важливо у проді

Більшість команд втрачають години не тому, що їм бракує “ще одного DMV-запиту”, а тому що немає спільного workflow, який перетворює симптоми на докази, а докази — на безпечну контрольовану зміну.

Якщо ви швидко відповідаєте на (1) що зараз виконується, (2) на що воно чекає, (3) хто кого блокує, і (4) що змінилося відносно baseline — ви перестаєте гадати. Інциденти стають коротшими, менше ризикових “рандомних рестартів”, і простіше запобігати повторенням.

## Нотатки з безпеки
- DMV — це snapshot; робіть кілька вимірів у часі.
- На завантаженому прод-сервері не запускайте важкі діагностичні запити занадто часто.
- Частина lab-ів використовує server-wide DMV (`sys.dm_os_*`). Краще робити це на dev/тест інстансі.

## Incident workflow (повторюваний)
1. Чітко сформулюйте симптом (CPU? latency? blocking? error rate?).
2. Зніміть докази “прямо зараз” (active requests, waits, blocking).
3. Порівняйте з baseline (це нове чи очікуване в цей час?).
4. Зробіть одну контрольовану зміну (зупинити runaway-сесію, індекс, переписати запит, ресурси).
5. Перевірте ефект і задокументуйте (що зробили, що стало краще, як запобігти повторенню).

## Labs

### Lab 1 — Поточна активність: active requests + wait type
Задача: показати активні користувацькі запити (окрім вашої сесії) з wait-інфо.

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

Очікувано:
- На “тихому” інстансі може бути 0 рядків.
- На завантаженому — побачите waits типу `CXPACKET`, `PAGEIOLATCH_*`, `LCK_M_*`, `SOS_SCHEDULER_YIELD` тощо.

### Lab 2 — Blocking chain: хто кого блокує

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

Очікувано:
- Якщо є blocking, будуть `LCK_M_*` waits і `blocking_session_id <> 0`.

### Lab 3 — Wait stats snapshot (будуємо baseline)

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

Очікувано:
- Отримаєте список “топ” waits. Дивіться на домінуючі waits (великий відсоток), а не на хвіст.

Опційно (тільки dev):
```sql
-- УВАГА: скидає server-wide wait stats.
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
```

### Lab 4 — Tempdb pressure: топ-сесії за tempdb allocations

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

Очікувано:
- При spill/hashes/sorts часто ростуть internal object pages.

### Lab 5 — I/O latency: швидка перевірка по файлах

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

Очікувано:
- Шукайте аутлайери: дуже високий `avg_read_ms` або `avg_write_ms` порівняно з іншими файлами.

### Lab 6 — Query Store: знайти “важкі” запити (якщо увімкнено)

```sql
-- Потрібен Query Store, увімкнений у поточній БД.
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

Очікувано:
- На БД з активністю Query Store швидко побачите “heavy hitters”.

## Типові помилки (і як дебажити)
- Робити висновки з одного snapshot: вимірюйте у часі.
- Ігнорувати `blocking_session_id` і дивитися тільки на wait stats.
- Шукати “винний запит”, коли симптом — ресурсна конкуренція.
- Зловживати `NOLOCK`: воно ховає симптоми й може повертати некоректні дані.

## Міні-оцінювання (самоперевірка)

1. Чому DMV — це “snapshot”, і як ви компенсуєте це під час інциденту?
2. Чим відрізняється blocked-сесія від сесії, яка чекає на I/O?
3. Навіщо baseline, якщо є Query Store?
4. Коли доречно “вбити” сесію, і які докази варто зняти перед цим?
5. Чому “top waits з моменту рестарту” може бути оманливим без контексту?
6. Назвіть дві типові причини tempdb pressure у workload.

## Домашнє (практика інцидентів)

1. Зробіть “1-сторінковий runbook” для свого середовища: які 3 DMV-запити ви запускаєте першими, у якому порядку, і що кожен відповідає.
2. На dev-базі зберіть відтворюваний blocking-демо (дві сесії, одна транзакція лишається відкритою) і використайте Lab 2, щоб знайти blocker.
3. Для Lab 5 визначте, що таке “погана latency” у вашому середовищі (хоча б як заглушка) і зафіксуйте, що б перевіряли поза SQL Server (storage, VM-метрики тощо).
4. (Опційно) Якщо Query Store увімкнено: оберіть один запит і задокументуйте:
    - baseline продуктивності,
    - зміну, яка викликає регресію,
    - як би ви виявили і мітігували регресію.

## Підсумок
- Troubleshooting — це цикл: симптом → докази → baseline → одна зміна → перевірка.
- Стартуйте з поточної активності (requests + waits + blocking), потім переходьте до wait stats та I/O.
- Baselines допомагають не сприймати “нормальний” нічний batch як інцидент.

Довідка:
- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views
- https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-and-tune-for-performance

*Висновок:* Моніторинг — це не “збирати все”, а мати невеликий набір запитів, яким ви довіряєте під стресом, і workflow, який тримає вас в режимі доказів, а не припущень.
