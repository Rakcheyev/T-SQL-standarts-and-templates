**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_8_transactions_concurrency.md)

<h2 align="center">Lesson 8 — Transactions, concurrency, locking, deadlocks</h2>

*Intro:* Concurrency is where “works on my machine” SQL fails: blocking, lock waits, and deadlocks appear only under overlap. You’ll learn what locks and isolation levels really mean, how to reproduce issues with two sessions, and which patterns keep transactions small and retryable.

**DBMS scope:** [CORE] transactions + [CROSS] concurrency concepts; SQL Server specifics are [T-SQL] (RCSI/SNAPSHOT demos).

This lesson is deliberately practical: you’ll open two query windows and watch how one session’s choices become another session’s wait time. That experience makes the concepts stick—because “blocking” stops being a theory and becomes an observable effect you can diagnose.

You’ll build a simple mental model for why locks exist (correctness), why they sometimes hurt (contention), and how isolation levels shift the trade-offs. Then we’ll focus on engineering patterns you can apply without heroics: keep transactions short, touch rows in a consistent order, avoid unnecessary work while holding locks, and design your code so deadlock victims can safely retry.

## Goal
Understand why production workloads block/deadlock, and learn safe, retryable patterns.

## Prerequisites
- Basic DML (Lesson 4)

## Who this lesson is for
- Analysts and BI users: helps you understand why a query “hangs” (blocking) and why `NOLOCK` is a risky band-aid.
- Backend engineers: helps you design safe writes and retry logic.
- Junior DBAs: gives you the mental model to diagnose blocking/deadlocks.

## What you need (tools)
- Two query windows (two sessions) in SSMS or Azure Data Studio.
- A sandbox database where you’re allowed to run `CREATE TABLE`.

## How to run the labs without getting stuck
1. Open **Session A** and **Session B**.
2. Copy/paste the lab blocks exactly as written.
3. If Session B blocks and you want to “unstick” it: `COMMIT` or `ROLLBACK` in Session A.
4. If something goes wrong: rerun the **Lab setup** to reset state.

## Key definitions
- **Transaction**: a unit of work that either fully succeeds (`COMMIT`) or is undone (`ROLLBACK`).
- **Blocking**: session A holds a lock needed by session B.
- **Deadlock**: two (or more) sessions each hold locks the other needs; SQL Server chooses a victim (error 1205).

## What’s really happening (newbie explanation)
### Locks
**What it is:** the database protects data correctness by taking locks (or using row versions, depending on isolation).

**Why it’s used:** without locking/versioning, two users could overwrite each other’s updates or read inconsistent data.

**Benefits:**
- correctness (no “half-written” reads under default settings)
- predictable transactional behavior

**Pitfalls:**
- long transactions hold locks longer → other sessions wait (blocking)
- under heavy load, deadlocks can happen if sessions touch rows in different orders

### Isolation level (high-level)
**What it is:** rules that define what a transaction is allowed to read while other transactions write.

**Why it’s used:** you choose a tradeoff between concurrency and consistency.

Beginner takeaway:
- Start with the default (`READ COMMITTED`) and learn to recognize blocking.
- If your workload is read-heavy and blocking is a problem, investigate RCSI/SNAPSHOT in a controlled way.

## Isolation levels (SQL Server)
- `READ COMMITTED` (default): reads don’t see uncommitted data, but can be blocked by writers.
- **RCSI** (Read Committed Snapshot): changes read committed semantics to use row versioning.
- `SNAPSHOT`: consistent view of committed data at transaction start; update conflicts can occur.
- `SERIALIZABLE`: strongest, prevents phantoms; can lock ranges.

Note: RCSI and SNAPSHOT require database-level configuration.

## Recommended patterns

### Pattern 1 — Keep transactions short
- do validation before the transaction when possible
- touch rows in a consistent order

### Pattern 2 — Idempotent updates
Design writes so retries are safe.

### Pattern 3 — Retry deadlocks
Deadlocks are normal under concurrency; retry with backoff.

## Labs (requires 2 sessions)
These labs are “procedural”: open **Session A** and **Session B**.

### Lab setup
This lab uses the simplest “money transfer” model on purpose: two accounts and a balance. When you see blocking and deadlocks here, you can be confident it’s not a business-logic bug—it’s concurrency mechanics.

We keep the table narrow so it’s easy to reason about what is locked. In real systems the same patterns happen on wider tables and across multiple indexes; the only difference is that diagnosing it becomes harder.

Run this setup whenever you want to reset the world to a known state. That repeatability matters: concurrency labs are easy to “mess up” if a previous transaction is still open.
```sql
DROP TABLE IF EXISTS dbo.Accounts;
GO

CREATE TABLE dbo.Accounts(
  AccountID int NOT NULL PRIMARY KEY,
  Balance money NOT NULL
);

INSERT INTO dbo.Accounts(AccountID, Balance)
VALUES (1, 100.00), (2, 100.00);
GO
```

### Lab 1 — Basic transaction and rollback
This is the foundational promise of a transaction: the system treats a group of statements as one unit of work. Either *all* statements take effect, or *none* do. If you’re new to this, it helps to think of a transaction as a “draft mode” for changes.

The code simulates a transfer: subtract from account 1, add to account 2. In between, you can run a `SELECT` to inspect the balances. Inside the same transaction you will see your own uncommitted changes; other sessions will behave according to their isolation level.

