--------------------------------------------------------
-- This script drops all objects from the OnlineStore database
--------------------------------------------------------
USE OnlineStore;
GO


-- Drops stored procedures
DROP PROCEDURE IF EXISTS sales.get_credit_card_info;
DROP PROCEDURE IF EXISTS sales.get_customer_credit_card;
DROP PROCEDURE IF EXISTS dbo.clear_cache;
DROP PROCEDURE IF EXISTS dbo.get_index_basic_page_info;
DROP PROCEDURE IF EXISTS dbo.get_index_leaf_page_content;
DROP PROCEDURE IF EXISTS dbo.get_index_page_content;
DROP PROCEDURE IF EXISTS dbo.get_index_root_page_content;
DROP PROCEDURE IF EXISTS dbo.get_table_filegroup_row_count_info;
DROP PROCEDURE IF EXISTS update_customer_points;

-- Drops views
DROP VIEW IF EXISTS sales.top_category_per_customer_view
DROP VIEW IF EXISTS sales.top_category_per_customer_hashed_id_view
DROP VIEW IF EXISTS sales.top_category_per_customer_random_id_view;
DROP VIEW IF EXISTS sales.top_category_per_customer_without_id_view;
DROP VIEW IF EXISTS sales.customer_total_spent_per_product_view;
DROP VIEW IF EXISTS production.product_view;
DROP VIEW IF EXISTS dbo.fk_settings_view;
DROP VIEW IF EXISTS dbo.get_missing_indexes_on_fk_view;
DROP VIEW IF EXISTS dbo.missing_indexes_on_fk_view;
DROP VIEW IF EXISTS sales.customer_top_spending_category_guid_view;
DROP VIEW IF EXISTS sales.customer_top_spending_category_hashed_id_view;
DROP VIEW IF EXISTS sales.customer_top_spending_category_view;
DROP VIEW IF EXISTS sales.customer_top_spending_category_without_id_view;
DROP VIEW IF EXISTS sales.customer_total_spent_per_product_view_NORMAL;


-- Drop tables
IF OBJECT_ID(N'production.promotion_temporal', N'U') IS NOT NULL
BEGIN
	ALTER TABLE production.promotion_temporal  SET (SYSTEM_VERSIONING = OFF)
	DROP TABLE IF EXISTS production.promotion_temporal;
END
DROP TABLE IF EXISTS production.promotion_temporal_history;
DROP TABLE IF EXISTS production.review_image;
DROP TABLE IF EXISTS production.product_comment;
DROP TABLE IF EXISTS sales.customer_wishlist;
DROP TABLE IF EXISTS sales.credit_card;
DROP TABLE IF EXISTS sales.order_item_shipment;
DROP TABLE IF EXISTS sales.order_item;
DROP TABLE IF EXISTS sales.order_status_history;
DROP TABLE IF EXISTS sales.order_shipment;
DROP TABLE IF EXISTS sales.[order];
DROP TABLE IF EXISTS production.review;
DROP TABLE IF EXISTS person.customer_description;
DROP TABLE IF EXISTS person.customer;
DROP TABLE IF EXISTS person.[state];
DROP TABLE IF EXISTS sales.order_amount;
DROP TABLE IF EXISTS sales.order_item_quantity;
DROP TABLE IF EXISTS production.hardware_product;
DROP TABLE IF EXISTS production.software_product;
DROP TABLE IF EXISTS production.product_review;
DROP TABLE IF EXISTS production.promotion;
DROP TABLE IF EXISTS production.product_category_translation;
DROP TABLE IF EXISTS production.[language];
DROP TABLE IF EXISTS production.product;
DROP TABLE IF EXISTS production.product_category;
DROP TABLE IF EXISTS sales.order_status_type;
DROP TABLE IF EXISTS production.vendor;
DROP TABLE IF EXISTS dbo.migration_history;
DROP TABLE IF EXISTS dbo.number;
DROP TABLE IF EXISTS dbo.calendar;
DROP TABLE IF EXISTS sales.non_workday_calendar;
DROP TABLE IF EXISTS sales.calendar;
DROP TABLE IF EXISTS sales.credit_card_access_log;
DROP TABLE IF EXISTS dbo.vert_part_FULL;
DROP TABLE IF EXISTS dbo.vert_part_PAR2;
DROP TABLE IF EXISTS dbo.vert_part_PAR1;
DROP TABLE IF EXISTS dbo.vert_part_INT;
DROP TABLE IF EXISTS dbo.vert_part_NEWSEQUENTIALID;
DROP TABLE IF EXISTS dbo.vert_part_GUID;
DROP TABLE IF EXISTS dbo.child;
DROP TABLE IF EXISTS dbo.parent;
DROP TABLE IF EXISTS dbo.multi_language;
DROP TABLE IF EXISTS dbo.varbinary_max_table;
DROP TABLE IF EXISTS dbo.filestream_table;
DROP TABLE IF EXISTS s02_scalar;
DROP TABLE IF EXISTS s02_new_order;
DROP TABLE IF EXISTS s02_group_by;
DROP TABLE IF EXISTS s02_count;
DROP TABLE IF EXISTS s02_identity;
DROP TABLE IF EXISTS skewed_table;
DROP TABLE IF EXISTS dbo.file_table;
DROP TABLE IF EXISTS customer_point_charge_event_history;
DROP TABLE IF EXISTS customer_point;
DROP TABLE IF EXISTS production.warehouse;
GO

