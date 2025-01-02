-----------------------------------------------------------------------------------
-- Script 015                                                                 
--       
-- VERTICAL PARTITIONING                  
--    
-- #1  A customer description table creation 
-- #2  Vertical partitioning and query performance
-- #3  Index key size and fragmentation
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-----------------------------------------------------------------------------------
-- #1 A customer description table creation
-----------------------------------------------------------------------------------

-- Gets address information of customers with open orders 
SET STATISTICS IO ON
SELECT 
	o.order_date,
	o.order_id,
	c.customer_id,
	c.address,
	c.city,
	c.zip_code
FROM sales.[order] o
	INNER JOIN person.customer c ON o.customer_id = c.customer_id
WHERE o.order_status_type_id = 
	(
		SELECT order_status_type_id 
		FROM sales.order_status_type 
		WHERE name = 'OPEN'
	)
ORDER BY o.order_date, c.customer_id
GO
SET STATISTICS IO OFF
 

-- Displays information about the pk_customer
EXEC dbo.get_index_basic_page_info 'pk_customer'


-- Creates a customer_description table
CREATE TABLE person.customer_description (
	customer_id	INT				NOT NULL,
	description	VARCHAR (2000)	NULL,
	CONSTRAINT pk_customer_description PRIMARY KEY (customer_id),
	CONSTRAINT fk_customer_description_customer FOREIGN KEY(customer_id) 
		REFERENCES person.customer (customer_id) 
		ON DELETE CASCADE
);


INSERT INTO person.customer_description(
	customer_id, 
	description
)
SELECT 
	customer_id, 
	description
FROM person.customer
GO


-- description data has been migrated, so it can be deleted from the customer table
ALTER TABLE person.customer DROP COLUMN [description];
GO

-- Rebuilds all indexes on the customer table
ALTER INDEX ALL ON person.customer REBUILD;


-----------------------------------------------------------------------------------
-- #2 Vertical partitioning and query performance
-----------------------------------------------------------------------------------
ALTER DATABASE OnlineStore ADD FILEGROUP vertical_partitioning;
ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = vertical_partitioning_1,
	FILENAME = 'C:\Udemy\vertical_partitioning.ndf', -- adjust the path
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 100 MB
) TO FILEGROUP vertical_partitioning;
GO

CREATE TABLE dbo.vert_part_FULL
(
	id INT IDENTITY,
	column_1 VARCHAR (10),
	column_2 VARCHAR (1000)
	CONSTRAINT pk_vert_part_full PRIMARY KEY (id)
)

CREATE TABLE dbo.vert_part_PAR1
(
	id INT IDENTITY,
	column_1 VARCHAR (10)
	CONSTRAINT pk_vert_part_PAR1 PRIMARY KEY (id)
)

CREATE TABLE dbo.vert_part_PAR2
(
	id INT IDENTITY,
	column_2 VARCHAR (1000)
	CONSTRAINT pk_vert_part_PAR2 PRIMARY KEY (id),
	FOREIGN KEY (id) REFERENCES vert_part_PAR1(id)
)
GO

-- Inserts 100 000 records
SET NOCOUNT ON;
DECLARE @counter_1 INT = 1
WHILE (@counter_1 <= 1) ---> Change it from 1 to 100000 to test the query
BEGIN
	BEGIN TRAN;
	INSERT INTO dbo.vert_part_FULL(column_1,column_2) VALUES(REPLICATE ('A', 10), REPLICATE ('B', 1000))
	INSERT INTO dbo.vert_part_PAR1(column_1) VALUES(REPLICATE ('A', 10))
	INSERT INTO dbo.vert_part_PAR2(column_2) VALUES(REPLICATE ('B', 1000))
	SET @counter_1 = @counter_1 + 1
	COMMIT TRAN;
END


-- Shows structures of clustered indexes
EXEC dbo.get_index_basic_page_info 
	'pk_vert_part_full,pk_vert_part_PAR1,pk_vert_part_PAR2'

