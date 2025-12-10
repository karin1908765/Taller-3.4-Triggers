-- Triggers
-- grupo bartolitos
-- 10/12/2025

-- ========== PUBS ========== 
USE pubs;
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

-- Auditoría de INSERT en Titles
IF OBJECT_ID('Auditoria.TitlesInsert') IS NOT NULL DROP TABLE Auditoria.TitlesInsert;
CREATE TABLE Auditoria.TitlesInsert (
    idAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    title_id VARCHAR(6),
    title VARCHAR(80),
    price MONEY,
    fecha DATETIME DEFAULT GETDATE()
);

-- Auditoría de UPDATE en price de Titles
IF OBJECT_ID('Auditoria.TitlesPriceUpdate') IS NOT NULL DROP TABLE Auditoria.TitlesPriceUpdate;
CREATE TABLE Auditoria.TitlesPriceUpdate (
    idAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    title_id VARCHAR(6),
    precio_anterior MONEY,
    precio_nuevo MONEY,
    fecha DATETIME DEFAULT GETDATE()
);

-- Auditoría de DELETE en Authors
IF OBJECT_ID('Auditoria.AuthorsDelete') IS NOT NULL DROP TABLE Auditoria.AuthorsDelete;
CREATE TABLE Auditoria.AuthorsDelete (
    idAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    au_id VARCHAR(11),
    au_lname VARCHAR(40),
    au_fname VARCHAR(20),
    fecha DATETIME DEFAULT GETDATE()
);

-- Auditoría de INSERT en Sales
IF OBJECT_ID('Auditoria.SalesInsert') IS NOT NULL DROP TABLE Auditoria.SalesInsert;
CREATE TABLE Auditoria.SalesInsert (
    idAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    stor_id VARCHAR(4),
    ord_num VARCHAR(20),
    qty INT,
    fecha DATETIME DEFAULT GETDATE()
);

-- Tabla de errores por intentos de eliminar publishers con libros
IF OBJECT_ID('Auditoria.PublishersDeleteError') IS NOT NULL DROP TABLE Auditoria.PublishersDeleteError;
CREATE TABLE Auditoria.PublishersDeleteError (
    idAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    pub_id VARCHAR(4),
    mensaje VARCHAR(200),
    fecha DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------
-- TRIGGER 1: AUDITORÍA DE INSERT EN TITLES
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarInsertTitle
ON titles
FOR INSERT
AS
BEGIN
    INSERT INTO Auditoria.TitlesInsert (title_id, title, price)
    SELECT title_id, title, price
    FROM inserted;
END;
GO

SELECT * FROM titles;

INSERT INTO titles (title_id, title, type, pub_id, price)
VALUES ('ZZ1112', 'Principito', 'popular_comp', '0877', 30);

SELECT * FROM Auditoria.TitlesInsert;

---------------------------------------------------------
-- TRIGGER 2: AUDITORÍA DE UPDATE EN PRECIO DE TITLES
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarUpdateTitlePrice
ON titles
FOR UPDATE
AS
BEGIN
    IF UPDATE(price)
    BEGIN
        INSERT INTO Auditoria.TitlesPriceUpdate (title_id, precio_anterior, precio_nuevo)
        SELECT d.title_id, d.price, i.price
        FROM deleted d
        JOIN inserted i ON d.title_id = i.title_id;
    END
END;
GO

SELECT * FROM titles;
UPDATE titles
SET price = price + 5
WHERE title_id = 'ZZ1111';

SELECT * FROM Auditoria.TitlesPriceUpdate;

---------------------------------------------------------
-- TRIGGER 3: AUDITORÍA DE DELETE EN AUTHORS
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarDeleteAuthor
ON authors
FOR DELETE
AS
BEGIN
    INSERT INTO Auditoria.AuthorsDelete (au_id, au_lname, au_fname)
    SELECT au_id, au_lname, au_fname
    FROM deleted;
END;
GO

INSERT INTO authors (au_id, au_lname, au_fname, phone, address, city, state, zip, contract)
VALUES (
    '999-99-9999',
    'Temporal',
    'Autor',
    '999 999-9999',
    'Calle Falsa 123',
    'Lima',
    'LI',
    '00000',
    1  
);

DELETE FROM authors WHERE au_id = '999-99-9999';

SELECT * FROM authors;
SELECT * FROM Auditoria.AuthorsDelete;

---------------------------------------------------------
-- TRIGGER 4: AUDITORÍA DE INSERT EN SALES
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_AuditarInsertSales
ON sales
FOR INSERT
AS
BEGIN
    INSERT INTO Auditoria.SalesInsert (stor_id, ord_num, qty)
    SELECT stor_id, ord_num, qty
    FROM inserted;
END;
GO

SELECT * FROM sales;

INSERT INTO sales (stor_id, ord_num, ord_date, qty, payterms, title_id)
VALUES ('7066', 'A123', GETDATE(), 10, 'NET 30', 'ZZ1111');

SELECT * FROM Auditoria.SalesInsert;

---------------------------------------------------------
-- TRIGGER 5: BLOQUEAR DELETE EN PUBLISHERS SI TIENE TITLES
---------------------------------------------------------
CREATE OR ALTER TRIGGER TR_BloquearDeletePublisher
ON publishers
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM titles t
        JOIN deleted d ON t.pub_id = d.pub_id
    )
    BEGIN
        INSERT INTO Auditoria.PublishersDeleteError (pub_id, mensaje)
        SELECT pub_id, 'No se puede eliminar: publisher tiene títulos asociados.'
        FROM deleted;

        RAISERROR('No se puede eliminar: publisher tiene títulos asociados.', 16, 1);
        RETURN;
    END;

    DELETE FROM publishers
    WHERE pub_id IN (SELECT pub_id FROM deleted);
