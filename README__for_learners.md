**Language:** English | [Українська](i18n/uk/README__for_learners.md)

# README (for learners)

## Who this repo is for

This repository is a good fit if you:

- are learning SQL from scratch or refreshing fundamentals;
- want structured lessons in Markdown;
- need short explanations and query examples by topic.

Lessons are in [course/lessons/](course/lessons/).

## How to learn SQL with this repo

- Start with [LEARNING_PATH.md](LEARNING_PATH.md) and follow the recommended order.
- Open each lesson in an editor (e.g., VS Code) and go top-to-bottom.
- After each SQL example, try running it in your DBMS (and adapt if needed).
- For quick lookups by topic/heading, use [navigation.md](navigation.md).
- For quick lookups by topic/heading, use [navigation.md](navigation.md) (or the detailed index [navigation_detailed.md](navigation_detailed.md)).

## DBMS scope tags (what the labels mean)

Some lessons include a **DBMS scope** line near the top and/or inline tags inside bullet lists.
These tags tell you whether a concept is portable SQL or specific to one database.

- `[CORE]` — portable SQL ideas/patterns that translate well across DBMS (syntax may differ slightly).
- `[CROSS]` — concept exists in multiple DBMS, but behavior/syntax/performance details differ; read the notes and adapt.
- `[T-SQL]` — SQL Server / Azure SQL specific (Transact-SQL features, tooling, or behavior).
- `[PG]` — PostgreSQL specific.

Tip: if you’re learning on SQL Server, focus on `[CORE]`, `[CROSS]`, and `[T-SQL]`. If you’re on PostgreSQL, focus on `[CORE]`, `[CROSS]`, and `[PG]`.

## What’s inside

- Lessons: [course/lessons/](course/lessons/)
- Lesson images: [assets/images/](assets/images/)
- Helper scripts for Markdown processing: [scripts/](scripts/)

## Pro tracks

- Pro DE (Data Engineer): [PRO_DE_TRACK_GUIDE.md](PRO_DE_TRACK_GUIDE.md)

## References (optional)

- Ben-Gan canon (inspiration only): [BEN_GAN_CANON.md](BEN_GAN_CANON.md)

## Capstone project

- End-to-end project spec: [CAPSTONE_PROJECT.md](CAPSTONE_PROJECT.md)