-- Clears the cache
EXEC dbo.clear_cache;
SET STATISTICS IO ON

-- vert_part_FULL vs vert_part_PAR1
-- Getting a single row with column_1
SELECT column_1 
FROM vert_part_FULL
WHERE id = 1000 
------------------------------
SELECT column_1 
FROM vert_part_PAR1
WHERE id = 1000


-- vert_part_FULL vs vert_part_PAR1
-- Getting 1000 rows with column_1
SELECT column_1 
FROM vert_part_FULL
WHERE id <= 1000 
------------------------------
SELECT column_1 
FROM vert_part_PAR1
WHERE id <= 1000


-- vert_part_FULL vs vert_part_PAR1, PAR2
-- Small range
SELECT column_1, column_2 
FROM vert_part_FULL
WHERE id <= 1000
------------------------------
SELECT column_1, column_2 
FROM vert_part_PAR1 p1
	INNER JOIN vert_part_PAR2 p2 ON p1.id = p2.id
WHERE p1.id <= 1000


-- vert_part_FULL vs vert_part_PAR1, PAR2
-- Big range
SELECT column_1, column_2  
FROM vert_part_FULL
WHERE id % 100 = 0
----------------------------
SELECT column_1, column_2  
FROM vert_part_PAR1 p1
	INNER JOIN vert_part_PAR2 p2 ON p1.id = p2.id
WHERE p1.id % 100 = 0



SET STATISTICS IO,TIME OFF
-- Clean up
DROP TABLE IF EXISTS dbo.vert_part_FULL;
DROP TABLE IF EXISTS dbo.vert_part_PAR2;
DROP TABLE IF EXISTS dbo.vert_part_PAR1;
GO

-----------------------------------------------------------------------------------
-- #3 Index key size and fragmentation
-----------------------------------------------------------------------------------
CREATE TABLE dbo.vert_part_INT
(
	id INT IDENTITY,
	column_1 VARCHAR (10),
	CONSTRAINT pk_vert_part_INT PRIMARY KEY (id)
)

CREATE TABLE dbo.vert_part_NEWSEQUENTIALID
(
	id UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID(),
	column_1 VARCHAR (10),
	CONSTRAINT pk_vert_part_NEWSEQUENTIALID PRIMARY KEY (id)
)

CREATE TABLE dbo.vert_part_GUID
(
	id UNIQUEIDENTIFIER DEFAULT NEWID(),
	column_1 VARCHAR (10),
	CONSTRAINT pk_vert_part_GUID PRIMARY KEY (id)
)
GO

SET NOCOUNT ON;
-- Inserts 100 000 records
DECLARE @counter_2 INT = 1
WHILE (@counter_2 <= 1) ---> Change it from 1 to 100000 if you want to test the query
BEGIN
	BEGIN TRAN;
	INSERT INTO dbo.vert_part_INT(column_1) VALUES(REPLICATE ('A', 10))
	INSERT INTO dbo.vert_part_NEWSEQUENTIALID(column_1) VALUES(REPLICATE ('A', 10))
	INSERT INTO dbo.vert_part_GUID(column_1) VALUES(REPLICATE ('A', 10))
	SET @counter_2 = @counter_2 + 1
	COMMIT TRAN;
END

-- Shows structures and fragmentation of clustered indexes
EXEC dbo.get_index_basic_page_info 
	'pk_vert_part_INT, pk_vert_part_NEWSEQUENTIALID, pk_vert_part_GUID';
GO


ALTER INDEX ALL ON dbo.vert_part_GUID REBUILD;

-- Clean up
DROP TABLE IF EXISTS dbo.vert_part_INT;
DROP TABLE IF EXISTS dbo.vert_part_NEWSEQUENTIALID;
DROP TABLE IF EXISTS dbo.vert_part_GUID;
GO
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'vertical_partitioning')
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE vertical_partitioning_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP vertical_partitioning;  
END;



-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (15, 'Vertical partitioning');
