/*
Reporting queries (capstone)
Run 01_schema.sql, 02_seed_data.sql, 03_pipeline_load.sql first.
*/

/*
Sanity checks (recommended)
*/

SELECT
    (SELECT COUNT(*) FROM dw.DimCustomer)   AS DimCustomerCount,
    (SELECT COUNT(*) FROM dw.DimProduct)    AS DimProductCount,
    (SELECT COUNT(*) FROM dw.FactOrderItem) AS FactOrderItemCount;

SELECT TOP (20) BatchId, StartedAt, EndedAt, Status, Message
FROM etl.LoadBatch
ORDER BY BatchId DESC;

-- Data quality: orphan checks (should be zero)
SELECT COUNT(*) AS OrphanFacts
FROM dw.FactOrderItem f
LEFT JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
LEFT JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
WHERE c.CustomerKey IS NULL OR p.ProductKey IS NULL;

-- 1) Daily revenue
SELECT
    CAST(OrderTime AS date) AS OrderDate,
    SUM(Revenue) AS Revenue
FROM dw.FactOrderItem
GROUP BY CAST(OrderTime AS date)
ORDER BY OrderDate;

-- 2) Monthly revenue
SELECT
    DATEFROMPARTS(YEAR(OrderTime), MONTH(OrderTime), 1) AS OrderMonth,
    SUM(Revenue) AS Revenue
FROM dw.FactOrderItem
GROUP BY DATEFROMPARTS(YEAR(OrderTime), MONTH(OrderTime), 1)
ORDER BY OrderMonth;

-- 3) Revenue by product
SELECT
    p.Sku,
    p.Name,
    SUM(f.Qty) AS Qty,
    SUM(f.Revenue) AS Revenue
FROM dw.FactOrderItem f
JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
GROUP BY p.Sku, p.Name
ORDER BY Revenue DESC;

-- 4) Top product per month
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(OrderTime), MONTH(OrderTime), 1) AS OrderMonth,
        p.Sku,
        SUM(f.Revenue) AS Revenue
    FROM dw.FactOrderItem f
    JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
    GROUP BY DATEFROMPARTS(YEAR(OrderTime), MONTH(OrderTime), 1), p.Sku
)
SELECT *
FROM
(
    SELECT
        OrderMonth,
        Sku,
        Revenue,
        ROW_NUMBER() OVER (PARTITION BY OrderMonth ORDER BY Revenue DESC) AS rn
    FROM Monthly
) x
WHERE rn = 1
ORDER BY OrderMonth;

-- 5) Customer lifetime revenue
SELECT
    c.Email,
    SUM(f.Revenue) AS LifetimeRevenue
FROM dw.FactOrderItem f
JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
GROUP BY c.Email
ORDER BY LifetimeRevenue DESC;

-- 6) Orders per customer
SELECT
    c.Email,
    COUNT(DISTINCT f.OrderId) AS Orders
FROM dw.FactOrderItem f
JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
GROUP BY c.Email
ORDER BY Orders DESC;

-- 7) Average order value (AOV)
WITH Orders AS
(
    SELECT OrderId, SUM(Revenue) AS OrderRevenue
    FROM dw.FactOrderItem
    GROUP BY OrderId
)
SELECT AVG(OrderRevenue) AS AvgOrderValue
FROM Orders;

-- 8) Repeat customers (>= 2 orders)
WITH OrdersPerCustomer AS
(
    SELECT CustomerKey, COUNT(DISTINCT OrderId) AS OrderCount
    FROM dw.FactOrderItem
    GROUP BY CustomerKey
)
SELECT COUNT(*) AS RepeatCustomers
FROM OrdersPerCustomer
WHERE OrderCount >= 2;

-- 9) Cohorts: first order month and retention
WITH CustomerMonths AS
(
    SELECT
        CustomerKey,
        DATEFROMPARTS(YEAR(MIN(OrderTime)), MONTH(MIN(OrderTime)), 1) AS CohortMonth
    FROM dw.FactOrderItem
    GROUP BY CustomerKey
),
Activity AS
(
    SELECT
        cm.CohortMonth,
        DATEFROMPARTS(YEAR(f.OrderTime), MONTH(f.OrderTime), 1) AS ActivityMonth,
        DATEDIFF(MONTH, cm.CohortMonth, DATEFROMPARTS(YEAR(f.OrderTime), MONTH(f.OrderTime), 1)) AS MonthOffset,
        f.CustomerKey
    FROM dw.FactOrderItem f
    JOIN CustomerMonths cm ON cm.CustomerKey = f.CustomerKey
)
SELECT
    CohortMonth,
    MonthOffset,
    COUNT(DISTINCT CustomerKey) AS ActiveCustomers
FROM Activity
GROUP BY CohortMonth, MonthOffset
ORDER BY CohortMonth, MonthOffset;

-- 10) Revenue by customer and month (useful for BI exports)
SELECT
    c.Email,
    DATEFROMPARTS(YEAR(f.OrderTime), MONTH(f.OrderTime), 1) AS OrderMonth,
    SUM(f.Revenue) AS Revenue
FROM dw.FactOrderItem f
JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
GROUP BY c.Email, DATEFROMPARTS(YEAR(f.OrderTime), MONTH(f.OrderTime), 1)
ORDER BY c.Email, OrderMonth;

-- 11) Product mix by month
SELECT
    DATEFROMPARTS(YEAR(f.OrderTime), MONTH(f.OrderTime), 1) AS OrderMonth,
    p.Sku,
    SUM(f.Qty) AS Qty
FROM dw.FactOrderItem f
JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
GROUP BY DATEFROMPARTS(YEAR(f.OrderTime), MONTH(f.OrderTime), 1), p.Sku
ORDER BY OrderMonth, Qty DESC;

-- 12) Batch history (ops)
SELECT BatchId, StartedAt, EndedAt, Status, Message
FROM etl.LoadBatch
ORDER BY BatchId DESC;

-- 13) Data quality: orphan checks
SELECT COUNT(*) AS OrphanFacts
FROM dw.FactOrderItem f
LEFT JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
LEFT JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
WHERE c.CustomerKey IS NULL OR p.ProductKey IS NULL;

-- 14) Identify inactive products still selling (should be zero in real rules)
SELECT p.Sku, SUM(f.Revenue) AS Revenue
FROM dw.FactOrderItem f
JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
WHERE p.IsActive = 0
GROUP BY p.Sku;

-- 15) Revenue concentration (top N products share)
WITH ByProduct AS
(
    SELECT p.Sku, SUM(f.Revenue) AS Revenue
    FROM dw.FactOrderItem f
    JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
    GROUP BY p.Sku
),
Ranked AS
(
    SELECT
        Sku,
        Revenue,
        SUM(Revenue) OVER() AS TotalRevenue,
        SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumRevenue
    FROM ByProduct
)
SELECT
    Sku,
    Revenue,
    CAST(100.0 * Revenue / NULLIF(TotalRevenue, 0) AS decimal(6,2)) AS PctOfTotal,
    CAST(100.0 * CumRevenue / NULLIF(TotalRevenue, 0) AS decimal(6,2)) AS CumPctOfTotal
FROM Ranked
ORDER BY Revenue DESC;
