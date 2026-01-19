**Мова:** [English](../../../../course/lessons/15_advanced_analytics_sql.md) | Українська

<h2 align="center">Урок 15 — Advanced analytics SQL (GROUPING SETS, PIVOT, cohorts)</h2>

*Вступ:* Коли ви вже вмієте JOIN-и, агрегації та window functions, наступний рівень — якісна аналітика: підсумки на кількох рівнях, крос-таблиці, cohort/retention-запити. Цей урок дає практичні патерни, які щодня використовують аналітики, але які часто “вчать на болі”.

**Сфера DBMS:** [CORE] концепти групування + [CROSS] концепти pivot/unpivot; приклади — [T-SQL] (SQL Server).

## Мета
Навчитися патернам для:
- кількох рівнів агрегації в одному запиті (`GROUPING SETS`, `ROLLUP`, `CUBE`)
- крос-таблиць (`PIVOT`, `UNPIVOT`)
- cohort/retention-запитів (місяць першої покупки → активність по зміщенню місяців)

## Передумови
- Уроки 6–7 (віконні функції та безпечні патерни запитів)

## Ключові терміни
- **Проміжний підсумок / загальний підсумок:** додаткові рядки агрегації поверх “базового” групування.
- **Grouping set:** один конкретний рівень групування в `GROUPING SETS`.
- **Крос-таблиця (pivot):** перетворення рядків на колонки для звітів.
- **Cohort:** група сутностей з однаковою стартовою подією (signup / перша покупка).

## Типові помилки
- Плутати рядки `ROLLUP` з реальними даними (завжди маркуйте subtotal-рядки).
- Використовувати `PIVOT`, коли простіша і переносиміша умовна агрегація.
- Рахувати “retention” без чіткого визначення cohort-івента та гранулярності часу.

## Labs

### Lab setup (спільний датасет)
Датасет маленький і детермінований.

```sql
DROP TABLE IF EXISTS dbo.Sales;
GO

CREATE TABLE dbo.Sales
(
    SaleId     int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerId int               NOT NULL,
    SaleDate   date              NOT NULL,
    Amount     decimal(12,2)     NOT NULL,
    Channel    varchar(10)       NOT NULL
);
GO

INSERT INTO dbo.Sales (CustomerId, SaleDate, Amount, Channel)
VALUES
-- Customer 1: перша покупка в січні, потім лютий і березень
(1, '2025-01-10', 120.00, 'web'),
(1, '2025-02-02',  80.00, 'web'),
(1, '2025-03-15',  60.00, 'store'),

-- Customer 2: перша покупка в січні, потім ще раз у січні
(2, '2025-01-05',  50.00, 'store'),
(2, '2025-01-20',  30.00, 'web'),

-- Customer 3: перша покупка в лютому, потім березень
(3, '2025-02-11', 200.00, 'web'),
(3, '2025-03-01',  40.00, 'web'),

-- Customer 4: перша покупка тільки в березні
(4, '2025-03-22',  70.00, 'store');
GO
```

### Lab 1 — `GROUPING SETS` для агрегації на кількох рівнях
Задача: показати виручку по (Month, Channel), плюс підсумок по місяцю, плюс загальний підсумок.

```sql
SELECT
    DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
    Channel,
    SUM(Amount) AS Revenue,
    GROUPING(DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)) AS IsMonthTotal,
    GROUPING(Channel) AS IsChannelTotal
FROM dbo.Sales
GROUP BY GROUPING SETS
(
    (DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1), Channel),
    (DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)),
    ()
)
ORDER BY
    SalesMonth,
    Channel;
```

Очікувана логіка:
- деталізація: `IsMonthTotal = 0` і `IsChannelTotal = 0`
- підсумок по місяцю: `IsChannelTotal = 1`
- загальний підсумок: `IsMonthTotal = 1` і `IsChannelTotal = 1`

### Lab 2 — `ROLLUP` + маркування subtotal-рядків

