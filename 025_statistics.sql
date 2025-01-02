---------------------------------------------------------------------------------
-- Script 025                                                                 
--       
-- STATISTICS   
--
-- #1  Building blocks of statistics
-- #2  Handling data skewness with filtered statistics
-- #3  How the query optimizer uses statistics  
-- #4  Outdated statistics and performance degradation (excessive memory grant example)
--
---------------------------------------------------------------------------------
USE OnlineStore;
GO

-----------------------------------------------------------------------------------
-- #1  Building blocks of statistics
-----------------------------------------------------------------------------------
 
DBCC SHOW_STATISTICS ('sales.order_item', 'pk_order_item');


SELECT *
FROM sales.order_item
WHERE order_id = 186;


 
-----------------------------------------------------------------------------------
-- #2  Handling data skewness with filtered statistics
-----------------------------------------------------------------------------------

-- Creates a table to store skewed data
CREATE TABLE skewed_table (
    id				INT IDENTITY(1,1) PRIMARY KEY,
    skewed_value	INT,
	content			VARCHAR(20)
);

-- Seeds the skewed_table
SET NOCOUNT ON;
DECLARE @iterator				INT = 1; -- Loop counter
DECLARE @max_row_count			INT = 200000;
DECLARE @duplicated_value		INT = 1;
DECLARE @duplication_row_count	INT = 500; -- Number of times each value will be duplicated

WHILE @iterator <= @max_row_count
BEGIN
   
    IF  (@iterator > (@duplicated_value + @duplication_row_count + 50)) -- If condition to introduce duplication of values
	BEGIN
		DECLARE @duplication_iterator INT = 1; -- Counter for inner loop
		SET @duplicated_value = @iterator; -- Initializes the duplicated value
		
		-- Inner loop to insert duplicated values
		WHILE @duplication_iterator <= @duplication_row_count
		BEGIN
			INSERT INTO skewed_table (skewed_value, content)
			VALUES (@duplicated_value, 'content');
			SET @duplication_iterator = @duplication_iterator + 1;
		END;

		SET @iterator = @iterator + @duplication_row_count; -- Increments outer loop counter by duplication row count
	END
    ELSE 
		BEGIN
			INSERT INTO skewed_table (skewed_value,content)
			VALUES (@iterator, 'content'); -- Inserts a single value
		END
	
	SET @iterator = @iterator + 1; -- Increments outer loop counter
END;

-- Displays duplicated values
SELECT 
	skewed_value, 
	COUNT(*) AS 'count'
FROM skewed_table
GROUP BY skewed_value 
HAVING COUNT(*) > 2
ORDER BY skewed_value ASC;



-- Creates an index on the skewed_value column
CREATE INDEX ix_skewed_value ON skewed_table (skewed_value);


-- Retrieves statistics for the index 'ix_skewed_value'
DBCC SHOW_STATISTICS ('dbo.skewed_table', 'ix_skewed_value');




-- Sample query for tests
SELECT * FROM skewed_table WHERE skewed_value = 552;


---- Creates filtered statistics on the first half of the 'skewed_value' range
CREATE STATISTICS stts_skewed_table_1_100000 ON skewed_table (skewed_value)
	WHERE skewed_value >= 1 
	  AND skewed_value <= 100000
WITH FULLSCAN;
---- Creates filtered statistics on the second half of the 'skewed_value' range
CREATE STATISTICS stts_skewed_table_100001 ON skewed_table (skewed_value)
	WHERE skewed_value > 100000
WITH FULLSCAN;



-- Displays filtered statistics
DBCC SHOW_STATISTICS ('dbo.skewed_table', 'stts_skewed_table_1_100000');
SELECT 
	skewed_value, 
	COUNT(*) AS 'count'
FROM skewed_table
GROUP BY skewed_value 
HAVING COUNT(*) > 2
ORDER BY skewed_value ASC;
DBCC SHOW_STATISTICS ('dbo.skewed_table', 'stts_skewed_table_100001') WITH HISTOGRAM;



-- Drops the statistics 
DROP STATISTICS dbo.skewed_table.stts_skewed_table_1_100000;
DROP STATISTICS dbo.skewed_table.stts_skewed_table_100001;



-----------------------------------------------------------------------------------
-- #3  How the query optimizer uses statistics  
-----------------------------------------------------------------------------------

--
-- 1: The histogram is used when constant value expression is compared to indexed column
--

DBCC SHOW_STATISTICS ('dbo.skewed_table', 'ix_skewed_value') WITH HISTOGRAM;
-- EQ_ROWS is used: 1 row
SELECT * FROM skewed_table WHERE skewed_value = 199999; 

--  AVG_RANGE_ROWS is used: 6.8 rows
DBCC SHOW_STATISTICS ('dbo.skewed_table', 'ix_skewed_value') WITH HISTOGRAM;
SELECT * FROM skewed_table WHERE skewed_value = 199998;

