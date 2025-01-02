-----------------------------------------------------------------------------------
-- Script 014                                                                 
--       
-- HORIZONTAL PARTITIONING                   
--   
-- #1  Partitioned table creation
-- #2  Sliding Window
-- #3  How NOT to merge partitions
-- #4  Partitioned vs non-partitioned tables 
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-----------------------------------------------------------------------------------
-- #1  Partitioned table creation
-----------------------------------------------------------------------------------

-- Creates 6 filegroups and adds a single file to each
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_old;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2020;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2021;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2022;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2023;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2024;
GO
 
ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_old_1,
	FILENAME = 'C:\Udemy\order_report_old.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_old;
ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2020_1,
	FILENAME = 'C:\Udemy\order_report_2020.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2020;

ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2021_1,
	FILENAME = 'C:\Udemy\order_report_2021.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2021;

ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2022_1,
	FILENAME = 'C:\Udemy\order_report_2022.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2022;

ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2023_1,
	FILENAME = 'C:\Udemy\order_report_2023.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2023;

ALTER DATABASE OnlineStore    
ADD FILE
(
	NAME = order_report_2024_1,
	FILENAME = 'C:\Udemy\order_report_2024.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2024;
GO

-- List all filegroups in the db
SELECT 
	name,
	physical_name
FROM sys.database_files


-- Creates a partition function that will create 5 partitions
CREATE PARTITION FUNCTION order_time_partition_function (DATE)
AS RANGE RIGHT 
FOR VALUES (
	'20200101',
	'20210101',
	'20220101',
	'20230101'
);
GO

-- Lists partition function boundaries
SELECT 
    pf.name AS partition_function,
    prv.boundary_id,
    prv.value AS boundry_value
FROM 
    sys.partition_functions AS pf
    INNER JOIN sys.partition_range_values AS prv
    ON pf.function_id = prv.function_id
WHERE 
    pf.name = 'order_time_partition_function';



-- Creates a partition scheme
CREATE PARTITION SCHEME order_time_partition_scheme
AS PARTITION order_time_partition_function
TO (
	order_report_old, 
	order_report_2020, 
	order_report_2021, 
	order_report_2022, 
	order_report_2023, 
	order_report_2024
);
GO


-- Creates an order_report partitioned table
CREATE TABLE sales.order_report (
	order_date		DATE			NOT NULL,
	product_id		VARCHAR(7)		NOT NULL,
	total_quantity	INT 			NOT NULL,
	final_price		DECIMAL(10, 2)	NOT NULL DEFAULT 0,
	CONSTRAINT pk_order_report PRIMARY KEY (order_date, product_id)
) 
ON order_time_partition_scheme (order_date);
GO

-- Populates the order_report table with data
INSERT INTO sales.order_report (
	order_date, 
	product_id,
	total_quantity,
	final_price
)
SELECT
	CONVERT([date], order_date) AS 'order_date',
	product_id,
	SUM(oi.quantity) AS 'total_quantity',
	SUM(
		oi.quantity * 
		oi.list_price * 
		(1.0 - oi.discount_percent/100)
	) AS 'final_price'
FROM sales.[order] o
	INNER JOIN sales.order_item oi ON o.order_id = oi.order_id
WHERE o.order_date < '20240101'
GROUP BY product_id, CONVERT(date, order_date)
ORDER BY order_date
GO


-- The order_report_2020 table serves as a switch out table
CREATE TABLE sales.order_report_2020 (
	order_date		DATE			NOT NULL,
	product_id		VARCHAR(7)		NOT NULL,
	total_quantity	INT 			NOT NULL,
	final_price		DECIMAL(10, 2)	NOT NULL DEFAULT 0,
	CONSTRAINT pk_order_report_2020 PRIMARY KEY (order_date, product_id),
	CONSTRAINT check_date_is_less_than_20210101 CHECK (order_date < '20210101' )
) ON order_report_2020;


-- The order_report_2024 table serves as a switch in table
CREATE TABLE sales.order_report_2024 (
	order_date		DATE			NOT NULL,
	product_id		VARCHAR(7)		NOT NULL,
	total_quantity	INT 			NOT NULL,
	final_price		DECIMAL(10, 2)	NOT NULL DEFAULT 0,
	CONSTRAINT pk_order_report_2024 PRIMARY KEY (order_date, product_id),
	CONSTRAINT check_date_is_greater_than_20240101 CHECK (order_date >= '20240101' )
) ON order_report_2024;
GO

-- Seeds the order_report_2024 table with 36000 orders
SET NOCOUNT ON
SET STATISTICS IO OFF
SET STATISTICS TIME OFF
DECLARE @Counter INT 
SET @Counter=1
WHILE (@Counter <= 36000)
BEGIN

	BEGIN TRAN;
	INSERT INTO sales.order_report_2024(
		order_date, 
		product_id,
		total_quantity,
		final_price
	)
	VALUES(DATEADD(DAY, @Counter/100, '20240101'), (@Counter % 100) + 1, 1, 10)
	COMMIT TRAN;
    SET @Counter  = @Counter  + 1
END

-- The order_report table partitions
EXEC dbo.get_table_filegroup_row_count_info 'order_report'

-----------------------------------------------------------------------------------
-- #2  Sliding Window
-----------------------------------------------------------------------------------

-- Initial state (prior to merging and splitting)
EXEC dbo.get_table_filegroup_row_count_info 'order_report'

SELECT *
FROM sales.order_report
WHERE $PARTITION.order_time_partition_function(order_date) = 2;


-- Adds a new boundary to the partition function
SET STATISTICS IO ON
ALTER PARTITION FUNCTION order_time_partition_function() SPLIT RANGE ('20240101');
SET STATISTICS IO OFF

-- Adds new data (2024 year) to the window
EXEC dbo.get_table_filegroup_row_count_info 'order_report'
ALTER TABLE sales.order_report_2024 SWITCH PARTITION 1 TO sales.order_report PARTITION 6;
EXEC dbo.get_table_filegroup_row_count_info 'order_report'
-- Removes the old data (2020 year) from the window
ALTER TABLE sales.order_report SWITCH PARTITION 2 TO sales.order_report_2020 PARTITION 1;
EXEC dbo.get_table_filegroup_row_count_info 'order_report'

-- Removes a boundary from the partition function
SET STATISTICS IO ON
ALTER PARTITION FUNCTION order_time_partition_function() MERGE RANGE ('20200101');
SET STATISTICS IO OFF

-- Final state
EXEC dbo.get_table_filegroup_row_count_info 'order_report'

-----------------------------------------------------------------------------------
-- #3  How NOT to merge partitions
-----------------------------------------------------------------------------------
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2020_bad_example;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2021_bad_example;
ALTER DATABASE OnlineStore ADD FILEGROUP order_report_2022_bad_example;

ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2020_1_bad_example,
	FILENAME = 'C:\Udemy\order_report_2020_bad_example.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2020_bad_example;

ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2021_1_bad_example,
	FILENAME = 'C:\Udemy\order_report_2021_bad_example.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2021_bad_example;

ALTER DATABASE OnlineStore    
ADD FILE 
(
	NAME = order_report_2022_1_bad_example,
	FILENAME = 'C:\Udemy\order_report_2022_bad_example.ndf',
		SIZE = 5 MB, 
		MAXSIZE = UNLIMITED, 
		FILEGROWTH = 5 MB
) TO FILEGROUP order_report_2022_bad_example;


-- Creates a partition function that will create 3 partitions based on date
CREATE PARTITION FUNCTION order_time_partition_function_bad_example (DATE)
AS RANGE RIGHT 
FOR VALUES (
	'20210101',
	'20220101'
);
GO

-- Creates a partition scheme
CREATE PARTITION SCHEME order_time_partition_scheme_bad_example
AS PARTITION order_time_partition_function_bad_example
TO (
	order_report_2020_bad_example, 
	order_report_2021_bad_example, 
	order_report_2022_bad_example
);
GO

-- Creates a order_report partitioned table
CREATE TABLE sales.order_report_bad_example (
	order_date		DATE			NOT NULL,
	product_id		VARCHAR(7)		NOT NULL,
	total_quantity	INT 			NOT NULL,
	final_price		DECIMAL(10, 2)	NOT NULL DEFAULT 0,
	CONSTRAINT pk_order_report_bad_example PRIMARY KEY (order_date, product_id)
) 
ON order_time_partition_scheme_bad_example (order_date);
GO

-- Populates the order_report table with data
INSERT INTO sales.order_report_bad_example (
	order_date, 
	product_id,
	total_quantity,
	final_price
)
SELECT
	CONVERT([date], order_date) AS 'order_date',
	product_id,
	SUM(oi.quantity) AS 'total_quantity',
	SUM(
		oi.quantity * 
		oi.list_price * 
		(1.0 - oi.discount_percent/100)
	) AS 'final_price'
FROM sales.[order] o
	INNER JOIN sales.order_item oi ON o.order_id = oi.order_id
WHERE o.order_date < '20240101'
GROUP BY product_id, CONVERT(date, order_date)
ORDER BY order_date
GO

-- Creates a switch out table
CREATE TABLE sales.order_report_2020_bad_example (
	order_date		DATE			NOT NULL,
	product_id		VARCHAR(7)		NOT NULL,
	total_quantity	INT 			NOT NULL,
	final_price		DECIMAL(10, 2)	NOT NULL DEFAULT 0,
	CONSTRAINT pk_order_report_2020_bad_example PRIMARY KEY (order_date, product_id),
	CONSTRAINT check_date_is_less_than_20210101_bad_example CHECK (order_date < '20210101' )
) ON order_report_2020_bad_example;



--
-- Merging done incorrectly - causes data movement
--

BEGIN TRY
    BEGIN TRANSACTION;

    -- Initial state 
    EXEC dbo.get_table_filegroup_row_count_info 'order_report_bad_example';

    -- Removes the old data (2020 year) from the partitioned window
    ALTER TABLE sales.order_report_bad_example SWITCH PARTITION 1 TO sales.order_report_2020_bad_example PARTITION 1;

    EXEC dbo.get_table_filegroup_row_count_info 'order_report_bad_example';

    SET STATISTICS IO ON;
    ALTER PARTITION FUNCTION order_time_partition_function_bad_example() MERGE RANGE ('20210101');
    SET STATISTICS IO OFF;

    -- Final state
    EXEC dbo.get_table_filegroup_row_count_info 'order_report_bad_example';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Logs error
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT 
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;


-----------------------------------------------------------------------------------
-- #4  Partitioned vs non-partitioned tables 
-----------------------------------------------------------------------------------

-- Creates a non-partitioned table 
-- with the exact same structure as the partitioned one for comparison
SELECT *
INTO sales.order_report_non_partitioned 
FROM  sales.order_report;

-- Adds a primary key/clustered index to the order_report_non_partitioned table
ALTER TABLE sales.order_report_non_partitioned 
	ADD CONSTRAINT pk_order_report_non_partitioned PRIMARY KEY (order_date, product_id);


-- Enables IO to compare performance
SET STATISTICS IO ON;


-- Full table scan
SELECT 
	order_date, 
	product_id, 
	total_quantity, 
	final_price 
FROM sales.order_report;

SELECT 
	order_date, 
	product_id, 
	total_quantity, 
	final_price 
FROM sales.order_report_non_partitioned;


-- Range scan
SELECT 
	order_date, 
	product_id, 
	total_quantity, 
	final_price 
FROM sales.order_report
WHERE order_date BETWEEN '20210101' AND '20211231';

SELECT 
	order_date, 
	product_id, 
	total_quantity, 
	final_price 
FROM sales.order_report_non_partitioned
WHERE order_date BETWEEN '20210101' AND '20211231';


-- Adds a nonclustered non-unique index to partitioned and non-partitioned tables
CREATE NONCLUSTERED INDEX ix_total_quantity ON sales.order_report (total_quantity);
CREATE NONCLUSTERED INDEX ix_total_quantity_non_partitioned ON sales.order_report_non_partitioned (total_quantity);

-- Maximum total_quantity
SELECT 
	MAX(total_quantity) 
FROM sales.order_report;

SELECT 
	MAX(total_quantity) 
FROM sales.order_report_non_partitioned;

-- Join on product_id
SELECT * 
FROM sales.order_report orep 
	JOIN production.product p ON orep.product_id = p.product_id
WHERE orep.total_quantity = 8;

SELECT * 
FROM sales.order_report_non_partitioned orep 
	JOIN production.product p ON orep.product_id = p.product_id
WHERE orep.total_quantity = 8;



-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (14, 'Horizontal partitioning');
