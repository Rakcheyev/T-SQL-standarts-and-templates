**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_9_stored_procedures_error_handling.md)

<h2 align="center">Lesson 9 — Stored procedures and error handling</h2>

*Intro:* Stored procedures are a contract: either the whole operation succeeds or nothing changes, and failures leave the session clean. You’ll practice a production template with TRY/CATCH, THROW, and XACT_STATE(), plus a simple audit trail—so database code behaves predictably under errors.

**DBMS scope:** [CROSS] stored-procedure “contract” patterns + [T-SQL] error-handling template (`TRY...CATCH`, `THROW`, `XACT_STATE()`).

The point isn’t to memorize syntax; it’s to standardize behavior. When every procedure follows the same error-handling shape, your application can rely on consistent outcomes (commit vs rollback), logs become meaningful, and “mystery half-writes” stop happening.

You’ll practice writing multi-step work as one unit, proving that your transaction boundaries match the business boundary. We’ll also treat observability as part of correctness: a small audit entry—written at the right time—turns a failure from a guessing game into something you can explain.

By the end, you should be able to look at a procedure and answer quickly: What is the success contract? What happens on error? Can this safely be retried? And does the caller get a clean, actionable exception?

## Goal
Write production-grade database code: predictable, safe under errors, and supportable.

## Prerequisites
- Transactions (Lesson 8)

## Who this lesson is for
- If you mostly write ad-hoc queries: this teaches you how to package work into a reliable “database API”.
- If you’re a backend engineer: this gives you safe templates that play well with application error handling.
- If you’re maintaining a legacy database: this clarifies what to standardize first (error handling, transactions, audit).

## What “professional” database code looks like
- Predictable: either the whole operation succeeds or nothing changes.
- Observable: you can trace what happened (auditing/logging).
- Safe under failure: errors are not swallowed; the transaction is left in a clean state.

## What a stored procedure is (beginner-friendly)
**What it is:** a named program stored in SQL Server that you execute with parameters.

**Why it’s used:** it becomes a stable “database API” so applications call `EXEC dbo.usp_DoThing @Id=...` instead of sending big ad-hoc SQL strings.

**Benefits:**
- consistency: one canonical place for business rules
- security: you can grant `EXECUTE` without granting direct table permissions
- maintainability: changes are localized

**Pitfalls:**
- procedures can still be slow; you still need good indexing and good query patterns
- overusing procedures for tiny queries can add complexity without value
- dynamic SQL inside procedures requires careful parameterization

## How to use this lesson
1. Run the lab setup.
2. Execute each lab and confirm the expected behavior.
3. Intentionally break it (not found / constraint violation) and verify that the audit table stays consistent.

## Why stored procedures
- stable API for the application
- parameterization reduces SQL injection risk
- permissions can be granted at the procedure level

## Error handling (SQL Server)
Key tools:
- `TRY...CATCH`
- `THROW` (preferred over legacy `RAISERROR` for new code)
- `XACT_STATE()` to decide whether you can commit

## Pattern: safe transaction template
```sql
CREATE OR ALTER PROCEDURE dbo.usp_DoWork
  @SomeId int
AS
BEGIN
  SET NOCOUNT ON;

  BEGIN TRY
    BEGIN TRAN;

    -- Your work here

    COMMIT;
  END TRY
  BEGIN CATCH
    IF XACT_STATE() <> 0
      ROLLBACK;

    -- Rethrow preserving original error
    THROW;
  END CATCH
END;
GO
```

## Labs

### Lab setup
The goal of this setup is to create a tiny, controlled environment where “business correctness” and “operational correctness” are both visible. The `Products` table represents a piece of business state, while `AuditLog` represents your ability to explain what happened later.

Notice the check constraint on `Price`. Constraints are not just “data validation”; they are part of your error-handling story. A well-designed procedure must behave predictably when the database refuses invalid data.

Finally, starting with one product is deliberate. It makes the happy path and the not-found path unambiguous, which is exactly what you want when you’re learning (or standardizing) patterns.
```sql
DROP TABLE IF EXISTS dbo.AuditLog;
DROP TABLE IF EXISTS dbo.Products;
GO

CREATE TABLE dbo.Products(
  ProductID int NOT NULL PRIMARY KEY,
  ProductName nvarchar(50) NOT NULL,
  Price decimal(10,2) NOT NULL,
  CONSTRAINT CK_Products_Price CHECK (Price >= 0)
);

CREATE TABLE dbo.AuditLog(
  AuditID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  EventTime datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  Event nvarchar(200) NOT NULL
);
GO

INSERT INTO dbo.Products(ProductID, ProductName, Price)
VALUES (1, N'Keyboard', 50.00);
GO
```

### Lab 1 — Create a procedure that updates price and audits
This lab builds a procedure that has to satisfy three requirements simultaneously: (1) it must update data, (2) it must record an audit trail, and (3) it must remain correct when something goes wrong. That combination is what makes stored procedures feel “serious” compared to ad-hoc statements.

Pay attention to the order of operations. We update first, validate that something actually changed (`@@ROWCOUNT`), and only then insert into the audit log. That ordering is intentional: you don’t want audit rows that claim success when the update didn’t touch anything.