-- Range 
DBCC SHOW_STATISTICS ('dbo.skewed_table', 'ix_skewed_value') WITH HISTOGRAM;
SELECT * FROM skewed_table 
WHERE skewed_value >= 197810 
  AND skewed_value <= 199998;


--
-- 2: When the histogram can not be used the density vector is used to estimate the number of rows
--

-- Index density calculation 
DECLARE @density_of_skewed_value FLOAT 
	= 1.00 / 
			(
				SELECT COUNT(DISTINCT skewed_value) 
				FROM skewed_table
			);
SELECT @density_of_skewed_value as 'density';
DBCC SHOW_STATISTICS ('dbo.skewed_table', 'ix_skewed_value');

-- Estimated number of rows based on the density vector
SELECT estimated_num_of_rows = @density_of_skewed_value * (SELECT COUNT(*) FROM skewed_table);

-- Equality
DECLARE @a INT = 199999;
SELECT * FROM skewed_table 
WHERE skewed_value = @a;

-- Range
DECLARE @b INT = 1;
SELECT * FROM skewed_table 
WHERE skewed_value < @b;


-- Clean up
DROP TABLE IF EXISTS skewed_table;



-----------------------------------------------------------------------------------
-- #4  Outdated statistics and performance degradation (excessive memory grant example)
-----------------------------------------------------------------------------------

-- Inserts data into the target table
CREATE TABLE s025_stats (
    id INT NOT NULL,
    col_2 VARCHAR(1000) NOT NULL
);

-- Populates the table with 100,000 rows
WITH number_generator AS (
    SELECT 1 AS id
    UNION ALL
    SELECT id + 1
    FROM number_generator
    WHERE id < 100000
)
INSERT INTO s025_stats (id, col_2)
SELECT id, CAST(REPLICATE('A', 1000) AS VARCHAR(1000)) AS col_2
FROM number_generator
OPTION (MAXRECURSION 0); 

-- Adds a primary key
ALTER TABLE s025_stats ADD CONSTRAINT pk_s025_stats PRIMARY KEY (id);

-- Displays initial statistics for the primary key index
DBCC SHOW_STATISTICS ('dbo.s025_stats', 'pk_s025_stats');

-- Disables automatic statistics updates for the primary key index
-- AUTO_UPDATE_STATISTICS option
-- Reference: https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics?view=sql-server-ver16
ALTER INDEX pk_s025_stats ON dbo.s025_stats
SET (STATISTICS_NORECOMPUTE = ON);


-- Updates statistics in the s025_stats table
-- UPDATE STATISTICS dbo.s025_stats;



-- Deletes a significant portion of the table to make statistics outdated
DELETE FROM s025_stats
WHERE id >= 1
  AND id <= 50000;

-- Query the remaining data to potentially trigger an excessive memory grant
SELECT 
	id, 
	col_2 
FROM s025_stats
WHERE id <= 50500
ORDER BY col_2;


-- Retrieves the top 20 statements that consumed the largest amounts of execution memory
-- Useful for identifying potential excessive memory grants
-- Reference: https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/troubleshoot-memory-grant-issues
SELECT TOP 20
  SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,  
    ((CASE statement_end_offset   
        WHEN -1 THEN DATALENGTH(ST.text)  
        ELSE QS.statement_end_offset END   
            - QS.statement_start_offset)/2) + 1) AS statement_text  
  ,CONVERT(DECIMAL (10,2), max_grant_kb /1024.0) AS max_grant_mb
  ,CONVERT(DECIMAL (10,2), min_grant_kb /1024.0) AS min_grant_mb
  ,CONVERT(DECIMAL (10,2), (total_grant_kb / execution_count) /1024.0) AS avg_grant_mb
  ,CONVERT(DECIMAL (10,2), max_used_grant_kb /1024.0) AS max_grant_used_mb
  ,CONVERT(DECIMAL (10,2), min_used_grant_kb /1024.0) AS min_grant_used_mb
  ,CONVERT(DECIMAL (10,2), (total_used_grant_kb/ execution_count)  /1024.0) AS avg_grant_used_mb
  ,CONVERT(DECIMAL (10,2), (total_ideal_grant_kb/ execution_count)  /1024.0) AS avg_ideal_grant_mb
  ,CONVERT(DECIMAL (10,2), (total_ideal_grant_kb/ 1024.0)) AS total_grant_for_all_executions_mb
  ,execution_count
FROM sys.dm_exec_query_stats QS
  CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST
WHERE max_grant_kb > 10240 -- greater than 10 MB
ORDER BY max_grant_kb DESC


-- Clean up
DROP TABLE IF EXISTS dbo.s025_stats;



----------------------------------------------------------------------------------
-- Updates the schema migration history table
----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (25, 'Statistics');
