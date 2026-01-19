**Мова:** [English](../../../../course/lessons/17_table_expressions_lab_pack.md) | Українська

<h2 align="center">Урок 17 — Table expressions lab pack (derived tables, CTE, APPLY)</h2>

*Вступ:* Table expressions — це “інструменти форми” в SQL: вони змінюють те, *як ви пишете* запит і інколи впливають на те, як оптимізатор може його трансформувати. У цьому lab pack ви навчитеся свідомо обирати між derived tables, CTE та `APPLY` — з точки зору коректності (ties, дублікати, NULL), читабельності та plan shape.

**Сфера DBMS:** [CORE] derived tables + CTE; [T-SQL] `CROSS APPLY` / `OUTER APPLY`; [PG] `LATERAL` — близький аналог.

## Мета

- Розуміти, коли derived tables, CTE та APPLY дають однаковий результат (і коли — ні).
- Уникати багів коректності через дублікати, ties та випадкове множення рядків.
- Сформувати інтуїцію щодо plan shape: коли переписування перетворюється на join, spool, sort або “per-row evaluation”.

## Передумови

- Урок 7: Розширені патерни запитів (особливо `EXISTS` / `NOT EXISTS` і APPLY)
- Урок 7B буде корисний, якщо потрібно освіжити віконні функції

## Чому це важливо у проді

Більшість команд “падають” не через синтаксис, а через те, що:

- запит виглядає правильним, але ламається на ties/дублікатах;
- маленький рефакторинг непомітно змінює grain;
- correlated subquery під навантаженням стає RBAR;
- CTE помилково сприймають як “матеріалізований”, і робота повторюється.

Цей lab pack дає патерни та контрприклади, щоб спершу довести коректність, а потім думати про продуктивність.

## Setup для лабів

Датасет спеціально підібраний так, щоб проявлялися класичні edge cases:

- два замовлення одного клієнта з тим самим timestamp (ties)
- дублікати “event” рядків (потрібен dedupe)
- клієнти без замовлень (поведінка outer)

```sql
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.OrderEvents;
GO

CREATE TABLE dbo.Customers(
  CustomerID int NOT NULL PRIMARY KEY,
  CustomerName nvarchar(100) NOT NULL
);

CREATE TABLE dbo.Orders(
  OrderID int NOT NULL PRIMARY KEY,
  CustomerID int NOT NULL,
  OrderDateTime datetime2(0) NOT NULL,
  Amount decimal(10,2) NOT NULL,
  CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);

CREATE TABLE dbo.OrderEvents(
  OrderEventID int NOT NULL PRIMARY KEY,
  OrderID int NOT NULL,
  EventType varchar(20) NOT NULL,
  EventTime datetime2(0) NOT NULL,
  CONSTRAINT FK_OrderEvents_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID)
);

INSERT INTO dbo.Customers(CustomerID, CustomerName)
VALUES
  (1, N'Ada'),
  (2, N'Boris'),
  (3, N'Chloe');

-- У клієнта 1 є tie по OrderDateTime (однаковий timestamp для двох замовлень)
INSERT INTO dbo.Orders(OrderID, CustomerID, OrderDateTime, Amount)
VALUES
  (101, 1, '2025-01-01 10:00:00', 40.00),
  (102, 1, '2025-01-01 10:00:00', 55.00),
  (103, 1, '2025-01-03 09:00:00', 12.00),
  (201, 2, '2025-01-02 11:00:00', 20.00);

-- Дублікати event-ів навмисні (один і той самий type/time)
INSERT INTO dbo.OrderEvents(OrderEventID, OrderID, EventType, EventTime)
VALUES
  (1, 101, 'PLACED', '2025-01-01 10:00:00'),
  (2, 101, 'PAID',   '2025-01-01 10:05:00'),
  (3, 101, 'PAID',   '2025-01-01 10:05:00'),
  (4, 102, 'PLACED', '2025-01-01 10:00:00'),
  (5, 102, 'PAID',   '2025-01-01 10:04:00'),
  (6, 103, 'PLACED', '2025-01-03 09:00:00'),
  (7, 201, 'PLACED', '2025-01-02 11:00:00');
GO
```

Рекомендація, коли тема — performance:

```sql
SET STATISTICS IO, TIME ON;
-- В SSMS/Azure Data Studio: увімкніть Actual Execution Plan.
```

## Основна ідея: що таке “table expression”

Table expression — це те, що поводиться як таблиця у `FROM`, але генерується запитом:

