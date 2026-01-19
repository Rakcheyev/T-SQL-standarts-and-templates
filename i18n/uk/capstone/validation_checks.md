# Перевірки валідації (capstone)

Ці перевірки мають бути зручними для copy-paste і безпечними для повторного запуску.

У capstone SQL-скриптах уже є спеціальні блоки **Validation** / **Sanity checks**.
Цей документ — швидкий “індекс”: де їх знайти і що саме вони доводять.

## Де саме знаходяться перевірки

1. Перевірки схеми: `capstone/sql/01_schema.sql`
   - Перевіряє наявність схем (`etl`, `stg`, `dw`).
   - Перевіряє наявність потрібних об’єктів (таблиць у кожному шарі).

2. Перевірки seed даних: `capstone/sql/02_seed_data.sql`
   - Row counts для OLTP таблиць.
   - Orphan checks (цілісність зв’язків).

3. Перевірки pipeline load: `capstone/sql/03_pipeline_load.sql`
   - Статус batch для поточного `@BatchId`.
   - Row counts у staging для batch.
   - Row counts у DW (dims/fact).
   - Expected vs actual fact rows для batch.
   - Перевірка на дублікати у fact та перевірка “orphan” посилань на виміри.

4. Перевірки перед репортами: `capstone/sql/04_reporting_queries.sql`
   - Швидкі row counts у DW.
   - Остання історія batch.
   - Orphan facts check.

## Мінімальне “визначення коректності”

Після запуску пайплайна:
- `etl.LoadBatch` показує ваш batch як `Succeeded`.
- Orphan-перевірки повертають `0`.
- Повторний запуск `capstone/sql/03_pipeline_load.sql` з тим самим `@BatchId` не змінює:
  - row counts у staging для цього `@BatchId`
  - row counts у DW
  - expected vs actual fact rows

## Поради

- Сприймайте кожну data-quality перевірку як unit test для логіки пайплайна.
- Якщо перевірка “падає”, зафіксуйте:
  - що саме змінилося (дані, код, індекси, статистики)
  - як ви відтворили проблему
  - як ви верифікували фікс
