-----------------------------------------------------------------------------------
-- Script 002                                                                 
--                                                                               
-- INDEXING STRATEGY                               
--   
--  #1  Clustered Index Impact On Nonclustered Indexes
--  #2  IDENTITY Gaps
--  #3  Indexes And Cardinality
--  #4  Composite Index
--  #5  Composite Index vs Index With Included Column 
--  #6  Non-sargable queries 
--  #7  Indexing For JOIN
--  #8  Indexing For ORDER BY
--  #9  Indexing For GROUP BY
-- #10  Indexing For COUNT
-- #11  Indexing For MIN, MAX, SUM, AVG
-- #12  Analyzing Indexes With DMVs
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-----------------------------------------------------------------------------------
-- #1  Clustered Index Impact On Nonclustered Indexes
-----------------------------------------------------------------------------------

--
-- Creates a table for tests
--
SELECT 
	ISNULL(NEWID(),'00000000-0000-0000-0000-000000000000') AS 'order_id', 
	customer_id,
	status,
	order_date
INTO sales.order_WITH_GUID
FROM sales.[order];
 
-- Adds a nonclustered index
CREATE UNIQUE INDEX ix_order_status_order_date ON sales.[order] (status, order_date);
GO 

-- Adds a primary key and a nonclustered index
ALTER TABLE sales.order_WITH_GUID ADD CONSTRAINT pk_order_id_2 PRIMARY KEY (order_id);
CREATE INDEX ix_order_status_order_date_WITH_GUID_NON_UNIQUE ON sales.order_WITH_GUID (status, order_date);
CREATE UNIQUE INDEX ix_order_status_order_date_WITH_GUID_UNIQUE ON sales.order_WITH_GUID (status, order_date);
GO 


--
-- Compares the newly created table with the one from sample db
--
EXEC dbo.get_index_basic_page_info 'ix_order_status_order_date';
EXEC dbo.get_index_basic_page_info 'ix_order_status_order_date_WITH_GUID_UNIQUE';
EXEC dbo.get_index_basic_page_info 'ix_order_status_order_date_WITH_GUID_NON_UNIQUE';


EXEC dbo.get_index_root_page_content 'ix_order_status_order_date';
EXEC dbo.get_index_root_page_content 'ix_order_status_order_date_WITH_GUID_UNIQUE';
EXEC dbo.get_index_root_page_content 'ix_order_status_order_date_WITH_GUID_NON_UNIQUE';


EXEC dbo.get_index_leaf_page_content 'ix_order_status_order_date';
EXEC dbo.get_index_leaf_page_content 'ix_order_status_order_date_WITH_GUID_UNIQUE';
EXEC dbo.get_index_leaf_page_content 'ix_order_status_order_date_WITH_GUID_NON_UNIQUE';

-- Clean up
DROP TABLE IF EXISTS sales.order_WITH_GUID;
DROP INDEX IF EXISTS ix_order_status_order_date ON sales.[order];



-----------------------------------------------------------------------------------
-- #2  IDENTITY Gaps
-----------------------------------------------------------------------------------

--
-- Gaps in ids MIGHT be unacceptable in certain scenarios like: 
-- Accounting system, Student enrollment system
--

CREATE TABLE s02_identity(
	order_id			INT				NOT NULL IDENTITY (1, 1),
	customer_id			INT				NOT NULL,
	status				VARCHAR (50)	NOT NULL,
	order_date			DATETIME		NOT NULL,
	CONSTRAINT pk_order PRIMARY KEY (order_id)
);

BEGIN TRANSACTION 
	INSERT INTO s02_identity(customer_id, status, order_date) 
	SELECT customer_id, status, order_date
	FROM sales.[order];
ROLLBACK

INSERT INTO s02_identity(customer_id, status, order_date) 
SELECT customer_id, status, order_date
FROM sales.[order];


-- Clean up
DROP TABLE IF EXISTS s02_identity;


-----------------------------------------------------------------------------------
-- #3  Indexes And Cardinality
-----------------------------------------------------------------------------------
--
-- How cardinality estimates change the execution plan
--
-- (Clustered index scan)
SELECT 
	customer_id, 
	order_id
FROM sales.[order]
WHERE customer_id = 3 
  AND status = 'OPEN';

-- Adds an index on customer_id column
CREATE INDEX ix_order_customer_id ON sales.[order] (customer_id)
GO