```sql
WITH Base AS
(
    SELECT
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
        Channel,
        Amount
    FROM dbo.Sales
)
SELECT
    SalesMonth,
    CASE
        WHEN GROUPING(Channel) = 1 AND GROUPING(SalesMonth) = 0 THEN '(підсумок місяця)'
        WHEN GROUPING(Channel) = 1 AND GROUPING(SalesMonth) = 1 THEN '(загальний підсумок)'
        ELSE Channel
    END AS ChannelLabel,
    SUM(Amount) AS Revenue
FROM Base
GROUP BY ROLLUP (SalesMonth, Channel)
ORDER BY SalesMonth, ChannelLabel;
```

### Lab 3 — Умовна агрегація як переносима альтернатива `PIVOT`
Задача: крос-таблиця виручки по місяцю з колонками `web_revenue` та `store_revenue`.

```sql
SELECT
    DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
    SUM(CASE WHEN Channel = 'web'   THEN Amount ELSE 0 END) AS web_revenue,
    SUM(CASE WHEN Channel = 'store' THEN Amount ELSE 0 END) AS store_revenue,
    SUM(Amount) AS total_revenue
FROM dbo.Sales
GROUP BY DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)
ORDER BY SalesMonth;
```

Очікуваний результат:
- 2025-01-01: web=30, store=170, total=200
- 2025-02-01: web=280, store=0, total=280
- 2025-03-01: web=40, store=130, total=170

### Lab 4 — `PIVOT` для фіксованого набору колонок

```sql
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS SalesMonth,
        Channel,
        Amount
    FROM dbo.Sales
)
SELECT
    SalesMonth,
    ISNULL([web], 0) AS web_revenue,
    ISNULL([store], 0) AS store_revenue
FROM Monthly
PIVOT
(
    SUM(Amount) FOR Channel IN ([web], [store])
) p
ORDER BY SalesMonth;
```

### Lab 5 — Cohorts: місяць першої покупки → активність по зміщенню місяців
Визначення:
- cohort month = місяць першої покупки клієнта
- retention month = місяць покупки
- month_offset = різниця місяців між cohort month і retention month

```sql
WITH Purchases AS
(
    SELECT
        CustomerId,
        DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1) AS PurchaseMonth
    FROM dbo.Sales
    GROUP BY CustomerId, DATEFROMPARTS(YEAR(SaleDate), MONTH(SaleDate), 1)
),
Cohorts AS
(
    SELECT
        CustomerId,
        MIN(PurchaseMonth) AS CohortMonth
    FROM Purchases
    GROUP BY CustomerId
),
Activity AS
(
    SELECT
        c.CohortMonth,
        p.PurchaseMonth,
        DATEDIFF(MONTH, c.CohortMonth, p.PurchaseMonth) AS MonthOffset,
        p.CustomerId
    FROM Cohorts c
    JOIN Purchases p
        ON p.CustomerId = c.CustomerId
)
SELECT
    CohortMonth,
    MonthOffset,
    COUNT(DISTINCT CustomerId) AS ActiveCustomers
FROM Activity
GROUP BY CohortMonth, MonthOffset
ORDER BY CohortMonth, MonthOffset;
```

Очікуваний результат:
- Cohort 2025-01-01: offset 0 → 2 клієнти (1,2); offset 1 → 1 (1); offset 2 → 1 (1)
- Cohort 2025-02-01: offset 0 → 1 (3); offset 1 → 1 (3)
- Cohort 2025-03-01: offset 0 → 1 (4)

## Підсумок
- `GROUPING SETS` — найпрозоріший спосіб описати кілька рівнів агрегації одним запитом.
- `ROLLUP` зручний, але subtotal-рядки потрібно маркувати.
- Для крос-таблиць найпереносиміший підхід — умовна агрегація; `PIVOT` корисний, коли набір колонок фіксований.
- У cohort-запитах “магія” не в SQL, а в точних визначеннях (стартова подія, гранулярність часу).

Довідка (SQL Server):
- https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql
- https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot

*Висновок:* Advanced analytics SQL — це вміння чітко сформулювати бізнес-питання (підсумки, виміри, cohorts) і вибрати найпростіший коректний запит, який не “ламається” з ростом даних.
