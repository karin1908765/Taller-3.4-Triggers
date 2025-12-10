-- Triggers
-- grupo bartolitos
-- 10/12/2025

-- ========== NORTHWIND ========== 
USE Northwind;
GO

---------------------------------------------------------
-- CREAR ESQUEMA DE AUDITORÍA
---------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Auditoria')
BEGIN
    EXEC('CREATE SCHEMA Auditoria');
END
GO

---------------------------------------------------------
-- TABLAS DE AUDITORÍA
---------------------------------------------------------

IF OBJECT_ID('Auditoria.ProductsInsert') IS NOT NULL DROP TABLE Auditoria.ProductsInsert;
CREATE TABLE Auditoria.ProductsInsert (
    IdAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    ProductName NVARCHAR(50),
    UnitPrice MONEY,
    Fecha DATETIME DEFAULT GETDATE()
);

IF OBJECT_ID('Auditoria.ProductsPriceUpdate') IS NOT NULL DROP TABLE Auditoria.ProductsPriceUpdate;
CREATE TABLE Auditoria.ProductsPriceUpdate (
    IdAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    PrecioAnterior MONEY,
    PrecioNuevo MONEY,
    Fecha DATETIME DEFAULT GETDATE()
);

IF OBJECT_ID('Auditoria.OrdersInsert') IS NOT NULL DROP TABLE Auditoria.OrdersInsert;
CREATE TABLE Auditoria.OrdersInsert (
    IdAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    CustomerID NVARCHAR(10),
    EmployeeID INT,
    Fecha DATETIME DEFAULT GETDATE()
);

IF OBJECT_ID('Auditoria.EmployeesDelete') IS NOT NULL DROP TABLE Auditoria.EmployeesDelete;
CREATE TABLE Auditoria.EmployeesDelete (
    IdAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT,
    FirstName NVARCHAR(20),
    LastName NVARCHAR(20),
    Fecha DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------
-- TRIGGER 1: AUDITORÍA DE INSERT EN PRODUCTS
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarInsertProducto
ON Products
FOR INSERT
AS
BEGIN
    INSERT INTO Auditoria.ProductsInsert (ProductID, ProductName, UnitPrice)
    SELECT ProductID, ProductName, UnitPrice
    FROM inserted;
END;
GO

SELECT * FROM Products;

INSERT INTO Products (ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock)
VALUES ('Producto Demo', 1, 1, '10 cajas', 99.99, 20);

SELECT * FROM Auditoria.ProductsInsert;

---------------------------------------------------------
-- TRIGGER 2: AUDITORÍA DE CAMBIOS DE PRECIO EN PRODUCTS
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarUpdatePrecio
ON Products
FOR UPDATE
AS
BEGIN
    IF UPDATE(UnitPrice)
    BEGIN
        INSERT INTO Auditoria.ProductsPriceUpdate (ProductID, PrecioAnterior, PrecioNuevo)
        SELECT d.ProductID, d.UnitPrice, i.UnitPrice
        FROM deleted d
        JOIN inserted i ON d.ProductID = i.ProductID;
    END
END;
GO

SELECT * FROM Products;

UPDATE Products
SET UnitPrice = UnitPrice + 10
WHERE ProductID = 2;

SELECT * FROM Auditoria.ProductsPriceUpdate;

---------------------------------------------------------
-- TRIGGER 3: BLOQUEAR DELETE DE CATEGORIES SI TIENE PRODUCTOS
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_BloquearDeleteCategoria
ON Categories
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Products p
        JOIN deleted d ON p.CategoryID = d.CategoryID
    )
    BEGIN
        RAISERROR('No se puede eliminar: la categoría tiene productos asociados.', 16, 1);
        RETURN;
    END;

    DELETE FROM Categories
    WHERE CategoryID IN (SELECT CategoryID FROM deleted);
END;
GO

SELECT * FROM Categories;

DELETE FROM Categories WHERE CategoryID = 1;




---------------------------------------------------------
-- TRIGGER 4: AUDITORÍA DE INSERT EN ORDERS
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarInsertOrder
ON Orders
FOR INSERT
AS
BEGIN
    INSERT INTO Auditoria.OrdersInsert (OrderID, CustomerID, EmployeeID)
    SELECT OrderID, CustomerID, EmployeeID
    FROM inserted;
END;
GO

SELECT * FROM Orders;

INSERT INTO Orders (CustomerID, EmployeeID, OrderDate)
VALUES ('ALFKI', 1, GETDATE());

SELECT * FROM Auditoria.OrdersInsert;



---------------------------------------------------------
-- TRIGGER 5: AUDITORÍA DE DELETE EN EMPLOYEES
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarDeleteEmpleado
ON Employees
FOR DELETE
AS
BEGIN
    INSERT INTO Auditoria.EmployeesDelete (EmployeeID, FirstName, LastName)
    SELECT EmployeeID, FirstName, LastName
    FROM deleted;
END;
GO

INSERT INTO Employees (FirstName, LastName)
VALUES ('Linares', 'Pepe');

DECLARE @ID INT = SCOPE_IDENTITY();

DELETE FROM Employees WHERE EmployeeID = 12;

SELECT * FROM Auditoria.EmployeesDelete;
SELECT * FROM Employees;
