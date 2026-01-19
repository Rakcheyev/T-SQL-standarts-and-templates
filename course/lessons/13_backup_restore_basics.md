**Language:** English | [Українська](../../i18n/uk/course/lessons/13_backup_restore_basics.md)

<h2 align="center">Lesson 13 — Backup/restore basics (SQL Server)</h2>

*Intro:* “We have backups” only matters if you can restore under time pressure. This lesson builds the restore-chain mental model (full, diff, log), connects it to RPO/RTO, and gives safe script templates for backup and restore-to-new-name practice—the habit that turns files into recovery.

**DBMS scope:** [T-SQL] SQL Server backup/restore chain and scripts.

Backups are not a checkbox—they’re a capability. The only proof that you have that capability is a routine restore rehearsal that works with real paths, real permissions, and real timing constraints.

You’ll learn how the chain behaves, what breaks it, and how to think in terms of outcomes: how much data can we lose (RPO) and how long can we be down (RTO)? Then you’ll practice scripts that restore into a separate database name so you can validate safely without risking production.

The goal is to walk away with muscle memory: when something goes wrong, you don’t start Googling—you run a known, repeatable restore sequence.

## Goal
Understand what backups are (and aren’t), and be able to write correct backup/restore scripts.

## Who this lesson is for
- Developers: to understand what your DBA/SRE team needs from you (and what “we have backups” actually means).
- Junior DBAs/SREs: to learn the backup chain and practice safe restore scripts.

## Safety rules (please treat as non-negotiable)
- [CORE] Do **not** test restore scripts on production.
- [CORE] Always restore to a **separate** database name first.
- [CORE] A backup you never restored is just a file.

## Prerequisites
- Basic admin access to a SQL Server instance (for hands-on)

## Key concepts
- [T-SQL] **Full backup**: base of a restore chain.
- [T-SQL] **Differential backup**: changes since last full backup.
- [T-SQL] **Log backup**: transaction log records since last log backup (requires FULL/BULK_LOGGED recovery).
- [CORE] **RPO**: how much data loss is acceptable.
- [CORE] **RTO**: how long restore can take.

## What backups are (and what they are not)
**A backup is not high availability.** It won’t keep your database online during an outage.

**A backup is recovery.** It’s how you rebuild the database state after:
- [CORE] accidental deletes/updates
- [CORE] disk/VM loss
- [CORE] corruption or ransomware

Beginner mental model:
- [T-SQL] Full backup starts the chain.
- [T-SQL] Differential is “since last full”.
- [T-SQL] Log backups let you restore close to a point in time (if your recovery model supports it).

## Safety
- [CORE] Always test restores.
- [CORE] Backups must be stored off the server to protect from disk loss.

## Labs (script templates)
These scripts require a writable backup path and permissions.

### Lab 1 — Full backup
The full backup is the foundation of everything that follows. When someone says “we can restore the database”, what they often mean is “we can restore a full backup, and then optionally apply other backups on top of it.” Without a recent full backup, your restore options narrow quickly.

The `WITH INIT` option overwrites the target backup file. That can be convenient in a lab, but it is dangerous in a real backup strategy if you reuse file names accidentally. In production you typically use unique file names and retention policies so you never overwrite the only good copy.

`COMPRESSION` and `CHECKSUM` are not “luxury flags”. Compression reduces storage and often speeds up backups by moving less data. Checksums help detect corruption during backup/restore—an essential part of trusting your chain.
```sql
BACKUP DATABASE YourDb
TO DISK = 'C:\Backups\YourDb_full.bak'
WITH INIT, COMPRESSION, CHECKSUM;
```

### Lab 2 — Differential backup
Differential backups exist to save time. Instead of restoring a week-old full backup and then replaying a mountain of log backups, you restore a more recent “since last full” snapshot and then apply fewer logs. This can dramatically improve your RTO.

The critical detail is in the definition: differential is “since the last full backup”, not “since the last differential”. That means differentials grow over time until the next full backup resets the base.

