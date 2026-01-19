**Мова:** [English](../../CAPSTONE_PROJECT.md) | Українська

# Capstone — end-to-end data product (OLTP → pipeline → reporting → ops)

Це capstone-проєкт “як у проді” для портфоліо, який комбінує теми з Pro треків.

Результати (deliverables) у цьому репозиторії:
- скрипти OLTP схеми + seed data
- staging + інкрементальні load-скрипти (ідемпотентні)
- 10–15 ключових reporting-запитів
- нотатки з performance тюнінгу (IO/time + plan evidence)
- ops runbook (як запускати, безпечно перезапускати та моніторити)

Папка проєкту: [capstone/](../../capstone/)

## Сценарій
Є невеликий онлайн-магазин. Замовлення надходять постійно. Ваше завдання:
1) змоделювати OLTP дані (customers, products, orders)
2) побудувати повторюваний пайплайн у curated таблиці
3) підготувати звітні запити (денна виручка, retention, топ-продукти)
4) описати операції (перезапуски, помилки, моніторинг)

## Критерії готовності (definition of done)
- Усі скрипти виконуються з “чистої” бази.
- Пайплайн ідемпотентний: повторний запуск батчу не створює дублі.
- Reporting-запити повертають стабільні коректні результати.
- Є мінімум 3 performance поліпшення з доказами (IO/time + план).

## Як почати
1. Схема: [capstone/sql/01_schema.sql](../../capstone/sql/01_schema.sql)
2. Дані: [capstone/sql/02_seed_data.sql](../../capstone/sql/02_seed_data.sql)
3. Load batch: [capstone/sql/03_pipeline_load.sql](../../capstone/sql/03_pipeline_load.sql)
4. Reports: [capstone/sql/04_reporting_queries.sql](../../capstone/sql/04_reporting_queries.sql)
5. Ops: [capstone/ops_runbook.md](../../capstone/ops_runbook.md)