-- Getting orders of a signle customer with an index (Index seek + Key Lookup)
SELECT 
	customer_id, 
	order_id
FROM sales.[order]
WHERE customer_id = 3 
  AND status = 'OPEN';

-- Getting orders of 2 customers (Index seek + Key Lookup)
SELECT 
	customer_id, 
	order_id
FROM sales.[order]
WHERE status = 'OPEN' 
  AND customer_id >= 3 
  AND customer_id <= 4; 
 

-- Getting orders of 3 customers (Clustered index scan)
SELECT
	customer_id, 
	order_id
FROM sales.[order]
WHERE status = 'OPEN' 
  AND customer_id >= 3
  AND customer_id <= 5;  
  

-- Forcing the query optimizer to use a non-clustered index makes the query run longer
SELECT 
	customer_id, 
	order_id
FROM sales.[order] WITH (INDEX(ix_order_customer_id))
WHERE status = 'OPEN' 
  AND customer_id >= 3  
  AND customer_id <= 5; 


-- Creates a covering index
CREATE INDEX ix_order_status_customer_id ON sales.[order] (status, customer_id);
GO

SELECT
	customer_id, 
	order_id
FROM sales.[order]
WHERE status = 'OPEN' 
  AND customer_id >= 3
  AND customer_id <= 5;  

-- Cleanup
DROP INDEX IF EXISTS ix_order_customer_id ON sales.[order];
DROP INDEX IF EXISTS ix_order_status_customer_id ON sales.[order];


-----------------------------------------------------------------------------------
-- #4  Composite Index 
-----------------------------------------------------------------------------------
IF NOT EXISTS (
	SELECT 1 FROM sys.indexes 
	WHERE name='ix_order_item_product_id' 
	  AND object_id = OBJECT_ID('sales.order_item'))
CREATE INDEX ix_order_item_product_id ON sales.order_item (product_id);
 

-- 
-- Filtering with equality
-- 
SELECT *
FROM sales.order_item
WHERE order_id = 8


SELECT *
FROM sales.order_item
WHERE item_id = 6;

SELECT *
FROM sales.order_item
WHERE item_id = 7;


SELECT order_id
FROM sales.order_item
WHERE item_id = 7;

SELECT *
FROM sales.order_item
WHERE item_id = 8;

SELECT *
FROM sales.order_item
WHERE item_id = 9;


-- 
-- Filtering with equality and range
-- 

-- Adds 3 indexes to compare performance between each
CREATE INDEX ix_order_order_date ON sales.[order] (order_date);
CREATE INDEX ix_order_order_date_status ON sales.[order] (order_date, status);
CREATE INDEX ix_order_status_order_date ON sales.[order] (status, order_date);
GO

SELECT order_id  
FROM sales.[order] WITH (INDEX(ix_order_order_date))  -- Forces use of ix_order_order_date index
WHERE status = 'OPEN'
  AND order_date >= '2020-10-01'
  AND order_date <= '2021-10-01'; 

SELECT order_id  
FROM sales.[order] WITH (INDEX(ix_order_order_date_status)) -- Forces use of ix_order_order_date_status index
WHERE status = 'OPEN'
  AND order_date >= '2020-10-01'
  AND order_date <= '2021-10-01'; 

SELECT order_id  
FROM sales.[order] WITH (INDEX(ix_order_status_order_date)) -- Forces use of ix_order_status_order_date index
WHERE status = 'OPEN' 
  AND order_date >= '2020-10-01'
  AND order_date <= '2021-10-01'; 


EXEC dbo.get_index_leaf_page_content 'ix_order_order_date_status';
EXEC dbo.get_index_leaf_page_content 'ix_order_status_order_date';



-- Cleanup
DROP INDEX IF EXISTS ix_order_order_date ON sales.[order];
DROP INDEX IF EXISTS ix_order_order_date_status ON sales.[order];
DROP INDEX IF EXISTS ix_order_status_order_date ON sales.[order];



-----------------------------------------------------------------------------------
-- #5  Composite Index vs Index With Included Column
-----------------------------------------------------------------------------------

-- Creates 2 covering indexes
CREATE NONCLUSTERED INDEX ix_order_status_order_date ON sales.[order] (status, order_date);
CREATE NONCLUSTERED INDEX ix_order_status_including_order_date ON sales.[order] (status) INCLUDE (order_date);
GO


