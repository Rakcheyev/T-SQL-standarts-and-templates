**Мова:** [English](../../PRO_DE_TRACK_GUIDE.md) | Українська

# Pro DE (Data Engineer) — гайд треку

Цей документ перетворює Pro DE TODO (“наголос: транзакції/ідемпотентність, патерни завантаження, продуктивність для пайплайнів”) на конкретні цілі й чеклисти.

## Рекомендовані передумови
- Пройти основний порядок у [LEARNING_PATH.md](../../LEARNING_PATH.md) принаймні до Уроку 6.

## Основні уроки для Pro DE
Рекомендована послідовність (і навіщо):
1. Урок 7 — безпечні патерни запитів (коректність важливіша за швидкість)
2. Урок 7B — віконні функції (de-dupe, sequencing, top-N per group)
3. Урок 8 — транзакції та конкурентність (надійність під навантаженням)
4. Урок 9 — процедури + обробка помилок (продакшн DML)
5. Урок 11 — індекси та SARGability (повторюваний тюнінг)
6. Урок 12 — ETL патерни (staging → upsert → batching)

## На чому робити наголос (Pro DE фокус)

### 1) Транзакції та надійність
Чеклист:
- Використовуйте явні транзакції, коли одиниця роботи має бути атомарною.
- Тримайте транзакції короткими (не робіть інтерактивних дій усередині транзакції).
- Розумійте компроміси рівнів ізоляції (blocking vs consistency).
- Робіть ретраї безпечно (тільки якщо операція ідемпотентна або є захист).

Практичні патерни:
- Аудитні записи + статуси (Pending → Applied → Failed).
- “Exactly-once effect” через constraints + `NOT EXISTS` guards.

### 2) Ідемпотентність (головний skill для ETL)
Чеклист:
- Кожне завантаження має бути безпечним для повторного запуску.
- Розділяйте час *extract* і час *effective*.
- Використовуйте стабільні натуральні ключі або детерміноване зіставлення surrogate.
- Підкріплюйте унікальність constraints (не покладайтеся лише на логіку).

Типові підходи:
- Stage “raw” → upsert у curated.
- Зберігайте watermark + batch id; фіксуйте результат виконання.

### 3) Патерни завантаження (staging → transform → publish)
Чеклист:
- Перевіряйте schema drift і nullability у staging.
- Додавайте audit-колонки (`load_batch_id`, `loaded_at`, `source_file`, тощо).
- Віддавайте перевагу set-based upsert; batch-іть великі модифікації.

### 4) Продуктивність пайплайнів
Чеклист:
- Пишіть SARGable watermark-предикати (range по “сирому” datetime/date).
- Уникайте implicit conversions між staging і target.
- Слідкуйте за tempdb при hash joins/sorts/spills.
- Якщо заявляємо performance — міряємо `SET STATISTICS IO, TIME ON`.

Операційні поради:
- Якщо обсяги ростуть, спочатку зазвичай допомагають правильні індекси на staging/target (business keys + watermark).
- Зменшуйте “ширину рядка” якнайраніше (вибирайте тільки потрібні колонки).

## Міні-оцінювання (10 питань)
1. Що означає “ідемпотентна операція”?
2. Чому довгі транзакції збільшують ризик blocking?
3. Коли `MERGE` ризикований і які є безпечніші альтернативи?
4. Чим відрізняється “rows processed” від “rows returned”?
5. Чому `CONVERT(date, EventTime)` часто робить предикат не-SARGable?
6. Що таке watermark і які типові failure modes?
7. Чому hash join і sort часто тиснуть на tempdb?
8. Що таке “exactly-once effect” у пайплайні?
9. Які дані треба зберігати для безпечних ретраїв?
10. Які докази збирати до/після performance-зміни?

## Пропозиція напрямку capstone (DE-варіант)
Для портфоліо Pro DE можна зробити:
- staging-таблицю
- curated dimension + fact
- інкрементальне завантаження з watermark
- upsert-стратегію + batching
- маленький ops runbook (як безпечно перезапускати, що моніторити)

## Посилання
- https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql
- https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-and-tune-for-performance

