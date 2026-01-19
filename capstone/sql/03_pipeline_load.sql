/*
Capstone pipeline load (idempotent, batch-based)

This script simulates loading from staging into curated (dw) tables.
In a real system, the staging tables would be populated from files or CDC.
*/

DECLARE @BatchId int = 1;
DECLARE @Now datetime2(0) = SYSUTCDATETIME();

IF NOT EXISTS (SELECT 1 FROM etl.LoadBatch WHERE BatchId = @BatchId)
BEGIN
    INSERT INTO etl.LoadBatch (BatchId, StartedAt, Status)
    VALUES (@BatchId, @Now, 'Running');
END
ELSE
BEGIN
    UPDATE etl.LoadBatch
    SET StartedAt = COALESCE(StartedAt, @Now),
        Status = CASE WHEN Status IN ('Succeeded') THEN Status ELSE 'Running' END
    WHERE BatchId = @BatchId;
END

BEGIN TRY
    /* Stage (example): copy current OLTP into stg for this batch */
    DELETE FROM stg.OrderItem WHERE BatchId = @BatchId;
    DELETE FROM stg.[Order]   WHERE BatchId = @BatchId;
    DELETE FROM stg.Product   WHERE BatchId = @BatchId;
    DELETE FROM stg.Customer  WHERE BatchId = @BatchId;

    INSERT INTO stg.Customer (BatchId, Email, CreatedAt)
    SELECT @BatchId, Email, CreatedAt
    FROM dbo.Customer;

    INSERT INTO stg.Product (BatchId, Sku, Name, UnitPrice, IsActive)
    SELECT @BatchId, Sku, Name, UnitPrice, IsActive
    FROM dbo.Product;

    INSERT INTO stg.[Order] (BatchId, OrderId, Email, OrderTime, Status)
    SELECT @BatchId, o.OrderId, c.Email, o.OrderTime, o.Status
    FROM dbo.[Order] o
    JOIN dbo.Customer c ON c.CustomerId = o.CustomerId;

    INSERT INTO stg.OrderItem (BatchId, OrderId, Sku, Qty, UnitPrice)
    SELECT @BatchId, oi.OrderId, p.Sku, oi.Qty, oi.UnitPrice
    FROM dbo.OrderItem oi
    JOIN dbo.Product p ON p.ProductId = oi.ProductId;

    /* Curate dims (idempotent upsert by natural key) */
    MERGE dw.DimCustomer AS tgt
    USING (
        SELECT Email, MIN(CreatedAt) AS CreatedAt
        FROM stg.Customer
        WHERE BatchId = @BatchId
        GROUP BY Email
    ) AS src
        ON src.Email = tgt.Email
    WHEN MATCHED THEN
        UPDATE SET tgt.CreatedAt = tgt.CreatedAt
    WHEN NOT MATCHED THEN
        INSERT (Email, CreatedAt) VALUES (src.Email, src.CreatedAt);

    MERGE dw.DimProduct AS tgt
    USING (
        SELECT Sku, MAX(Name) AS Name, MAX(UnitPrice) AS UnitPrice, MAX(IsActive) AS IsActive
        FROM stg.Product
        WHERE BatchId = @BatchId
        GROUP BY Sku
    ) AS src
        ON src.Sku = tgt.Sku
    WHEN MATCHED THEN
        UPDATE SET
            tgt.Name = src.Name,
            tgt.UnitPrice = src.UnitPrice,
            tgt.IsActive = src.IsActive
    WHEN NOT MATCHED THEN
        INSERT (Sku, Name, UnitPrice, IsActive)
        VALUES (src.Sku, src.Name, src.UnitPrice, src.IsActive);

    /* Fact: rebuild for the batch’s order set (simple approach) */
    DELETE f
    FROM dw.FactOrderItem f
    JOIN stg.[Order] o
        ON o.BatchId = @BatchId
       AND o.OrderId = f.OrderId;

    INSERT INTO dw.FactOrderItem (OrderId, OrderTime, CustomerKey, ProductKey, Qty, UnitPrice)
    SELECT
        o.OrderId,
        o.OrderTime,
        dc.CustomerKey,
        dp.ProductKey,
        oi.Qty,
        oi.UnitPrice
    FROM stg.[Order] o
    JOIN dw.DimCustomer dc
        ON dc.Email = o.Email
    JOIN stg.OrderItem oi
        ON oi.BatchId = @BatchId
       AND oi.OrderId = o.OrderId
    JOIN dw.DimProduct dp
        ON dp.Sku = oi.Sku
    WHERE o.BatchId = @BatchId;

    UPDATE etl.LoadBatch
    SET EndedAt = SYSUTCDATETIME(), Status = 'Succeeded', Message = NULL
    WHERE BatchId = @BatchId;
END TRY
BEGIN CATCH
    UPDATE etl.LoadBatch
    SET EndedAt = SYSUTCDATETIME(), Status = 'Failed', Message = ERROR_MESSAGE()
    WHERE BatchId = @BatchId;

    THROW;
END CATCH;