-- Query with an equality operator
SELECT
	order_id,
	order_date
FROM sales.[order] WITH (INDEX(ix_order_status_order_date))
WHERE status = 'CANCELLED';

SELECT
	order_id,
	order_date
FROM sales.[order] WITH (INDEX(ix_order_status_including_order_date))
WHERE status = 'CANCELLED';


-- Query with equality and range operators
SELECT
	order_id,
	order_date
FROM sales.[order] WITH (INDEX(ix_order_status_order_date))
WHERE status = 'CANCELLED'
  AND order_date >= '2020-10-01'
  AND order_date <= '2020-11-01'; 

SELECT
	order_id,
	order_date
FROM sales.[order] WITH (INDEX(ix_order_status_including_order_date))
WHERE status = 'CANCELLED'
  AND order_date >= '2020-10-01'
  AND order_date <= '2020-11-01'; 


-- Compares the content of both indexes
EXEC dbo.get_index_root_page_content 'ix_order_status_order_date';
EXEC dbo.get_index_root_page_content 'ix_order_status_including_order_date';

EXEC dbo.get_index_leaf_page_content 'ix_order_status_order_date';
EXEC dbo.get_index_leaf_page_content 'ix_order_status_including_order_date';



-- Cleanup
DROP INDEX IF EXISTS ix_order_status_order_date ON sales.[order];
DROP INDEX IF EXISTS ix_order_status_including_order_date ON sales.[order];


-----------------------------------------------------------------------------------
-- #6 Non-sargable queries 
-----------------------------------------------------------------------------------

-- Function applied to an indexed column
SELECT *
FROM sales.[order]
WHERE CEILING(order_id) = 632;


-- Mathematical operation applied to an indexed column
SELECT *
FROM sales.[order]
WHERE order_id * 1 = 632;


-- Not the leading column of a composite index
SELECT *
FROM sales.order_item
WHERE item_id = 5;


-- Not indexed column
SELECT *
FROM person.customer
WHERE state = 'NY';


CREATE INDEX ix_customer_state ON person.customer (state);


-- Indexed column with low cardinality value
SELECT *
FROM person.customer
WHERE state = 'NY';


-- When a less common value is used, the ix_customer_state index is used
SELECT *
FROM person.customer
WHERE state = 'AZ';



-- Cleanup
DROP INDEX IF EXISTS ix_customer_state ON person.customer;



-----------------------------------------------------------------------------------
-- #7  Indexing For JOIN
-----------------------------------------------------------------------------------
CREATE TABLE s02_new_order (
	order_id			INT				NOT NULL IDENTITY (1, 1),
	customer_id			INT				NOT NULL,
	status				VARCHAR (50)	NOT NULL,
	order_date			DATETIME		NOT NULL,
	CONSTRAINT pk_s02_new_order PRIMARY KEY (order_id)
);

INSERT INTO s02_new_order(customer_id, status, order_date) 
SELECT customer_id, status, order_date
FROM sales.[order]
	CROSS JOIN (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10)) AS set2(val);
GO

--
-- Sample query for analysis: Hash Join with 2 table scans
--
SELECT 
	name, 
	order_id, 
	order_date, 
	status
FROM person.customer c
	INNER JOIN s02_new_order o ON c.customer_id = o.customer_id
WHERE status = 'OPEN' 
  AND order_date >= '20220101' 
  AND order_date <= '20220218'
  AND c.city = 'Chicago';


--
-- Compares the joins
--

-- Forces Loop Join
SELECT name, order_id, order_date, status
FROM person.customer c INNER LOOP JOIN s02_new_order o ON c.customer_id = o.customer_id
WHERE status = 'OPEN' AND order_date >= '20220101' AND order_date <= '20220218' AND c.city = 'Chicago';
-- Forces Merge Join
SELECT name, order_id, order_date, status
FROM person.customer c INNER MERGE JOIN s02_new_order o ON c.customer_id = o.customer_id 
WHERE status = 'OPEN' AND order_date >= '20220101' AND order_date <= '20220218' AND c.city = 'Chicago';
-- Forces Hash Join
SELECT name, order_id, order_date, status
FROM person.customer c INNER HASH JOIN s02_new_order o ON c.customer_id = o.customer_id 
WHERE status = 'OPEN' AND order_date >= '20220101' AND order_date <= '20220218' AND c.city = 'Chicago';



