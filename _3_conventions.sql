
----------------------------------------------------------------------------
-- Naming conventions
----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Table names					: singular snake_case
--								: product
--								 (common prefixes: tbl_, tb_, dim_, fact_)
----------------------------------------------------------------------------
-- Column names					: singular snake_case
--								: product_description
----------------------------------------------------------------------------
-- Singular primary key name	: [Table Name]_id
--								: product_id
----------------------------------------------------------------------------
-- Primary key constraint		: pk_[Table Name]
--								: pk_product
----------------------------------------------------------------------------
-- Foreign key constraint		: fk_[Source Table Name]_[Target Table Name]
--								: fk_product_product_category
--								  (other common prefixes: ref_ )
----------------------------------------------------------------------------
-- Index						: ix_[Table Name]_[Column Names]
--								: ix_order_event_time_status
--								  (other: idx_ )
----------------------------------------------------------------------------
-- Index with included columns	: ix_[Table Name]_[Column Names]_including_[Included Column Names]
-- 								: ix_order_customer_id_including_order_id_status
----------------------------------------------------------------------------
-- Filtered index				: ix_[Table Name]_[Column Names]_filtered
--								: ix_order_shipment_is_complete_filtered
----------------------------------------------------------------------------
-- Check constraint				: chk_[Table Name]_[Constraint Description]
--								: chk_promotion_discount_percent_between_0_and_100
----------------------------------------------------------------------------
-- Default constraint			: df_[Table Name]_[Constraint Description]
--								: df_order_shipment_is_complete_0
--								  (other: def_ )
----------------------------------------------------------------------------
-- Trigger Name					: on_[After | Instead]_[Table Name]_[Inserted]_[Updated]_[Deleted]
--								: on_after_order_inserted_updated
--								  (other: trg_, tr_)
----------------------------------------------------------------------------
-- View Name					: [View description]_view
--								: top_category_per_customer_view
--								  (other: vw_  )
----------------------------------------------------------------------------
-- Stored procedure				: [A verb describing the operation]
--								: get_customer_credit_card
--								  (other: sp_, usp_ )

-- SQL code
IF OBJECT_ID('dbo.migration_history', 'U') IS NULL
BEGIN
	PRINT 'Creating a migration_history table in dbo schema.'
	CREATE TABLE dbo.migration_history(
		migration_history_id	INT				NOT NULL,
		[description]			VARCHAR(500)	NOT NULL,
		CONSTRAINT pk_migration_history PRIMARY KEY (migration_history_id)
	);
END
ELSE
BEGIN
	PRINT 'The table migration_history exists.' 
END;
