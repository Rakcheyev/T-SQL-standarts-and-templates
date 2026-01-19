**Мова:** [English](../../TODO.md) | Українська

# TODO / Дорожня карта курсу (після уроків 7–14)

Цей файл — беклог і дорожня карта подальшого розвитку курсу.

Поточний стан (вже зроблено):
- Уроки 7–14 та бонусний Урок X є в обох локалях.
- Навігація стабільна: короткий `navigation.md` на локаль + згенерований `navigation_detailed.md`.
- Є перевірка цілісності: `scripts/verify_repo.ps1` (перегенерація індексів + sanity checks) + VS Code task.

Позначки “сфера DBMS”, які використовуємо в цьому файлі:
- `[CORE]` переносимий SQL (працює на більшості DBMS)
- `[CROSS]` концепт крос-DB, але синтаксис/поведінка відрізняється (описувати по DB)
- `[T-SQL]` специфічно для SQL Server / Azure SQL (T-SQL або особливості рушія)
- `[PG]` специфічно для PostgreSQL

---

## 0) Мета / стандарти

- [ ] (Опційно) Нотатки по PostgreSQL там, де доречно
  - [ ] [T-SQL] `CROSS APPLY` / `OUTER APPLY` ↔ [PG] `LATERAL` join-и
  - [ ] [T-SQL] `PIVOT` / `UNPIVOT` ↔ [PG] умовна агрегація / `crosstab` (extension)
  - [ ] [T-SQL] filtered indexes ↔ [PG] partial indexes
  - [ ] [T-SQL] computed columns + indexing ↔ [PG] generated columns + indexes
  - [ ] [T-SQL] Query Store (опційно) ↔ [PG] `pg_stat_statements` + `auto_explain` (опційно)
  - [ ] [CROSS] identity / sequences: [T-SQL] `IDENTITY` ↔ [PG] `GENERATED AS IDENTITY`

- [x] Додати українські версії planning-доків
  - [x] Створити цей файл: `i18n/uk/TODO.md`

- [x] (Опційно) Додати “канон” як натхнення (Itzik Ben-Gan тощо)
  - Правило: не копіювати текст, а писати оригінальні пояснення та labs.
  - Додано: `i18n/uk/BEN_GAN_CANON.md` + Урок 17 (lab pack): `i18n/uk/course/lessons/17_table_expressions_lab_pack.md`.

---

## 1) Наступні великі блоки (елективи)

### Pro DA (Data Analyst) — поглиблена аналітика
- [x] Додати DA-only урок: Advanced analytics SQL
  - [CORE] `GROUPING SETS` / `ROLLUP` / `CUBE`
  - [T-SQL] `PIVOT` / `UNPIVOT`
  - [CORE] cohort/retention патерни

### Pro DBA — моніторинг і troubleshooting
- [x] Додати DBA-only урок: monitoring & troubleshooting
  - waits/IO/tempdb
  - baselines
  - incident workflow

### Pro Engineer — capstone
- [x] Capstone: end-to-end проєкт (OLTP schema + pipeline + reporting + ops runbook)

---

## 2) Repo integration checklist (для кожного нового уроку)

- [x] Переконатися, що всі зображення (якщо є) в `assets/images/` і шляхи працюють в обох локалях
  - [x] Автоматична перевірка: `scripts/check_markdown_links.ps1` (запускається в `scripts/verify_repo.ps1`)
- [x] Не тримати вручну anchors у навігації (покладатися на генерацію)
  - [x] Автоматичне попередження: anchored-links у `navigation.md` та `i18n/uk/navigation.md`

---

## 3) Quality bar (вимоги до кожного уроку)

Для кожного уроку:
- [ ] “Чому це важливо у проді” (1–2 абзаци)
- [ ] Мінімум 5 практичних lab-ів з очікуваними результатами
- [ ] Короткий чеклист: типові помилки + як дебажити
- [ ] Де доречно — SARGability і вплив на індекси
- [ ] Якщо заявляємо performance — міряємо IO/time і пояснюємо план
- [ ] Міні-оцінювання (5–10 питань)
- [ ] Домашнє з tradeoffs (коректність vs продуктивність vs підтримуваність)