CREATE INDEX ix_s02_new_order_status_order_date_customer_id
	ON dbo.s02_new_order (status, order_date, customer_id);

CREATE INDEX ix_customer_city ON person.customer(city);

CREATE INDEX ix_s02_new_order_customer_id_status_order_date 
	ON dbo.s02_new_order (customer_id, status, order_date);

CREATE INDEX ix_customer_city_including_name 
	ON person.customer(city) INCLUDE (name);

-- Cleanup
DROP INDEX IF EXISTS ix_customer_city ON person.customer;
DROP INDEX IF EXISTS ix_customer_city_including_name ON person.customer;
DROP TABLE IF EXISTS s02_new_order;

-----------------------------------------------------------------------------------
-- #8  Indexing For ORDER BY
-----------------------------------------------------------------------------------

SELECT
	order_id,
	order_date
FROM sales.[order]
WHERE order_date >= '20220101' 
  AND order_date <= '20220131'
ORDER BY order_date ASC;


-- Creates and index on the order_date column
CREATE INDEX ix_order_order_date ON sales.[order] (order_date ASC);

DROP INDEX IF EXISTS ix_order_order_date ON sales.[order];

-----------------------------------------------------------------------------------
-- #9  Indexing For GROUP BY
-----------------------------------------------------------------------------------

-- Sample table for tests
CREATE TABLE s02_group_by (
	order_id			INT				NOT NULL IDENTITY (1, 1),
	customer_id			INT				NOT NULL,
	status				VARCHAR (50)	NOT NULL,
	order_date			DATETIME		NOT NULL,
	CONSTRAINT pk_s02_group_by PRIMARY KEY (order_id)
);

INSERT INTO s02_group_by(customer_id, status, order_date)
SELECT customer_id, status, order_date
FROM sales.[order]
	CROSS JOIN (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10)) AS set2(val)
CREATE NONCLUSTERED INDEX ix_s02_group_by_customer_id ON s02_group_by (customer_id);
GO

-- Sample query for analysis
SELECT 
	o.customer_id, 
	COUNT(o.status) AS number_of_orders
FROM s02_group_by o
WHERE status = 'OPEN'
GROUP BY o.customer_id;
GO


-- Adds nonclustered indexes
CREATE NONCLUSTERED INDEX ix_s02_group_by_status_customer_id_1 ON s02_group_by (status, customer_id);
CREATE NONCLUSTERED INDEX ix_s02_group_by_status_including_customer_id_2 ON s02_group_by (status) INCLUDE (customer_id);
CREATE NONCLUSTERED INDEX ix_s02_group_by_customer_id_including_status_3 ON s02_group_by (customer_id) INCLUDE (status);
GO


--
-- Compares GROUP BY performance for different indexes
--

-- Forces the clustered index
SELECT o.customer_id, COUNT(o.status) AS number_of_orders
FROM s02_group_by o WITH (INDEX(pk_s02_group_by)) 
WHERE status = 'OPEN'
GROUP BY o.customer_id;

-- Forces the ix_s02_group_by_status_customer_id_1 index
SELECT o.customer_id, COUNT(o.status) AS number_of_orders
FROM s02_group_by o WITH (INDEX(ix_s02_group_by_status_customer_id_1))   
WHERE status = 'OPEN'
GROUP BY o.customer_id;

-- Forces the ix_s02_group_by_status_including_customer_id_2 index
SELECT o.customer_id, COUNT(o.status) AS number_of_orders
FROM s02_group_by o WITH (INDEX(ix_s02_group_by_status_including_customer_id_2)) 
WHERE status = 'OPEN'
GROUP BY o.customer_id;

-- Forces the ix_s02_group_by_customer_id_including_status_3 index
SELECT o.customer_id, COUNT(o.status) AS number_of_orders
FROM s02_group_by o WITH (INDEX(ix_s02_group_by_customer_id_including_status_3))
WHERE status = 'OPEN'
GROUP BY o.customer_id;


-- Compares data that is passed to the aggregate operator for 2 indexes
SELECT o.customer_id
FROM s02_group_by o WITH (INDEX(ix_s02_group_by_status_customer_id_1))
WHERE status = 'OPEN';