In practice, teams schedule full backups on a cadence (daily/weekly) and differentials in between, guided by RPO/RTO goals and storage constraints.
```sql
BACKUP DATABASE YourDb
TO DISK = 'C:\Backups\YourDb_diff.bak'
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM;
```

### Lab 3 — Log backup
Transaction log backups are what make point-in-time recovery possible. They capture the sequence of changes, allowing you to restore not just “a backup”, but the database state up to a chosen moment.

Log backups only work as expected in FULL (or BULK_LOGGED) recovery model. In SIMPLE recovery, the log is truncated automatically, which limits your ability to restore to a specific point in time.

Operationally, log backups are also about limiting loss. If you back up logs every 5 minutes, your RPO in the best case is around 5 minutes (plus whatever your restore process requires).
```sql
BACKUP LOG YourDb
TO DISK = 'C:\Backups\YourDb_log.trn'
WITH COMPRESSION, CHECKSUM;
```

### Lab 4 — Verify backup
Verification is the difference between “we have backup files” and “we have recoverability”. `RESTORE VERIFYONLY` checks that SQL Server can read the backup and that checksums (if present) validate. This is necessary, but not sufficient.

The important caveat is that `VERIFYONLY` does not prove that you can restore the database into a working state. It can’t validate the entire operational procedure: file locations, permissions, naming, application connectivity, and the full chain.

Treat verification as a quick health check you run frequently. Treat restore testing as the real proof.
```sql
RESTORE VERIFYONLY
FROM DISK = 'C:\Backups\YourDb_full.bak'
WITH CHECKSUM;
```

### Lab 5 — Restore to a new database name
This is the lab that turns theory into an operational capability. Restoring to a new database name is the safest way to practice: you do not overwrite production, and you can validate the result without pressure.

`RESTORE FILELISTONLY` is essential because backups store **logical file names**, not just physical paths. On restore, SQL Server needs to map those logical names to new physical file locations. If you guess them, you will eventually guess wrong.

The `MOVE` clauses are where most restore scripts fail in practice: the target folder might not exist, the service account might not have permissions, or the file names might collide. Getting this right (and automating it) is what makes restores predictable during incidents.
```sql
-- Inspect logical file names first
RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\YourDb_full.bak';

-- Then restore with MOVE
RESTORE DATABASE YourDb_RestoreTest
FROM DISK = 'C:\Backups\YourDb_full.bak'
WITH MOVE 'YourDb'     TO 'C:\SqlData\YourDb_RestoreTest.mdf',
     MOVE 'YourDb_log' TO 'C:\SqlData\YourDb_RestoreTest_log.ldf',
     REPLACE, RECOVERY;
```

## Common mistakes
Most backup failures are discovered during the worst possible moment: a real incident. The purpose of this section is to help you move those failures into routine practice instead.

The most dangerous belief is “the job succeeded, so we’re safe.” Backup jobs can succeed while producing unusable backups (wrong retention, overwritten files, inaccessible paths, missing logs). The only proof is a restore rehearsal.

The second common failure is misaligned expectations: teams choose recovery model and schedules without connecting them to RPO/RTO. If you want point-in-time recovery, you must plan log backups and retention accordingly.
- Thinking “backup succeeded” implies “restore will work”.
- Not backing up logs (in FULL recovery) and losing point-in-time restore.

## Summary
Backups are not about files; they are about a repeatable restoration process. Your real asset is the ability to rebuild the database reliably under time pressure.

The key mental model is the chain: full establishes the base, differential reduces restore time, and log backups provide continuity and point-in-time recovery. If any link is missing, your options shrink.

If you take one action after this lesson, make it a scheduled restore test to a separate database name. That single habit turns backups from hope into capability.

- Microsoft Docs: [BACKUP (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/backup-transact-sql), [RESTORE statements (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/restore-statements-transact-sql)

*Conclusion:* Backups are a process, not a file. Schedule restore rehearsals to a separate database name, verify checksums, and keep the chain intact—then incidents become execution, not panic.