END;
GO

DELETE FROM publishers WHERE pub_id = '1389';

SELECT * FROM Auditoria.PublishersDeleteError;


IF OBJECT_ID('Auditoria.SalesInsert') IS NOT NULL 
    DROP TABLE Auditoria.SalesInsert;
GO


-- AUDITORIA:registrar todos los cambios en el nivel de trabajo de los empleados.
-- TRIGGER 6: registrar todos los cambios en el nivel de trabajo de los empleados.
IF OBJECT_ID('Auditoria.EmployeeJobLevelUpdate') IS NOT NULL 
    DROP TABLE Auditoria.EmployeeJobLevelUpdate;
GO

CREATE TABLE Auditoria.EmployeeJobLevelUpdate (
    IdAuditoria INT IDENTITY(1,1) PRIMARY KEY,
    emp_id CHAR(9),
    job_id CHAR(3),
    nivel_anterior TINYINT,
    nivel_nuevo   TINYINT,
    fecha DATETIME DEFAULT GETDATE()
);
GO

CREATE OR ALTER TRIGGER TR_AuditarUpdateJobLevel
ON employee
FOR UPDATE
AS
BEGIN
    -- Solo registrar si se actualiza job_lvl
    IF UPDATE(job_lvl)
    BEGIN
        INSERT INTO Auditoria.EmployeeJobLevelUpdate (emp_id, job_id, nivel_anterior, nivel_nuevo)
        SELECT d.emp_id, d.job_id, d.job_lvl AS nivel_anterior, i.job_lvl AS nivel_nuevo
        FROM deleted d
        JOIN inserted i ON d.emp_id = i.emp_id;
    END
END;
GO
-- Ver empleados antes
SELECT emp_id, fname, lname, job_id, job_lvl FROM employee;

-- Cambiar el nivel de trabajo a un empleado de prueba
UPDATE employee
SET job_lvl = job_lvl + 1
WHERE emp_id = 'PMA42628M';  -- reemplazar por un emp_id válido de tu tabla

-- Ver auditoría
SELECT * FROM Auditoria.EmployeeJobLevelUpdate;