SELECT o.customer_id
FROM s02_group_by o WITH (INDEX(ix_s02_group_by_status_including_customer_id_2))
WHERE status = 'OPEN';


-- Shows a leaf page of each index
EXEC dbo.get_index_leaf_page_content 'ix_s02_group_by_status_customer_id_1';
EXEC dbo.get_index_leaf_page_content 'ix_s02_group_by_status_including_customer_id_2';


-- Cleanup
DROP TABLE IF EXISTS s02_group_by;

-----------------------------------------------------------------------------------
-- #10  Indexing For COUNT
-----------------------------------------------------------------------------------

-- Sample table for tests
CREATE TABLE s02_count (
	order_id			INT				NOT NULL IDENTITY (1, 1),
	customer_id			INT				NOT NULL,
	status				VARCHAR (50)	NULL,
	order_date			DATETIME		NOT NULL,
	CONSTRAINT pk_s02_count PRIMARY KEY (order_id)
);

-- Fills the sample table with data
INSERT INTO s02_count(customer_id, status, order_date) 
SELECT customer_id, status, order_date
FROM sales.[order];

-- Creates a nonclustered index on the order_date column
CREATE NONCLUSTERED INDEX ix_s02_count_order_date ON s02_count (order_date);
GO


-- Sample query for tests
SELECT 
	COUNT(status)
FROM s02_count;


-- Gets index information
EXEC dbo.get_index_leaf_page_content 'ix_s02_count_order_date';
EXEC dbo.get_index_basic_page_info 'ix_s02_count_order_date';


-- Clean up
DROP TABLE IF EXISTS s02_count;

-----------------------------------------------------------------------------------
-- #11  Indexing For MIN, MAX, SUM, AVG
-----------------------------------------------------------------------------------

-- Sample table for tests
CREATE TABLE s02_aggregate (
	order_id			INT				NOT NULL IDENTITY (1, 1),
	customer_id			INT				NOT NULL,
	status				VARCHAR (50)	NOT NULL,
	order_date			DATETIME		NOT NULL,
	price				DECIMAL(10,2)	NOT NULL,
	CONSTRAINT pk_s02_aggregate PRIMARY KEY (order_id)
);

-- Fills the sample table with data
INSERT INTO s02_aggregate(customer_id, status, order_date, price) 
SELECT customer_id, status, order_date, customer_id/100
FROM sales.[order]
	CROSS JOIN (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10),
		(11), (12), (13), (14), (15), (16), (17), (18), (19), (20)) AS set2(val);
GO


-- Sample queries for tests
SELECT 
	  MIN(order_date) AS 'Min'
	, MAX(order_date) AS 'Max'
	, SUM(price)	  AS 'Sum'
	, AVG(price)	  AS 'Avg'
    , COUNT(order_id) AS 'Count'
FROM s02_aggregate WITH (INDEX(pk_s02_aggregate));

SELECT 
	  MIN(order_date) AS 'Min'
	, MAX(order_date) AS 'Max'
	, SUM(price)	  AS 'Sum'
	, AVG(price)	  AS 'Avg'
    , COUNT(order_id) AS 'Count'
FROM s02_aggregate;


-- Creates a nonclustered index on the order_date and price columns
CREATE NONCLUSTERED INDEX ix_s02_aggregate_order_date_price ON s02_aggregate (order_date, price);


-- Creates a nonclustered index to speed up grouping
CREATE NONCLUSTERED INDEX ix_s02_aggregate_customer_id1 ON s02_aggregate (customer_id);
CREATE NONCLUSTERED INDEX ix_s02_aggregate_customer_id2 ON s02_aggregate (customer_id, order_date, price);


-- Cleanup
DROP TABLE IF EXISTS s02_aggregate;


-----------------------------------------------------------------------------------
-- #12  Analyzing Indexes With DMVs
-----------------------------------------------------------------------------------

-- Getting index usage statistics
SELECT 
    OBJECT_NAME(s.object_id) AS 'table_name',
	i.name,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
	s.last_user_seek,
	s.last_user_scan,
	s.last_user_lookup
FROM sys.dm_db_index_usage_stats s
	JOIN sys.indexes i ON s.object_id = i.object_id
	 AND s.index_id = i.index_id;


