**Language:** English | [Українська](i18n/uk/BEN_GAN_CANON.md)

# Ben-Gan “canon” (inspiration only) — how to use it safely

This page is a **reference list + study guide** for learners who want to go deeper into the “classic” T‑SQL pattern style associated with Itzik Ben‑Gan and related Microsoft SQL Server materials.

**Important rule:** use these sources as *inspiration only*. Do not copy text into this repo. Instead, extract **patterns**, then write your own explanations and build your own labs.

## What to use this for

High ROI areas where “classic” materials tend to be strongest:

- **Set-based thinking:** replace loops and per-row logic with set operations.
- **Correctness edge cases:** NULL semantics, duplicates, ties, deterministic ordering.
- **Window-function patterns:** dedupe, sequencing, running totals, gaps-and-islands.
- **Table expressions:** derived tables vs CTEs vs APPLY, and when each helps.

## How to use external sources ethically (and effectively)

A simple workflow that keeps you safe and productive:

1. Read a pattern description in a source.
2. Close the source.
3. Write the idea in **your own words** from memory (no paraphrase-by-rewrite).
4. Build a **fresh dataset** (your own table names + values).
5. Create:
   - a clear problem statement,
   - a “first attempt” query (often wrong),
   - a corrected query,
   - an explanation of *why* it’s correct,
   - an exercise that forces tie/NULL/duplicate edge cases.

If you can’t explain the pattern without looking, you haven’t learned it yet.

## Trustworthy starting points

- Microsoft Press Store (search results / books list):
  - https://www.microsoftpressstore.com/search/index.aspx?query=Ben-Gan
- T‑SQL Fundamentals (4th Edition):
  - https://www.microsoftpressstore.com/store/t-sql-fundamentals-9780138102104
- T‑SQL Window Functions (2nd Edition):
  - https://www.microsoftpressstore.com/store/t-sql-window-functions-for-data-analysis-and-beyond-9780135861448
- T‑SQL Querying:
  - https://www.microsoftpressstore.com/store/t-sql-querying-9780735685048

Historical (still useful concepts / mental models):

- MSDN Magazine archive (APPLY / CTE / PIVOT/UNPIVOT / TRY/CATCH / SNAPSHOT):
  - https://learn.microsoft.com/en-us/archive/msdn-magazine/2004/february/powerful-t-sql-syntax-gives-sql-server-a-programmability-boost

## Suggested study path inside this repo

- Window functions:
  - Lesson 6 (intro): `course/lessons/06_data_chas_vikonni_funkcii.md`
  - Lesson 7B (deep dive): `course/lessons/07b_window_functions_deep_dive.md`
- Table expressions + APPLY:
  - Lesson 7 (APPLY section): `course/lessons/07_advanced_query_patterns.md`
  - Elective lab pack: `course/lessons/17_table_expressions_lab_pack.md`

## What “good output” looks like

When you add a new lab/pattern to this repo, aim for:

- a crisp statement of **row-grain** (what one row represents)
- at least one **counterexample dataset** (ties, NULLs, duplicates)
- deterministic ordering where relevant (stable tie-breakers)
- a small, verifiable expected output (so the lab can be checked)
- a short note: correctness vs performance vs maintainability tradeoffs
