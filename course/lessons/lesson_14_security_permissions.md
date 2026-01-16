**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_14_security_permissions.md)

<h2 align="center">Lesson 14 — Security basics: principals, roles, permissions</h2>

*Intro:* Security is easiest when it’s designed, not patched. You’ll learn SQL Server principals (login vs user), schemas, roles, and the GRANT/DENY model, then practice least-privilege patterns like EXECUTE-only access. The goal is to make the secure path the easy path.

The mindset shift is to treat permissions like code: explicit, reviewable, and testable. When access is granted ad hoc (“just make it work”), the system becomes fragile—small changes accidentally widen privilege, and the blast radius of a leaked credential grows.

We’ll build a clean model from the ground up: who is the principal, what is the boundary (schema), and what is the role allowed to do? Then we’ll turn that model into a practical pattern: the application executes approved modules, while base tables remain protected.

By the end, you should be comfortable diagnosing “why can’t this user do X?” and, more importantly, comfortable designing access so that the default path is safe.

## Goal
Know how SQL Server security is structured and apply least privilege.

## Who this lesson is for
- Developers: to avoid over-privileging “just to make it work”.
- Analysts: to understand why you might not have direct table access.
- DBAs: as a quick, teachable checklist for least-privilege setups.

## How to use this lesson
1. Run it only in a sandbox.
2. Create principals, then test access boundaries.
3. Prefer role-based grants.

## Key concepts
- **Login** (server-level principal) vs **User** (database-level principal)
- **Schema**: container/namespace; also a security boundary
- **Role**: group of permissions
- Prefer granting permissions to roles, not individual users

## What SQL Server permissions are (beginner-friendly)
**What it is:** a system that answers “who can do what to which object?”.

**Why it’s used:** to enforce least privilege and reduce blast radius when credentials leak.

**Benefits:**
- safer systems (users only have what they need)
- easier audits and offboarding

**Pitfalls:**
- granting broad roles (`db_owner`) makes troubleshooting easy but security weak
- mixing everything in `dbo` can make separation harder

## Labs (templates)
These require appropriate permissions (typically sysadmin in a sandbox).

### Lab 1 — Create login and user
This lab demonstrates the most important split in SQL Server security: a **login** exists at the server level, while a **user** exists inside a database. Newcomers often expect “a user is a user”, but in SQL Server those are two separate identities linked together.

Think of it like this: the login answers “can you connect to the server?”, and the user answers “once connected, what can you do inside this database?”. This distinction is what allows a single login to map to different users across databases (or to have access to some databases and not others).

In real environments, you usually do not create SQL logins for applications and people unless you have a specific reason; many organizations use Windows/Entra identities. But the model of server principal → database principal remains the same.
```sql
-- Server level
CREATE LOGIN DemoLogin WITH PASSWORD = 'ChangeMe_StrongPassword!';
GO

-- Database level
USE YourDb;
GO
CREATE USER DemoUser FOR LOGIN DemoLogin;
GO
```

### Lab 2 — Create a role and grant permissions
Roles are the unit of management. If you grant permissions directly to users, you’ll eventually create an unreviewable maze. If you grant permissions to roles and then add users to roles, you create something you can reason about and audit.

This lab uses `GRANT SELECT ON SCHEMA::dbo` to illustrate a practical pattern: grant by schema instead of granting per-table, so the permission boundary matches how you organize objects. It’s not always appropriate, but it’s a clean starting point for many applications.

After you run the script, don’t stop at “it executed”. Test it: connect as the demo user (or use `EXECUTE AS USER = 'DemoUser'`) and verify what can and cannot be read. Security is only real when you validate it from a non-admin context.
```sql
USE YourDb;
GO
CREATE ROLE AppReader;
GO
GRANT SELECT ON SCHEMA::dbo TO AppReader;
GO
ALTER ROLE AppReader ADD MEMBER DemoUser;
GO
```

### Lab 3 — Deny overrides grant (demonstration)
This is a small but critical rule: `DENY` is stronger than `GRANT`. It is designed as a safety override, but it can also produce confusing outcomes if you forget it exists.

The practical lesson is not “use DENY everywhere”. The practical lesson is: if something doesn’t work, check for an unexpected `DENY` (directly on the user, on a role, or inherited through membership).

In mature environments, teams often prefer “positive permissions” (grant the minimum needed) and use `DENY` sparingly, because `DENY` tends to make long-term maintenance harder.
```sql
DENY SELECT ON dbo.SensitiveTable TO AppReader;
```

### Lab 4 — Execute permissions on procedures
Granting `EXECUTE` on procedures is one of the most powerful least-privilege patterns in SQL Server. Instead of giving an application role the ability to modify tables directly, you give it the ability to call approved operations.

This aligns security with business intent: “the app can update a price *via this procedure*”, not “the app can update any row in the table using any statement.” That difference matters when credentials leak or when bugs happen.

The flip side is that your procedures become part of the security boundary. They must validate inputs, avoid unsafe dynamic SQL, and be tested with realistic permission sets.
```sql
GRANT EXECUTE ON dbo.usp_UpdatePrice TO AppReader;
```

### Lab 5 — Ownership chaining (concept)
Ownership chaining is a subtle mechanism that can be helpful or dangerous depending on how you use it. The simplified idea is: if the caller has permission to execute a module (procedure, function, view), SQL Server may allow that module to access underlying objects without requiring the caller to have direct permissions on those objects.

This is one reason the “execute-only” pattern works so well: the procedure becomes the controlled entry point, and the caller doesn’t need table permissions. But it also means your module design and object ownership matter a lot.

Treat this lab as a prompt to test boundaries: create a minimal role, grant execute on a procedure, deny table access, and verify the behavior. Never assume security properties—prove them in a sandbox.
If a user can execute a procedure, the procedure can access tables it owns (under certain conditions).
Design procedures carefully and test permission boundaries.

## Common mistakes
Security mistakes tend to look like productivity wins at first. Giving `db_owner` makes things “just work” and removes friction. But it also removes safety boundaries and turns every bug into a potential incident.

The second mistake is treating schema design as purely organizational. In SQL Server, schemas are also permission boundaries. If everything lives in `dbo`, you make it harder to grant “this team can read reporting objects but not operational tables” in a clean way.

The guiding principle is: make the secure path the easy path. Define roles, grant minimum permissions, and provide procedures/views as the intended interface.
- Granting `db_owner` or `sysadmin` “to make it work”.
- Mixing objects in `dbo` without schema separation.

## Summary
SQL Server security becomes manageable when you treat it as a design problem, not an emergency fix. Logins and users define identity, schemas define boundaries, and roles define capabilities.

From there, least privilege is a habit: grant only what is needed, validate from non-admin contexts, and prefer role-based permissions over one-off user grants.

If you want one actionable next step: create an application role in a sandbox, deny direct table access, grant execute on a small set of procedures, and test that your app can do its job and nothing more.

- Microsoft Docs: [CREATE USER (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/create-user-transact-sql), [GRANT (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/grant-transact-sql), [DENY (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/deny-transact-sql)

*Conclusion:* Treat permissions like code: explicit, reviewable, testable. Use roles, separate schemas, avoid broad grants, and validate from non-admin contexts—then “works” never means “over-privileged”.
