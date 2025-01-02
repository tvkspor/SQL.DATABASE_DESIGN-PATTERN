-----------------------------------------------------------------------------------
-- Script 003                                                                 
--       
-- FOREIGN KEY                      
--          
-- #1  Getting information about foreign keys
-- #2  Indexed foreign keys and cascade delete performance
-- #3  Indexed foreign keys and join performance
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-----------------------------------------------------------------------------------
-- #1  Getting information about foreign keys
-----------------------------------------------------------------------------------
-- Retrieves foreign key constraint settings
SELECT * FROM dbo.fk_settings_view;

-- Retrieves missing indexes on foreign keys
SELECT * FROM dbo.missing_indexes_on_fk_view;


-----------------------------------------------------------------------------------
-- #2  Indexed foreign keys and cascade delete performance
-----------------------------------------------------------------------------------
-- Creates 2 tables linked via a foreign key
CREATE TABLE parent (
  parent_id		INT			NOT NULL	IDENTITY PRIMARY KEY,
  data_1		VARCHAR(50) NOT NULL,
);

CREATE TABLE child (
  child_id	INT			NOT NULL	IDENTITY PRIMARY KEY,
  parent_id INT			NOT NULL	REFERENCES parent (parent_id) ON DELETE CASCADE,
  data_1	VARCHAR(50) NOT NULL,
);

-- Inserts 100 000 records into the parent table
SET NOCOUNT ON;
DECLARE @counter_parent INT = 1;
WHILE @counter_parent <= 1 ---> Change it from 1 to 100000 if you want to test the query
BEGIN
    INSERT INTO parent (data_1)
    VALUES (NEWID());
    SET @counter_parent = @counter_parent + 1;
END;

-- Inserts 10 000 000 records into the child table
INSERT INTO child (parent_id, data_1)
SELECT 
	p.parent_id, 
	NEWID()
FROM parent p
CROSS JOIN (SELECT TOP 100 ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS 'row_num' FROM sys.objects) AS numbered_rows;


-- Deletes a single parent
BEGIN TRANSACTION;
	SET STATISTICS IO ON;
		DELETE FROM parent
		WHERE parent_id = 1 
	SET STATISTICS IO OFF;
ROLLBACK TRANSACTION;

-- Adds a nonclustered index on a foreign key
-- Now IO activity is significantly reduced
-- on cascading deletes
CREATE NONCLUSTERED INDEX idx_parent_id ON child (parent_id);


-----------------------------------------------------------------------------------
-- #3  Indexed foreign keys and join performance
-----------------------------------------------------------------------------------

--
-- Compares IO activity difference
--
SET STATISTICS IO ON;
	SELECT *
	FROM parent AS p 
		JOIN child AS c ON p.parent_id = c.parent_id 
	WHERE p.parent_id = 123 
 
	SELECT *
	FROM parent AS p 
		JOIN child AS c ON p.parent_id = c.parent_id 
	WHERE p.parent_id BETWEEN 1 AND 100
 
	-- Drops the index
	DROP INDEX IF EXISTS idx_parent_id ON child;
 
	SELECT *
	FROM parent AS p 
		JOIN child AS c ON p.parent_id = c.parent_id 
	WHERE p.parent_id = 123 
 
	SELECT *
	FROM parent AS p 
		JOIN child AS c ON p.parent_id = c.parent_id 
	WHERE p.parent_id BETWEEN 1 AND 100
SET STATISTICS IO OFF;



--
-- Compares execution plan costs
--
-- Creates the index again
CREATE NONCLUSTERED INDEX idx_parent_id ON child (parent_id);
SELECT *
FROM parent AS p 
	JOIN child AS c ON p.parent_id = c.parent_id 
WHERE p.parent_id = 123 
-- Drops the index
DROP INDEX IF EXISTS idx_parent_id ON child;
SELECT *
FROM parent AS p 
	JOIN child AS c ON p.parent_id = c.parent_id 
WHERE p.parent_id = 123 



-- Drops both tables
DROP TABLE IF EXISTS dbo.child;
DROP TABLE IF EXISTS dbo.parent;


----------------------------------------------------------------------------------
-- Updates the schema migration history table
----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (3, 'Foreign key');