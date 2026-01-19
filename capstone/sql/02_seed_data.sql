/* Seed data for capstone */

INSERT INTO dbo.Customer (Email, CreatedAt)
VALUES
('a@example.com', '2025-01-01T10:00:00'),
('b@example.com', '2025-01-05T12:00:00'),
('c@example.com', '2025-02-01T09:00:00');

INSERT INTO dbo.Product (Sku, Name, UnitPrice, IsActive)
VALUES
('SKU-001', 'Keyboard',  50.00, 1),
('SKU-002', 'Mouse',     25.00, 1),
('SKU-003', 'Monitor',  200.00, 1);

INSERT INTO dbo.[Order] (CustomerId, OrderTime, Status)
SELECT c.CustomerId, v.OrderTime, v.Status
FROM dbo.Customer c
JOIN (VALUES
    ('a@example.com', '2025-02-10T10:30:00', 'paid'),
    ('a@example.com', '2025-03-02T14:00:00', 'paid'),
    ('b@example.com', '2025-03-05T08:15:00', 'paid')
) v(Email, OrderTime, Status)
    ON v.Email = c.Email;

INSERT INTO dbo.OrderItem (OrderId, ProductId, Qty, UnitPrice)
SELECT o.OrderId, p.ProductId, v.Qty, v.UnitPrice
FROM dbo.[Order] o
JOIN dbo.Customer c ON c.CustomerId = o.CustomerId
JOIN dbo.Product p ON p.Sku = v.Sku
JOIN (VALUES
    ('a@example.com', '2025-02-10T10:30:00', 'SKU-001', 1, 50.00),
    ('a@example.com', '2025-02-10T10:30:00', 'SKU-002', 2, 25.00),
    ('a@example.com', '2025-03-02T14:00:00', 'SKU-003', 1, 200.00),
    ('b@example.com', '2025-03-05T08:15:00', 'SKU-002', 1, 25.00)
) v(Email, OrderTime, Sku, Qty, UnitPrice)
    ON v.Email = c.Email AND v.OrderTime = o.OrderTime;

/*
Validation (optional)
*/

SELECT
    (SELECT COUNT(*) FROM dbo.Customer)   AS CustomerCount,
    (SELECT COUNT(*) FROM dbo.Product)    AS ProductCount,
    (SELECT COUNT(*) FROM dbo.[Order])    AS OrderCount,
    (SELECT COUNT(*) FROM dbo.OrderItem)  AS OrderItemCount;

-- Orphan checks (should be zero)
SELECT COUNT(*) AS OrphanOrders
FROM dbo.[Order] o
LEFT JOIN dbo.Customer c ON c.CustomerId = o.CustomerId
WHERE c.CustomerId IS NULL;

SELECT COUNT(*) AS OrphanOrderItems
FROM dbo.OrderItem oi
LEFT JOIN dbo.[Order] o ON o.OrderId = oi.OrderId
LEFT JOIN dbo.Product p ON p.ProductId = oi.ProductId
WHERE o.OrderId IS NULL OR p.ProductId IS NULL;