- derived table: `FROM (SELECT ...) AS d`
- CTE: `WITH cte AS (...) SELECT ... FROM cte`
- APPLY: `FROM A CROSS APPLY (SELECT ...) AS x`

Найважливіше — **семантика**, а не синтаксис:

- Вираз рахується один раз чи “на кожен рядок”?
- Чи може оптимізатор його злити/переставити?
- Чи змінюється grain?
- Чи детермінований порядок, коли є ties?

---

## Лаб 1 — Derived table vs CTE (той самий результат)

Завдання: порахувати суму замовлень по клієнту.

```sql
-- Derived table
SELECT d.CustomerID, SUM(d.Amount) AS TotalAmount
FROM (
  SELECT o.CustomerID, o.Amount
  FROM dbo.Orders AS o
) AS d
GROUP BY d.CustomerID
ORDER BY d.CustomerID;

-- CTE
WITH d AS (
  SELECT o.CustomerID, o.Amount
  FROM dbo.Orders AS o
)
SELECT d.CustomerID, SUM(d.Amount) AS TotalAmount
FROM d
GROUP BY d.CustomerID
ORDER BY d.CustomerID;
```

Очікуваний результат:

| CustomerID | TotalAmount |
|-----------:|------------:|
| 1 | 107.00 |
| 2 | 20.00 |

Контрольна думка:
- Часто це просто дві форми запису одного й того самого.

---

## Лаб 2 — CTE — не “temp table” (повторні посилання)

Завдання: двічі використати один і той самий піднабір: (а) count і (б) sum.

```sql
WITH BigOrders AS (
  SELECT o.OrderID, o.CustomerID, o.Amount
  FROM dbo.Orders AS o
  WHERE o.Amount >= 20.00
)
SELECT
  COUNT(*) AS BigOrderCount,
  SUM(Amount) AS BigOrderAmount
FROM BigOrders;
```

Тепер використайте `BigOrders` двічі:

```sql
WITH BigOrders AS (
  SELECT o.OrderID, o.CustomerID, o.Amount
  FROM dbo.Orders AS o
  WHERE o.Amount >= 20.00
)
SELECT
  (SELECT COUNT(*) FROM BigOrders) AS BigOrderCount,
  (SELECT SUM(Amount) FROM BigOrders) AS BigOrderAmount;
```

Обговорення:
- CTE — це *вираз запиту*; оптимізатор може його inline.
- Якщо звертатися до CTE кілька разів, можлива стратегія зі spool або повторним обчисленням.

---

## Лаб 3 — Top-1 замовлення на клієнта: window підхід (детерміновано)

Завдання: повернути одне “найновіше” замовлення на клієнта.

Правило: “найновіше” = максимум `(OrderDateTime, OrderID)`.

```sql
WITH Ranked AS (
  SELECT
    o.CustomerID,
    o.OrderID,
    o.OrderDateTime,
    o.Amount,
    ROW_NUMBER() OVER (
      PARTITION BY o.CustomerID
      ORDER BY o.OrderDateTime DESC, o.OrderID DESC
    ) AS rn
  FROM dbo.Orders AS o
)
SELECT CustomerID, OrderID, OrderDateTime, Amount
FROM Ranked
WHERE rn = 1
ORDER BY CustomerID;
```

Очікувані рядки:

| CustomerID | OrderID | OrderDateTime | Amount |
|-----------:|--------:|:--------------|------:|
| 1 | 103 | 2025-01-03 09:00:00 | 12.00 |
| 2 | 201 | 2025-01-02 11:00:00 | 20.00 |

Контрольна думка:
- Tie-breaker (`OrderID`) робить результат детермінованим.

---

## Лаб 4 — Top-1 замовлення на клієнта: APPLY підхід

Завдання: повернути “найновіше” замовлення на клієнта через `OUTER APPLY`.

```sql
SELECT
  c.CustomerID,
  c.CustomerName,
  x.OrderID,
  x.OrderDateTime,
  x.Amount
FROM dbo.Customers AS c
OUTER APPLY (
  SELECT TOP (1)
    o.OrderID,
    o.OrderDateTime,
    o.Amount
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
  ORDER BY o.OrderDateTime DESC, o.OrderID DESC
) AS x
ORDER BY c.CustomerID;
```

Очікувані рядки:

| CustomerID | CustomerName | OrderID | OrderDateTime | Amount |
|-----------:|:-------------|--------:|:--------------|------:|
| 1 | Ada | 103 | 2025-01-03 09:00:00 | 12.00 |
| 2 | Boris | 201 | 2025-01-02 11:00:00 | 20.00 |
| 3 | Chloe | NULL | NULL | NULL |

