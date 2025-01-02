--------------------------------------------------------
-- Creates an OnlineStore database
--------------------------------------------------------
IF NOT EXISTS(SELECT * FROM sys.databases WHERE name = 'OnlineStore')
	BEGIN
		CREATE DATABASE OnlineStore;
	END
GO
USE OnlineStore;
GO


--------------------------------------------------------
-- Creates schemas
--------------------------------------------------------
CREATE SCHEMA person;
GO
CREATE SCHEMA sales;
GO
CREATE SCHEMA production;
GO

--------------------------------------------------------
-- Creates tables
--------------------------------------------------------
CREATE TABLE person.customer(
	customer_id		INT				NOT NULL IDENTITY (1, 1),
	name			VARCHAR (100)	NOT NULL,
	address			VARCHAR (255)	NOT NULL,
	city			VARCHAR (50)	NOT NULL,
	state			VARCHAR (2)		NOT NULL,
	zip_code		VARCHAR (5)		NOT NULL,
	phone			VARCHAR (25)	NULL,
	email			VARCHAR (100)	NOT NULL,
	wishlist		VARCHAR (255)	NULL,
	credit_card_id	VARCHAR (30)	NOT NULL,
	expiration_date	VARCHAR (5)		NOT NULL,
	holder_name		VARCHAR (50)	NOT NULL,
	[description]	VARCHAR (2000)	NULL,
	CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);

CREATE TABLE production.product_category(
	product_category_id	INT				NOT NULL IDENTITY (1, 1),
	name				VARCHAR (50)	NOT NULL,
	parent_category_id	INT				NULL,
	CONSTRAINT pk_product_category PRIMARY KEY (product_category_id),
	CONSTRAINT fk_product_category_self 
		FOREIGN KEY (parent_category_id) 
		REFERENCES production.product_category(product_category_id)
);