-- Script source: https://www.sqlservercentral.com/articles/finding-and-eliminating-duplicate-or-overlapping-indexes-1
;WITH CTE_INDEX_DATA AS (
    SELECT
        SCHEMA_DATA.name AS schema_name,
        TABLE_DATA.name AS table_name,
        INDEX_DATA.name AS index_name,
        STUFF((SELECT ', ' + COLUMN_DATA_KEY_COLS.name + ' ' + 
                       CASE WHEN INDEX_COLUMN_DATA_KEY_COLS.is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END -- Include column order (ASC / DESC)
               FROM sys.tables AS T
               INNER JOIN sys.indexes INDEX_DATA_KEY_COLS ON T.object_id = INDEX_DATA_KEY_COLS.object_id
               INNER JOIN sys.index_columns INDEX_COLUMN_DATA_KEY_COLS ON INDEX_DATA_KEY_COLS.object_id = INDEX_COLUMN_DATA_KEY_COLS.object_id
                                                                     AND INDEX_DATA_KEY_COLS.index_id = INDEX_COLUMN_DATA_KEY_COLS.index_id
               INNER JOIN sys.columns COLUMN_DATA_KEY_COLS ON T.object_id = COLUMN_DATA_KEY_COLS.object_id
                                                         AND INDEX_COLUMN_DATA_KEY_COLS.column_id = COLUMN_DATA_KEY_COLS.column_id
               WHERE INDEX_DATA.object_id = INDEX_DATA_KEY_COLS.object_id
                 AND INDEX_DATA.index_id = INDEX_DATA_KEY_COLS.index_id
                 AND INDEX_COLUMN_DATA_KEY_COLS.is_included_column = 0
               ORDER BY INDEX_COLUMN_DATA_KEY_COLS.key_ordinal
               FOR XML PATH('')), 1, 2, '') AS key_column_list,
        STUFF((SELECT ', ' + COLUMN_DATA_INC_COLS.name
               FROM sys.tables AS T
               INNER JOIN sys.indexes INDEX_DATA_INC_COLS ON T.object_id = INDEX_DATA_INC_COLS.object_id
               INNER JOIN sys.index_columns INDEX_COLUMN_DATA_INC_COLS ON INDEX_DATA_INC_COLS.object_id = INDEX_COLUMN_DATA_INC_COLS.object_id
                                                                    AND INDEX_DATA_INC_COLS.index_id = INDEX_COLUMN_DATA_INC_COLS.index_id
               INNER JOIN sys.columns COLUMN_DATA_INC_COLS ON T.object_id = COLUMN_DATA_INC_COLS.object_id
                                                         AND INDEX_COLUMN_DATA_INC_COLS.column_id = COLUMN_DATA_INC_COLS.column_id
               WHERE INDEX_DATA.object_id = INDEX_DATA_INC_COLS.object_id
                 AND INDEX_DATA.index_id = INDEX_DATA_INC_COLS.index_id
                 AND INDEX_COLUMN_DATA_INC_COLS.is_included_column = 1
               ORDER BY INDEX_COLUMN_DATA_INC_COLS.key_ordinal
               FOR XML PATH('')), 1, 2, '') AS include_column_list,
        INDEX_DATA.is_disabled
    FROM sys.indexes INDEX_DATA
    INNER JOIN sys.tables TABLE_DATA ON TABLE_DATA.object_id = INDEX_DATA.object_id
    INNER JOIN sys.schemas SCHEMA_DATA ON SCHEMA_DATA.schema_id = TABLE_DATA.schema_id
    WHERE TABLE_DATA.is_ms_shipped = 0
      AND INDEX_DATA.type_desc IN ('NONCLUSTERED', 'CLUSTERED')
)
SELECT
    *
FROM CTE_INDEX_DATA DUPE1
WHERE EXISTS (
    SELECT * FROM CTE_INDEX_DATA DUPE2
    WHERE DUPE1.schema_name = DUPE2.schema_name
      AND DUPE1.table_name = DUPE2.table_name
      AND (DUPE1.key_column_list LIKE LEFT(DUPE2.key_column_list, LEN(DUPE1.key_column_list)) OR DUPE2.key_column_list LIKE LEFT(DUPE1.key_column_list, LEN(DUPE2.key_column_list)))
      AND DUPE1.index_name <> DUPE2.index_name
)
ORDER BY index_name;



-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (2, 'Indexing strategy');