DROP USER IF EXISTS normal_user;
DROP USER IF EXISTS masked_user;
DROP USER IF EXISTS admin_user;
DROP USER IF EXISTS secure_user;

-- Drops files, file groups and other objects
IF EXISTS (SELECT 1 FROM sys.database_files WHERE name = 'file_stream_data')
BEGIN TRY
	ALTER DATABASE OnlineStore REMOVE FILE file_stream_data; 
END TRY
BEGIN CATCH
    PRINT 'An error occurred: ' + ERROR_MESSAGE();  
END CATCH;
GO
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'file_stream_group')
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILEGROUP file_stream_group;  
END

DROP TABLE IF EXISTS sales.order_report;
DROP TABLE IF EXISTS sales.order_report_2020;
DROP TABLE IF EXISTS sales.order_report_2024;
DROP TABLE IF EXISTS sales.order_report_non_partitioned;
IF EXISTS(SELECT 1 FROM sys.partition_schemes WHERE name = 'order_time_partition_scheme') 
	DROP PARTITION SCHEME order_time_partition_scheme;
IF EXISTS(SELECT 1 FROM sys.partition_functions WHERE name = 'order_time_partition_function') 
	DROP PARTITION FUNCTION order_time_partition_function;

IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_old')
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE order_report_old_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_old;  
END
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2020')
BEGIN
 
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2020_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2020;  
END

IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2021') 
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2021_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2021;  
END

IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2022') 
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2022_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2022;  
END
 
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2023') 
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2023_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2023;  
END
 
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2024') 
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2024_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2024;  
END
GO

DROP TABLE IF EXISTS sales.order_report_bad_example;
DROP TABLE IF EXISTS sales.order_report_2020_bad_example;
IF EXISTS(SELECT 1 FROM sys.partition_schemes 
	WHERE name = 'order_time_partition_scheme_bad_example') 
DROP PARTITION SCHEME order_time_partition_scheme_bad_example;

IF EXISTS(SELECT 1 FROM sys.partition_functions 
	WHERE name = 'order_time_partition_function_bad_example') 
DROP PARTITION FUNCTION order_time_partition_function_bad_example;

IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2020_bad_example')
BEGIN
 
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2020_1_bad_example; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2020_bad_example;  
END

IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2021_bad_example')
BEGIN
 
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2021_1_bad_example; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2021_bad_example;  
END
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2022_bad_example')
BEGIN
 
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2022_1_bad_example; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2022_bad_example;  
END
IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'order_report_2023_bad_example')
BEGIN
 
	ALTER DATABASE OnlineStore REMOVE FILE order_report_2023_1_bad_example; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP order_report_2023_bad_example;  
END

IF EXISTS (SELECT 1 FROM sys.FileGroups WHERE name = 'vertical_partitioning')
BEGIN
	ALTER DATABASE OnlineStore REMOVE FILE vertical_partitioning_1; 
	ALTER DATABASE OnlineStore REMOVE FILEGROUP vertical_partitioning;  
END;


DROP TRIGGER IF EXISTS sales.on_after_order_inserted_updated;

-- Drops schemas
DROP SCHEMA IF EXISTS sales;
DROP SCHEMA IF EXISTS production;
DROP SCHEMA IF EXISTS person;