Нотатки про tradeoffs:
- APPLY зручний, коли реально потрібне “одне похідне значення на кожен рядок зліва”.
- Але може перетворитися на per-row evaluation, якщо немає індексу/селективності (ризик RBAR).

---

## Лаб 5 — “JOIN до перемоги” створює дублікати (виправляємо APPLY)

Завдання: додати **останній час PAID** для кожного order.

Спочатку naive join (дає дублікати, бо події можуть повторюватись):

```sql
SELECT o.OrderID, o.Amount, e.EventTime
FROM dbo.Orders AS o
LEFT JOIN dbo.OrderEvents AS e
  ON e.OrderID = o.OrderID
 AND e.EventType = 'PAID'
ORDER BY o.OrderID, e.EventTime;
```

Тепер виправте: один рядок на order, latest paid time.

```sql
SELECT
  o.OrderID,
  o.Amount,
  x.LatestPaidTime
FROM dbo.Orders AS o
OUTER APPLY (
  SELECT MAX(e.EventTime) AS LatestPaidTime
  FROM dbo.OrderEvents AS e
  WHERE e.OrderID = o.OrderID
    AND e.EventType = 'PAID'
) AS x
ORDER BY o.OrderID;
```

Очікуваний результат:

| OrderID | Amount | LatestPaidTime |
|--------:|------:|:---------------|
| 101 | 40.00 | 2025-01-01 10:05:00 |
| 102 | 55.00 | 2025-01-01 10:04:00 |
| 103 | 12.00 | NULL |
| 201 | 20.00 | NULL |

---

## Лаб 6 — Correlated subquery vs APPLY (plan shape)

Завдання: для кожного клієнта повернути кількість замовлень.

Correlated subquery:

```sql
SELECT
  c.CustomerID,
  c.CustomerName,
  (
    SELECT COUNT(*)
    FROM dbo.Orders AS o
    WHERE o.CustomerID = c.CustomerID
  ) AS OrderCount
FROM dbo.Customers AS c
ORDER BY c.CustomerID;
```

APPLY-версія:

```sql
SELECT
  c.CustomerID,
  c.CustomerName,
  x.OrderCount
FROM dbo.Customers AS c
OUTER APPLY (
  SELECT COUNT(*) AS OrderCount
  FROM dbo.Orders AS o
  WHERE o.CustomerID = c.CustomerID
) AS x
ORDER BY c.CustomerID;
```

Що дивитись у плані:
- Чи виконується права частина “на кожен рядок” (nested loops + seeks), чи рушій трансформує у join + aggregate?
- Додайте індекс і порівняйте:

```sql
CREATE INDEX IX_Orders_Customer_OrderDateTime ON dbo.Orders(CustomerID, OrderDateTime DESC, OrderID DESC) INCLUDE (Amount);
```

---

## Чеклист: безпечні дефолти

- Перед запитом визначте grain (“1 рядок = …”).
- Для top‑1/top‑N завжди робіть детермінований tie‑breaker.
- Не “лікуйте” дублікати `DISTINCT`, якщо не можете довести, що дублікати логічно неможливі.
- APPLY використовуйте тоді, коли вам справді потрібні похідні дані “на кожен рядок зліва” — і доведіть, що це не стане RBAR у проді.

## Міні‑тест

1. Коли CTE може поводитись так, ніби він “вклеївся” в зовнішній запит?
2. Чому `ORDER BY OrderDateTime` недостатній для top‑1, якщо є ties?
3. Коли APPLY допомагає коректності порівняно з join?
4. Якщо CTE використати двічі, яку стратегію плану може обрати SQL Server, щоб не рахувати заново?

## Підсумок

- Derived tables і CTE часто еквівалентні; обирайте читабельніший.
- CTE — не гарантія зберігання; це вираз.
- APPLY потужний для “похідного набору на рядок зліва”, але його треба застосовувати свідомо.
- Коректність — перша: ties/дублікати/NULL визначають, чи ваш запит безпечний.

Для глибшого бекграунду (класичні патерни):
- https://learn.microsoft.com/en-us/archive/msdn-magazine/2004/february/powerful-t-sql-syntax-gives-sql-server-a-programmability-boost

*Висновок:* Якщо ви можете сформулювати grain, обрати детермінований порядок і пояснити, чи table expression виконується один раз чи “на рядок”, ви здатні безпечно рев’юїти та рефакторити складний SQL.