CREATE TABLE production.product(
	product_id			INT				NOT NULL IDENTITY (1, 1),
	product_number		VARCHAR (7)		NOT NULL,
	name				VARCHAR (255)	NOT NULL,
	vendor_name			VARCHAR (255)	NOT NULL,
	compatible_os		VARCHAR (50)	NULL,
	required_disk_space	FLOAT			NULL,
	required_ram		FLOAT			NULL,
	weight				FLOAT			NULL,
	height				FLOAT			NULL,
	width				FLOAT			NULL,
	length				FLOAT			NULL,
	product_category_id	INT				NOT NULL,
	list_price			DECIMAL (10, 2) NOT NULL,
	CONSTRAINT pk_product PRIMARY KEY (product_id),
	CONSTRAINT fk_product_product_category FOREIGN KEY (product_category_id) 
		REFERENCES production.product_category (product_category_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION
);

CREATE TABLE sales.[order](
	order_id			INT				NOT NULL IDENTITY (1, 1),
	customer_id			INT				NOT NULL,
	status				VARCHAR (50)	NOT NULL,
	order_date			DATETIME		NOT NULL,
	CONSTRAINT pk_order PRIMARY KEY (order_id),
	CONSTRAINT fk_order_customer FOREIGN KEY(customer_id) 
		REFERENCES person.customer (customer_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION
);

CREATE TABLE sales.order_item(
	order_id		INT NOT NULL,
	item_id			INT NOT NULL,
	product_id		INT NOT NULL,
	quantity		INT NOT NULL,
	CONSTRAINT pk_order_item PRIMARY KEY (order_id, item_id),
	CONSTRAINT fk_order_item_order FOREIGN KEY (order_id)
		REFERENCES sales.[order] (order_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION,
	CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE NO ACTION 
		ON UPDATE NO ACTION
);

CREATE TABLE sales.order_shipment(
	order_shipment_id	INT				NOT NULL IDENTITY (1, 1),
	order_id			INT				NOT NULL,
	created_at			DATETIME		NOT NULL,
	price				DECIMAL (10, 2) NOT NULL,
	CONSTRAINT pk_order_shipment PRIMARY KEY (order_shipment_id),
	CONSTRAINT fk_order_shipment_order FOREIGN KEY(order_id)
		REFERENCES sales.[order] (order_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION
);

CREATE TABLE production.review(
	product_id		INT				NOT NULL,
	author_id		INT				NOT NULL,
	content			VARCHAR (4000)	NOT NULL,
	rating			INT				NOT NULL,
	review_date		DATETIME		NOT NULL,
	CONSTRAINT pk_review PRIMARY KEY (product_id, author_id),
	CONSTRAINT fk_review_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION,
	CONSTRAINT fk_review_customer FOREIGN KEY (author_id) 
		REFERENCES person.customer (customer_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION,
	CONSTRAINT chk_review_raiting_range CHECK(rating >= 0 and rating <= 5)
);

CREATE TABLE production.review_image(
	review_image_id		INT				NOT NULL IDENTITY (1, 1),
	product_id			INT				NOT NULL,
	author_id			INT				NOT NULL,
	image_url			VARCHAR(500)	NOT NULL,
	CONSTRAINT pk_review_image PRIMARY KEY (product_id, author_id, review_image_id),
	CONSTRAINT fk_review_image_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION,
	CONSTRAINT fk_review_image_customer FOREIGN KEY (author_id) 
		REFERENCES person.customer (customer_id) 
		ON DELETE CASCADE 
		ON UPDATE NO ACTION,
);

CREATE TABLE dbo.migration_history(
	migration_history_id	INT				NOT NULL,
	description				VARCHAR(500)	NOT NULL,
	CONSTRAINT pk_migration_history PRIMARY KEY (migration_history_id)
);
GO




--------------------------------------------------------
-- Creates stored procedures
--------------------------------------------------------
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------------
-- This procedure gets filegroup and row count
-- infromation for the passed tables
--------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.get_table_filegroup_row_count_info
(
    @tables NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON
	SELECT 
		o.name AS 'table_name', 
		i.name AS 'index_name',
		prv.value AS 'partition_range', 
		fg.name AS 'file_group_name', 
		p.partition_number, 
		p.rows AS 'number_of_rows',
		pf.name AS 'partitioning_function'
	FROM sys.partitions p
		INNER JOIN sys.indexes i ON p.object_id = i.object_id 
			   AND p.index_id = i.index_id
		INNER JOIN sys.objects o ON p.object_id = o.object_id
		INNER JOIN sys.partition_schemes ps ON ps.data_space_id = i.data_space_id
		INNER JOIN sys.partition_functions pf ON pf.function_id = ps.function_id
		INNER JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = ps.data_space_id 
			   AND dds.destination_id = p.partition_number
		INNER JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id 
		 LEFT JOIN sys.partition_range_values prv ON pf.function_id = prv.function_id 
			   AND p.partition_number = 
			   (
					CASE pf.boundary_value_on_right 
					WHEN 0 THEN prv.boundary_id 
						ELSE (prv.boundary_id + 1) 
					END
				)
	WHERE o.name IN (SELECT value FROM STRING_SPLIT(REPLACE(@tables, ' ', ''), ','))
	ORDER BY table_name, partition_number, file_group_name 
END
GO

--------------------------------------------------------
-- This procedure gets basic page information for
-- the passed indexes
--------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.get_index_basic_page_info
(
    @indexes VARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON
	SELECT 
		[name] AS 'index_name',
		CASE
			WHEN index_level = index_depth - 1 THEN 'root'
			WHEN index_level = 0 THEN 'leaf'
			ELSE CONCAT('intermediate_', index_level)
		END AS 'node',
		page_count,
		record_count,
		pstats.used_page_count,
		pstats.used_page_count * 8 AS 'index_size_in_kb',
		istats.alloc_unit_type_desc,
		ROUND(istats.avg_fragmentation_in_percent, 2) AS 'avg_fragmentation_in_percent',
		istats.fragment_count,
		ROUND(istats.avg_fragment_size_in_pages, 2) AS 'avg_fragment_size_in_pages',
		ROUND(istats.avg_page_space_used_in_percent, 2) AS 'avg_page_space_used_in_percent',
		istats.min_record_size_in_bytes,
		istats.max_record_size_in_bytes,
		istats.avg_record_size_in_bytes
	FROM sys.dm_db_index_physical_stats(db_id('OnlineStore'), object_id(''), NULL, NULL, N'DETAILED') istats
		JOIN sys.indexes i ON i.object_id = istats.object_id 
		 AND i.index_id = istats.index_id
		JOIN sys.dm_db_partition_stats AS pstats ON pstats.object_id = istats.object_id 
		 AND i.index_id = pstats.index_id
	WHERE name IN (SELECT value FROM STRING_SPLIT(REPLACE(@indexes, ' ', ''), ',')) 
	ORDER BY index_name, istats.index_level DESC
END
GO

--------------------------------------------------------
-- This procedure gets page content for the index passed
-- For the level = 1: the root page is returned
-- For the level = 0: a random leaf page is returned
--------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.get_index_page_content
(
    @index VARCHAR(MAX),
	@level VARCHAR(MAX) = 0
)
AS
BEGIN
    SET NOCOUNT ON	
	DECLARE @page AS INT = (
		SELECT TOP(1)
			allocated_page_page_id		
		FROM sys.dm_db_database_page_allocations(db_id(), object_id(''), NULL, NULL, N'DETAILED') dpa
			INNER JOIN sys.indexes i ON dpa.object_id = i.object_id
				   AND dpa.index_id = i.index_id
		WHERE page_type_desc IS NOT NULL
	      AND page_type_desc = 'INDEX_PAGE'
 		  AND i.name = @index
		  AND dpa.page_level = @level
		ORDER BY dpa.page_level DESC
	)
	DBCC PAGE(OnlineStore, 1, @page, 3) 
END
GO
-- Gets the root page content for the index passed
CREATE OR ALTER PROCEDURE dbo.get_index_root_page_content
(
    @index VARCHAR(MAX)
)
AS
BEGIN
    EXEC dbo.get_index_page_content @index, 1
END
GO
-- Gets a leaf page content for the index passed
CREATE OR ALTER PROCEDURE dbo.get_index_leaf_page_content
(
    @index VARCHAR(MAX)
)
AS
BEGIN
    EXEC dbo.get_index_page_content @index, 0
END
GO

-- Clears the cache
CREATE OR ALTER PROCEDURE dbo.clear_cache
AS
BEGIN
    CHECKPOINT; 
	DBCC DROPCLEANBUFFERS; 
END
GO

--------------------------------------------------------
-- This view retrieves missing indexes on foreign key columns
--------------------------------------------------------
CREATE OR ALTER VIEW dbo.missing_indexes_on_fk_view
AS
	SELECT
		fk.name AS 'foreign_key',
		OBJECT_SCHEMA_NAME(fk.parent_object_id) AS 'schema',
		OBJECT_NAME(fk.parent_object_id) AS 'table',
		COL_NAME(fk.parent_object_id, fkc.parent_column_id) AS 'column',
		OBJECT_NAME(fk.referenced_object_id) AS 'referenced_table',
		COL_NAME(fk.referenced_object_id, fkc.referenced_column_id) AS 'referenced_column'
	FROM sys.foreign_keys AS fk
		INNER JOIN sys.foreign_key_columns AS fkc ON fk.object_id = fkc.constraint_object_id
		LEFT JOIN sys.index_columns AS ic ON fkc.parent_object_id = ic.object_id 
				AND fkc.parent_column_id = ic.column_id
		LEFT JOIN sys.indexes AS i ON ic.index_id = i.index_id 
				AND ic.object_id = i.object_id
	WHERE i.index_id IS NULL
 
GO
--------------------------------------------------------
-- This view retrieves foreign keys constraint settings
--------------------------------------------------------
CREATE OR ALTER VIEW dbo.fk_settings_view
AS
	SELECT 
		fk.name AS 'foreign_key',
		OBJECT_NAME(fk.parent_object_id) AS 'table',
		COL_NAME(fk.parent_object_id, fkc.parent_column_id) AS 'column',
		OBJECT_NAME(fk.referenced_object_id) AS 'referenced_table',
		COL_NAME(fk.referenced_object_id, fkc.referenced_column_id) AS 'referenced_column',
		fk.delete_referential_action_desc AS 'on_delete_action',
		fk.update_referential_action_desc AS 'on_update_action'
	FROM 
		sys.foreign_keys AS fk
	INNER JOIN 
		sys.foreign_key_columns AS fkc ON fk.object_id = fkc.constraint_object_id
GO

--------------------------------------------------------
-- This stored procedure retrieves locks information
--------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.get_locks_info
    @session_id NVARCHAR(MAX) = NULL  -- Can be NULL or a comma-separated list of session IDs
AS
BEGIN
    -- Declares a table variable to store the parsed session IDs
    DECLARE @session_id_list TABLE (session_id INT);

    -- If @session_id is not NULL, parse the comma-separated list into the table
    IF @session_id IS NOT NULL
    BEGIN
        -- Split the session_id string and insert into the table variable
        INSERT INTO @session_id_list (session_id)
        SELECT TRIM(value) 
        FROM STRING_SPLIT(@session_id, ',') 
        WHERE TRIM(value) IS NOT NULL AND ISNUMERIC(TRIM(value)) = 1;
    END

    SELECT
        l.request_session_id,
        l.resource_type,
        CASE
            WHEN l.resource_type = 'OBJECT' THEN 
                o.name
            WHEN l.resource_type = 'PAGE' THEN 
                t.name
            WHEN l.resource_type = 'KEY' THEN 
                i.name
            ELSE ''
        END AS [object_name],
        l.resource_description,
        l.request_type,
        l.request_mode,
        l.request_status
    FROM sys.dm_tran_locks l
    LEFT JOIN sys.objects o ON l.resource_associated_entity_id = o.object_id 
            AND l.resource_database_id = DB_ID()
    LEFT JOIN sys.allocation_units au ON l.resource_associated_entity_id = au.container_id
    LEFT JOIN sys.partitions p ON au.container_id = p.hobt_id
    LEFT JOIN sys.tables t ON p.object_id = t.object_id
    LEFT JOIN sys.indexes i ON p.object_id = i.object_id 
    WHERE 
        (@session_id IS NULL OR l.request_session_id IN (SELECT session_id FROM @session_id_list))
    ORDER BY 
        CASE 
            WHEN l.resource_type = 'DATABASE' THEN 1
            WHEN l.resource_type = 'OBJECT' THEN 2
            WHEN l.resource_type = 'PAGE' THEN 3
            WHEN l.resource_type = 'KEY' THEN 4
            ELSE 5
        END,
        [object_name] DESC;
END
GO



--------------------------------------------------------
-- Updates the schema migration history table
--------------------------------------------------------
 INSERT INTO dbo.migration_history(migration_history_id, [description])
	VALUES (0, 'Initial schema creation');




