/*
Capstone schema (SQL Server)

Creates:
- OLTP schema: dbo.Customer, dbo.Product, dbo.[Order], dbo.OrderItem
- Staging schema: stg.*
- Curated schema: dw.*
- ETL metadata: etl.*

Note: This is intentionally small but realistic.
*/

IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('dw')  IS NULL EXEC('CREATE SCHEMA dw');
GO

DROP TABLE IF EXISTS dw.FactOrderItem;
DROP TABLE IF EXISTS dw.DimProduct;
DROP TABLE IF EXISTS dw.DimCustomer;
DROP TABLE IF EXISTS stg.OrderItem;
DROP TABLE IF EXISTS stg.[Order];
DROP TABLE IF EXISTS stg.Product;
DROP TABLE IF EXISTS stg.Customer;
DROP TABLE IF EXISTS etl.LoadBatch;
DROP TABLE IF EXISTS dbo.OrderItem;
DROP TABLE IF EXISTS dbo.[Order];
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.Customer;
GO

CREATE TABLE etl.LoadBatch
(
    BatchId      int            NOT NULL PRIMARY KEY,
    StartedAt    datetime2(0)   NOT NULL,
    EndedAt      datetime2(0)   NULL,
    Status       varchar(20)    NOT NULL,
    Message      varchar(4000)  NULL
);
GO

CREATE TABLE dbo.Customer
(
    CustomerId   int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Email        varchar(200)      NOT NULL,
    CreatedAt    datetime2(0)      NOT NULL,
    CONSTRAINT UQ_Customer_Email UNIQUE (Email)
);
GO

CREATE TABLE dbo.Product
(
    ProductId    int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Sku          varchar(50)       NOT NULL,
    Name         varchar(200)      NOT NULL,
    UnitPrice    decimal(12,2)     NOT NULL,
    IsActive     bit               NOT NULL,
    CONSTRAINT UQ_Product_Sku UNIQUE (Sku)
);
GO

CREATE TABLE dbo.[Order]
(
    OrderId      int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerId   int              NOT NULL,
    OrderTime    datetime2(0)     NOT NULL,
    Status       varchar(20)      NOT NULL,
    CONSTRAINT FK_Order_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer(CustomerId)
);
GO

CREATE TABLE dbo.OrderItem
(
    OrderItemId  int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    OrderId      int              NOT NULL,
    ProductId    int              NOT NULL,
    Qty          int              NOT NULL,
    UnitPrice    decimal(12,2)    NOT NULL,
    CONSTRAINT FK_OrderItem_Order   FOREIGN KEY (OrderId)   REFERENCES dbo.[Order](OrderId),
    CONSTRAINT FK_OrderItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product(ProductId)
);
GO

CREATE TABLE stg.Customer
(
    BatchId    int           NOT NULL,
    Email      varchar(200)  NOT NULL,
    CreatedAt  datetime2(0)  NOT NULL,
    CONSTRAINT PK_stgCustomer PRIMARY KEY (BatchId, Email)
);
GO

CREATE TABLE stg.Product
(
    BatchId    int           NOT NULL,
    Sku        varchar(50)   NOT NULL,
    Name       varchar(200)  NOT NULL,
    UnitPrice  decimal(12,2) NOT NULL,
    IsActive   bit           NOT NULL,
    CONSTRAINT PK_stgProduct PRIMARY KEY (BatchId, Sku)
);
GO

CREATE TABLE stg.[Order]
(
    BatchId    int           NOT NULL,
    OrderId    int           NOT NULL,
    Email      varchar(200)  NOT NULL,
    OrderTime  datetime2(0)  NOT NULL,
    Status     varchar(20)   NOT NULL,
    CONSTRAINT PK_stgOrder PRIMARY KEY (BatchId, OrderId)
);
GO

CREATE TABLE stg.OrderItem
(
    BatchId   int           NOT NULL,
    OrderId   int           NOT NULL,
    Sku       varchar(50)   NOT NULL,
    Qty       int           NOT NULL,
    UnitPrice decimal(12,2) NOT NULL,
    CONSTRAINT PK_stgOrderItem PRIMARY KEY (BatchId, OrderId, Sku)
);
GO

CREATE TABLE dw.DimCustomer
(
    CustomerKey int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Email       varchar(200)      NOT NULL,
    CreatedAt   datetime2(0)      NOT NULL,
    CONSTRAINT UQ_DimCustomer_Email UNIQUE (Email)
);
GO

CREATE TABLE dw.DimProduct
(
    ProductKey int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Sku        varchar(50)       NOT NULL,
    Name       varchar(200)      NOT NULL,
    UnitPrice  decimal(12,2)     NOT NULL,
    IsActive   bit               NOT NULL,
    CONSTRAINT UQ_DimProduct_Sku UNIQUE (Sku)
);
GO

CREATE TABLE dw.FactOrderItem
(
    OrderId      int            NOT NULL,
    OrderTime    datetime2(0)   NOT NULL,
    CustomerKey  int            NOT NULL,
    ProductKey   int            NOT NULL,
    Qty          int            NOT NULL,
    UnitPrice    decimal(12,2)  NOT NULL,
    Revenue      AS (Qty * UnitPrice) PERSISTED,
    CONSTRAINT PK_FactOrderItem PRIMARY KEY (OrderId, ProductKey),
    CONSTRAINT FK_Fact_Customer FOREIGN KEY (CustomerKey) REFERENCES dw.DimCustomer(CustomerKey),
    CONSTRAINT FK_Fact_Product  FOREIGN KEY (ProductKey)  REFERENCES dw.DimProduct(ProductKey)
);
GO

CREATE INDEX IX_Order_OrderTime ON dbo.[Order](OrderTime);
CREATE INDEX IX_Order_Customer_OrderTime ON dbo.[Order](CustomerId, OrderTime);
GO

/*
Validation (optional)

Run these after creating the schema to confirm objects exist.
*/

SELECT s.name AS SchemaName
FROM sys.schemas s
WHERE s.name IN ('etl', 'stg', 'dw')
ORDER BY s.name;

SELECT
    v.ObjectName,
    OBJECT_ID(v.ObjectName) AS ObjectId
FROM (VALUES
    ('etl.LoadBatch'),
    ('dbo.Customer'),
    ('dbo.Product'),
    ('dbo.[Order]'),
    ('dbo.OrderItem'),
    ('stg.Customer'),
    ('stg.Product'),
    ('stg.[Order]'),
    ('stg.OrderItem'),
    ('dw.DimCustomer'),
    ('dw.DimProduct'),
    ('dw.FactOrderItem')
) v(ObjectName)
ORDER BY v.ObjectName;