Finally, `ROLLBACK` proves the point: both updates are undone. This is not just a teaching trick—rollback is what keeps production systems correct when something fails mid-flight.
```sql
BEGIN TRAN;
UPDATE dbo.Accounts SET Balance = Balance - 10 WHERE AccountID = 1;
UPDATE dbo.Accounts SET Balance = Balance + 10 WHERE AccountID = 2;
-- Inspect balances here
ROLLBACK;
```
Expected: balances return to original values after rollback.

### Lab 2 — Blocking demo
Blocking is easiest to understand if you visualize a single row as a resource that can be “held” by one session while it is being modified. When Session A updates the row for `AccountID = 1` and keeps the transaction open, it is effectively saying: “this row is in the middle of change; nobody else can modify it until I’m done.”

Session B then tries to update the same row. SQL Server must protect correctness, so it makes Session B wait. This waiting is not a bug; it’s the database choosing safety over concurrency.

The practical lesson is that open transactions are not free. Even if you’re “just waiting” in your app, you may be holding locks that block other users. The fix is not `NOLOCK`—the fix is to keep the transaction short and commit/rollback promptly.
Session A:
```sql
BEGIN TRAN;
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 1;
-- Do not commit yet
```

Session B (will block):
```sql
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 1;
```

Fix: Session A `COMMIT` or `ROLLBACK`.

### Lab 3 — Lock timeout
In production, letting a request wait forever is rarely acceptable. A lock timeout turns “hangs” into a predictable failure you can handle: log it, retry it, or surface an error to the user.

`SET LOCK_TIMEOUT` is session-scoped. It affects how long *this session* will wait to acquire a lock before it gives up with error 1222. That’s a useful tool in batch jobs and diagnostic scripts.

Notice the bigger idea: timeouts are part of a reliability strategy. If you pair a lock timeout with idempotent logic and safe retries, you can keep a system responsive even under contention.
Session B:
```sql
SET LOCK_TIMEOUT 2000; -- 2 seconds
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 1;
```
Expected: after ~2 seconds, error 1222 (lock timeout) if Session A holds the lock.

### Lab 4 — Deadlock demo (classic)
A deadlock is blocking with a cycle: Session A holds one lock and waits for another, while Session B holds the other lock and waits for the first. If nobody intervenes, both sessions would wait forever.

SQL Server resolves this by picking a victim. One transaction is rolled back (error 1205), and the other is allowed to continue. This is why “deadlocks are normal” under concurrency: they are a mechanism, not an exception to the laws of physics.

The `WAITFOR` is here to make the timing deterministic so you can reproduce the cycle. In real systems, the timing is created by workload and scheduling, which is why deadlocks can feel random until you learn to read the deadlock graph.
Session A:
```sql
SET DEADLOCK_PRIORITY LOW;
BEGIN TRAN;
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 1;
WAITFOR DELAY '00:00:05';
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 2;
COMMIT;
```

Session B (run quickly after A starts):
```sql
BEGIN TRAN;
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 2;
WAITFOR DELAY '00:00:05';
UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountID = 1;
COMMIT;
```
Expected: one session gets error 1205 (deadlock victim).

### Lab 5 — Safe retry outline (application or T-SQL)
Once you accept that deadlocks can happen, the engineering question becomes: “how do I recover safely?” The standard answer is a retry loop with a small backoff. The backoff matters because it reduces the chance that the same two sessions collide again immediately.

Retries only work when the operation is safe to repeat. That’s why earlier we emphasized idempotent patterns: if the same logical request can be executed twice without double-applying side effects, retries become a reliability feature rather than a risk.

Many teams implement retries in the application layer because it’s easier to centralize logging, backoff strategy, and cancellation. But the principle is the same in T‑SQL: keep the transaction small, catch error 1205, wait, and try again.
Pseudo-pattern:
- try transaction
- if error 1205, wait a bit and retry

In T-SQL, retries are possible, but many teams implement retries in the app layer.

## Common mistakes
Most concurrency pain in production is self-inflicted: transactions are held open longer than necessary, and different code paths touch the same tables in different orders. The database then has no choice but to block, and under enough overlap, it may deadlock.

If you remember only one operational rule, make it this: do as much work as possible *outside* the transaction, and as little work as possible *inside* it. Validate inputs first; then open the transaction, touch the rows, and commit.

Finally, be suspicious of “quick fixes”. `NOLOCK` can make the waiting go away, but it does so by weakening correctness. If you use it, use it because the business explicitly accepts inconsistent reads—not because you wanted the query to finish.
- Big transactions that do multiple unrelated steps.
- Inconsistent row access order across procedures (deadlock factory).
- Disabling locks with `NOLOCK` to “fix” blocking (can return incorrect results).

Practical newbie warning:
- `NOLOCK` is not “faster reads”. It changes correctness guarantees. Use it only when you explicitly accept inconsistent results.

## Summary
- Blocking and deadlocks are concurrency mechanics, not “bugs”.
- Your job is to design transactions and indexes so the engine can do the minimum work.

- Microsoft Docs: [SQL Server transaction locking and row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide), [SET TRANSACTION ISOLATION LEVEL (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)

*Conclusion:* Treat blocking and deadlocks as normal mechanics. Keep transactions short, touch rows in a consistent order, and build safe retry logic—then your workload stays correct even under pressure.