Also notice the error path. We roll back if we are in a transactionable state, and then rethrow with `THROW` so the caller can react. The procedure does not attempt to hide failure; it guarantees the database is left clean and the error is propagated.
```sql
CREATE OR ALTER PROCEDURE dbo.usp_UpdatePrice
  @ProductID int,
  @NewPrice decimal(10,2)
AS
BEGIN
  SET NOCOUNT ON;

  BEGIN TRY
    BEGIN TRAN;

    UPDATE dbo.Products
    SET Price = @NewPrice
    WHERE ProductID = @ProductID;

    IF @@ROWCOUNT = 0
      THROW 50001, 'Product not found', 1;

    INSERT INTO dbo.AuditLog(Event)
    VALUES (CONCAT('Updated ProductID=', @ProductID, ' Price=', @NewPrice));

    COMMIT;
  END TRY
  BEGIN CATCH
    IF XACT_STATE() <> 0
      ROLLBACK;
    THROW;
  END CATCH
END;
GO
```

### Lab 2 — Happy path
This is where you confirm the “normal” behavior: the row is updated and exactly one audit event is written. The key habit is to verify both the business state (`Products`) and the operational state (`AuditLog`). If you only check the data, you can miss silent failures in logging; if you only check the logs, you can miss incorrect writes.

When you rerun the procedure with different prices, you should see the audit trail accumulating. In real systems, teams often include additional context (user, correlation id, source system), but the fundamental pattern is the same: record a durable explanation of the change.

If you’re curious, this is also a good place to open the actual plan and observe that the update is keyed by `ProductID`. Good procedure design and good indexing go together.
```sql
EXEC dbo.usp_UpdatePrice @ProductID = 1, @NewPrice = 60.00;
SELECT * FROM dbo.Products;
SELECT TOP (5) * FROM dbo.AuditLog ORDER BY AuditID DESC;
```
Expected: price changes to 60.00 and an audit row is added.

### Lab 3 — Not found path
“Not found” is not an edge case—it is one of the most common real error modes. IDs go stale, users click twice, messages are retried, and upstream systems race. If your procedure does not define how it behaves for “missing row”, your application will end up implementing that logic inconsistently.

Here, the procedure turns “nothing updated” into a deliberate error with a custom error number. That makes the outcome explicit for the caller. The important guarantee is that the audit log stays consistent: no misleading “updated” event is written.

In a real codebase you’d standardize error numbers and messages. Consistency here pays off later when you build monitoring and incident response.
```sql
EXEC dbo.usp_UpdatePrice @ProductID = 999, @NewPrice = 10.00;
```
Expected: error 50001, and no audit row is added.

### Lab 4 — Constraint violation path
This scenario is about respecting the database as the last line of defense. The check constraint rejects negative prices. Your job is not to “work around” that—it’s to ensure that when the database rejects the change, your procedure behaves cleanly.

The key observation is that the failure happens *inside* the transaction. If you don’t catch and roll back, you can leave the session in a bad transactional state, which then causes confusing follow-up errors. The template `TRY...CATCH` + `XACT_STATE()` is exactly for this.

Again, validate the audit log: there should be no audit row, because the change did not commit. In production, that property is essential for trust in your auditing.
```sql
EXEC dbo.usp_UpdatePrice @ProductID = 1, @NewPrice = -1.00;
```
Expected: check constraint error; transaction rolled back; no audit row.

### Lab 5 — Permissions idea (concept)
Permissions are where stored procedures really earn their keep. If you let an application role update tables directly, you’ve tied security to the shape of the schema and every query the app runs. If you grant only `EXECUTE` on curated procedures, you create controlled entry points.

The principle is: the role can perform *approved operations*, not arbitrary table writes. This reduces blast radius and makes audits more meaningful. It also makes it easier to review changes: security is defined in fewer places.

In real deployments, you’d define a role per application (or per capability), grant execute on a handful of procedures, and deny direct table access. You then test from a non-admin login to ensure the boundaries are real.
Grant only execute, not table access:
```sql
-- Example only; requires a user/principal.
-- GRANT EXECUTE ON dbo.usp_UpdatePrice TO SomeRole;
-- DENY SELECT, UPDATE ON dbo.Products TO SomeRole;
```

## Common mistakes
Most “stored procedure problems” aren’t about syntax. They’re about contracts: what does the procedure guarantee on success, and what does it guarantee on failure? The mistakes below are all ways to violate that contract.

`SET NOCOUNT ON` looks cosmetic, but it affects how some drivers interpret results. Swallowing errors makes debugging and correctness impossible. And logging too early creates a narrative that doesn’t match reality.

When you standardize procedure templates in a team, you are really standardizing behavior under stress. That is why these details matter.
- Forgetting `SET NOCOUNT ON` (breaks some app drivers that expect a single result set).
- Swallowing errors in CATCH without rethrowing.
- Logging before the change is guaranteed to commit.

## Summary
- Wrap multi-step work in a transaction.
- Use `TRY...CATCH` + `THROW`.
- Make procedure behavior predictable and auditable.

- Microsoft Docs: [CREATE PROCEDURE (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/create-procedure-transact-sql), [TRY...CATCH (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/language-elements/try-catch-transact-sql), [THROW (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/language-elements/throw-transact-sql), [XACT_STATE (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/functions/xact-state-transact-sql)

*Conclusion:* Standardize the template, then reuse it everywhere. When errors are rethrown and transactions are managed consistently, procedures become a reliable database API instead of a source of hidden states.
