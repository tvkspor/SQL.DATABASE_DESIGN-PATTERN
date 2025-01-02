-----------------------------------------------------------------------------------
-- Script 023                                                                 
--       
-- SENSITIVE DATA OBFUSCATION                 
--
--  #1  Using stored procedures
--  #2  Using views
--  #3  Dynamic data masking
--  #4  Column level encryption
--
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-----------------------------------------------------------------------------------
-- #1  Using stored procedures
-----------------------------------------------------------------------------------

-- Creates a table to log all access attempts to sensitive credit card data
-- This table will track which user accessed the data, when, and the action taken
CREATE TABLE sales.credit_card_access_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    user_name NVARCHAR(100), -- Name of the user who accessed the data
    access_time DATETIME DEFAULT GETDATE(), -- Timestamp of access, defaulting to the current time
    accessed_customer_id INT, -- ID of the customer whose data was accessed
    action NVARCHAR(50)	-- The action taken (e.g., full view, masked view, unauthorized access)
);
GO


-- Creates two users without login credentials for different access levels
-- These users represent different roles with varying levels of access to credit card data
DROP USER IF EXISTS secure_user;
DROP USER IF EXISTS masked_user;
CREATE USER secure_user WITHOUT LOGIN;  -- Full access
CREATE USER masked_user WITHOUT LOGIN;  -- Masked access
GO


-- Creates a stored procedure to retrieve customer credit card information
-- The stored procedure grants different access levels based on the user role
CREATE OR ALTER PROCEDURE sales.get_customer_credit_card
    @customer_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
	    -- Validates the customer ID to ensure it exists
		IF NOT EXISTS (SELECT 1 FROM person.customer WHERE customer_id = @customer_id)
		BEGIN
			RAISERROR('Customer ID does not exist.', 16, 1);
			RETURN;
		END;
		-- Checks if the current user is 'secure_user' with full access
        IF USER_NAME() = 'secure_user'
        BEGIN
            SELECT 
                holder_name, 
				FORMAT(CAST(cc.credit_card_id AS BIGINT), '0000-0000-0000-0000') AS card_number,
                expiration_date
            FROM sales.credit_card cc
            WHERE customer_id = @customer_id;

            -- Logs the full access to the audit table
            INSERT INTO sales.credit_card_access_log (user_name, accessed_customer_id, action)
            VALUES (USER_NAME(), @customer_id, 'Viewed Full Credit Card Information');
        END
		-- Checks if the current user is 'masked_user' with masked access
        ELSE IF USER_NAME() = 'masked_user'
        BEGIN
            SELECT 
                holder_name, 
                STUFF(cc.credit_card_id, 1, 12, '****-****-****-') AS 'card_number', -- Mask first 12 digits
                expiration_date
            FROM sales.credit_card cc
            WHERE customer_id = @customer_id;

            -- Logs the masked access to the audit table
            INSERT INTO sales.credit_card_access_log (user_name, accessed_customer_id, action)
            VALUES (USER_NAME(), @customer_id, 'Viewed Masked Credit Card Information');
        END
        ELSE
        BEGIN
            -- If the user is neither authorized role, log the unauthorized access attempt and raise an error
			INSERT INTO sales.credit_card_access_log (user_name, accessed_customer_id, action)
            VALUES (USER_NAME(), @customer_id, 'Unauthorized access to Credit Card Information');
            RAISERROR('Access Denied: You are not authorized to view this data.', 16, 1);
        END
    END TRY
    BEGIN CATCH
		THROW;

    END CATCH;
END;
GO


-- Grants the 'EXECUTE' permission to both users for the stored procedure
-- This allows 'secure_user' and 'masked_user' to execute the stored procedure.
GRANT EXECUTE ON sales.get_customer_credit_card TO secure_user;
GRANT EXECUTE ON sales.get_customer_credit_card TO masked_user;
GO


-- Tests the stored procedure by impersonating the 'secure_user'
EXECUTE AS USER = 'secure_user';
DECLARE @customer_id INT = 50;
EXEC sales.get_customer_credit_card @customer_id;
REVERT;  -- Reverts back to the original user context

-- Tests the stored procedure by impersonating the 'masked_user'
EXECUTE AS USER = 'masked_user';
EXEC sales.get_customer_credit_card @customer_id;
REVERT;  -- Reverts back to the original user context
GO

-- Tests the stored procedure by impersonating an unauthorized user
BEGIN TRY
	EXEC sales.get_customer_credit_card 50;
END TRY
BEGIN CATCH
	PRINT ERROR_MESSAGE();
END CATCH;


-- Checks the access logs to verify that all access attempts have been logged correctly
SELECT * FROM sales.credit_card_access_log;
GO



-----------------------------------------------------------------------------------
-- #2  Using views
-----------------------------------------------------------------------------------
-- Creates a view to find each customer's top product category by total spending
-- The view provides key metrics including total spent, category count, and average spent per order
CREATE OR ALTER VIEW sales.customer_top_spending_category_view  
AS  
SELECT 
    customer_id,
	total_spent,
    category_count,
    name,
    total_orders,
    total_customer_spent,
    total_spent / NULLIF(total_orders, 0) AS avg_spent_per_order,
    (total_spent * 100.0 / NULLIF(total_customer_spent, 0)) AS percent_spent_in_top_category,
    most_recent_order_date
FROM 
(
    SELECT 
        c.customer_id,
        pc.name,
        COUNT(DISTINCT pc.product_category_id) AS category_count,
        SUM(oi.quantity * p.list_price) AS total_spent,
        COUNT(*) OVER (PARTITION BY c.customer_id) AS total_orders,
        SUM(SUM(oi.quantity * p.list_price)) OVER (PARTITION BY c.customer_id) AS total_customer_spent,
        MAX(o.order_date) AS most_recent_order_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY SUM(oi.quantity * p.list_price) DESC
        ) AS position
    FROM person.customer c
    JOIN sales.[order] o ON c.customer_id = o.customer_id
    JOIN sales.order_item oi ON o.order_id = oi.order_id
    JOIN production.product p ON oi.product_id = p.product_id
    JOIN production.product_category pc ON p.product_category_id = pc.product_category_id
    WHERE o.order_status_type_id = 
    (
		-- Only include orders that are 'CLOSED'
        SELECT order_status_type_id 
        FROM sales.order_status_type 
        WHERE name = 'CLOSED'
    )
    GROUP BY c.customer_id, pc.name
) AS customer_purchase
WHERE position = 1 -- Keep only the top spending product category for each customer
ORDER BY total_spent DESC, 
		 category_count DESC
OFFSET 0 ROWS;
GO

-- Retrieves all data from the customer top spending category view
SELECT * 
FROM sales.customer_top_spending_category_view;
GO


-- Creates a view that replaces the customer ID with a GUID (anonymized) 
-- and adds a customer tier based on total spending
CREATE OR ALTER VIEW sales.customer_top_spending_category_guid_view  
AS  
	SELECT 		
		NEWID() AS anonymized_customer_id, -- Anonymized customer ID
		name, -- Top product category
		total_spent, -- Total spending in the top category
		category_count, -- Number of categories customer purchased from
		total_orders, -- Total number of orders
		most_recent_order_date, -- Most recent order date
		CASE 
			WHEN total_spent > 5000 THEN 'platinum' -- Customer tier based on spending
			WHEN total_spent > 2000 THEN 'gold'
			ELSE 'silver'
		END AS customer_tier,
		CASE 
			WHEN DATEDIFF(YEAR, most_recent_order_date, GETDATE()) <= 1 THEN 'active' 
			ELSE 'inactive'
		END AS customer_status, -- Marks whether the customer is active
		(
			SELECT SUM(oi.quantity * p.list_price)
			FROM sales.order_item oi
			JOIN sales.[order] o ON oi.order_id = o.order_id
			JOIN production.product p ON oi.product_id = p.product_id
			WHERE o.customer_id = c.customer_id AND YEAR(o.order_date) = YEAR(GETDATE()) - 1
		) AS last_year_spent, -- Total spending in the previous year
		(total_spent - COALESCE(
			(
				SELECT SUM(oi.quantity * p.list_price)
				FROM sales.order_item oi
				JOIN sales.[order] o ON oi.order_id = o.order_id
				JOIN production.product p ON oi.product_id = p.product_id
				WHERE o.customer_id = c.customer_id AND YEAR(o.order_date) = YEAR(GETDATE()) - 1
			), 0
		)) / NULLIF(
			(
				SELECT SUM(oi.quantity * p.list_price)
				FROM sales.order_item oi
				JOIN sales.[order] o ON oi.order_id = o.order_id
				JOIN production.product p ON oi.product_id = p.product_id
				WHERE o.customer_id = c.customer_id AND YEAR(o.order_date) = YEAR(GETDATE()) - 1
			), 0
		) * 100 AS spending_growth_rate -- Growth rate in spending from the previous year
	FROM sales.customer_top_spending_category_view c
	WHERE total_spent > 1000 AND category_count > 1;
GO

-- Retrieves all data from the anonymized customer view
SELECT * 
FROM sales.customer_top_spending_category_guid_view;
GO

-- Creates a view that removes the customer ID and focuses on the spending metrics.
-- Enhancing the view with monthly breakdown and percentile rank
CREATE OR ALTER VIEW sales.customer_top_spending_category_without_id_view  
AS  
	SELECT 		
		total_spent,
		category_count,
		name,
		total_orders,
		total_customer_spent,
		avg_spent_per_order,
		percent_spent_in_top_category,
		most_recent_order_date,
		DATEPART(MONTH, most_recent_order_date) AS last_order_month, -- Month of most recent order
		DATEPART(YEAR, most_recent_order_date) AS last_order_year, -- Year of most recent order
		(
			SELECT SUM(oi.quantity * p.list_price)
			FROM sales.order_item oi
			JOIN sales.[order] o ON oi.order_id = o.order_id
			JOIN production.product p ON oi.product_id = p.product_id
			WHERE o.customer_id = c.customer_id AND DATEPART(MONTH, o.order_date) = DATEPART(MONTH, GETDATE())
		) AS monthly_spending, -- Total spending in the current month
		NTILE(10) OVER (ORDER BY total_spent DESC) AS spending_percentile -- Spending rank across all customers
	FROM sales.customer_top_spending_category_view c;
GO


-- Retrieves all data from the view that excludes the customer ID
SELECT * 
FROM sales.customer_top_spending_category_without_id_view;
GO


-- Creates a view that hashes the customer ID
-- Only an admin user can view the actual customer ID; others will see 'restricted'
CREATE OR ALTER VIEW sales.customer_top_spending_category_hashed_id_view
AS  
	SELECT
	    CASE 
			WHEN USER_NAME() = 'admin_user' THEN CONVERT(VARCHAR(50), customer_id) -- Show customer ID only for admin_user
			ELSE CONVERT(VARCHAR(50), HASHBYTES('SHA2_256', CONVERT(VARCHAR(50), customer_id)), 2) -- Hash customer ID for non-admin users
		END AS customer_id_or_hashed,
		total_spent,
		category_count,
		name,
		total_orders,
		total_customer_spent,
		avg_spent_per_order,
		percent_spent_in_top_category,
		most_recent_order_date
	FROM sales.customer_top_spending_category_view;
GO

-- Creates an admin user with full access to view the hashed customer ID
DROP USER IF EXISTS admin_user;
CREATE USER admin_user WITHOUT LOGIN;
GRANT SELECT ON sales.customer_top_spending_category_hashed_id_view TO admin_user;
EXECUTE AS USER = 'admin_user';
-- As 'admin_user', retrieves the data from the hashed ID view, showing actual customer IDs
SELECT * 
FROM sales.customer_top_spending_category_hashed_id_view;
REVERT;
-- As the original (non-admin) user, runs the same query again; this time customer IDs will be masked
SELECT * 
FROM sales.customer_top_spending_category_hashed_id_view;
GO



-----------------------------------------------------------------------------------
-- #3  Dynamic data masking
-----------------------------------------------------------------------------------
-- 
-- Dynamic masking
-- 
BEGIN TRY
    BEGIN TRANSACTION;

    -- Altering columns to add masking
    ALTER TABLE person.customer ALTER COLUMN last_name ADD MASKED WITH (FUNCTION = 'partial(1,"...",0)');
    ALTER TABLE person.customer ALTER COLUMN address ADD MASKED WITH (FUNCTION = 'default()');
    ALTER TABLE person.customer ALTER COLUMN city ADD MASKED WITH (FUNCTION = 'default()');
    ALTER TABLE person.customer ALTER COLUMN zip_code ADD MASKED WITH (FUNCTION = 'partial(3, "XX", 0)');
    ALTER TABLE person.customer ALTER COLUMN phone ADD MASKED WITH (FUNCTION = 'partial(0,"xxx-xxx-",4)');
    ALTER TABLE person.customer ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');

	-- Creating a user with unmasked access
	DROP USER IF EXISTS admin_user;
	CREATE USER admin_user WITHOUT LOGIN;
	GRANT SELECT ON person.customer TO admin_user;
	-- Creating a user with masked access
	DROP USER IF EXISTS masked_user;
    CREATE USER masked_user WITHOUT LOGIN;
    GRANT SELECT ON person.customer TO masked_user;

	-- Allowing admin_user to bypass masking
	GRANT UNMASK TO admin_user;
		
	-- Executes as admin_user (unmasked view)
	EXECUTE AS USER = 'admin_user';
	SELECT * FROM person.customer;
	REVERT;

	-- Executes as masked_user (masked view)
	EXECUTE AS USER = 'masked_user';
	SELECT * FROM person.customer;
	REVERT;

	-- Rollbacks to undo changes
    ROLLBACK;
END TRY
BEGIN CATCH
    -- Handles the error
    PRINT 'Error occurred: ' + ERROR_MESSAGE();

    IF @@TRANCOUNT > 0
        ROLLBACK; -- Rollbacks if an error occurs

END CATCH;


-----------------------------------------------------------------------------------
-- #4  Column level encryption
-----------------------------------------------------------------------------------
-- Checks if the database master key (DMK) exists; if not, creates it
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MasterKeyPassword';
END;

-- Creates a new certificate for encrypting credit card data
CREATE CERTIFICATE credit_card_certificate
	WITH SUBJECT = 'Customer credit card numbers';   

-- Creates a symmetric key for encrypting credit card information using AES 256-bit encryption
CREATE SYMMETRIC KEY credit_card_key  
	WITH ALGORITHM = AES_256  
	ENCRYPTION BY CERTIFICATE credit_card_certificate;  


-- Adds a new column to the credit_card table to store the encrypted credit card IDs
ALTER TABLE sales.credit_card  
    ADD credit_card_id_encrypted VARBINARY(128);   
GO  


-- Opens the symmetric key for encryption using the associated certificate for decryption
OPEN SYMMETRIC KEY credit_card_key
   DECRYPTION BY CERTIFICATE credit_card_certificate;

-- Encrypts the credit card ID using the symmetric key 
-- and updates the new column with the encrypted value
UPDATE sales.credit_card
SET credit_card_id_encrypted = EncryptByKey(
    Key_GUID('credit_card_key'), credit_card_id);  
GO

-- Closes the symmetric key after completing the encryption process to secure it
CLOSE SYMMETRIC KEY credit_card_key;
GO


-- Creates a stored procedure to securely retrieve credit card information based on user role
CREATE OR ALTER PROCEDURE sales.get_credit_card_info
AS
BEGIN
    -- Checks if the calling user is a member of the 'db_owner' role for access control
    IF IS_MEMBER('db_owner') = 1
    BEGIN
	    -- Opens the symmetric key for decryption
		OPEN SYMMETRIC KEY credit_card_key
		DECRYPTION BY CERTIFICATE credit_card_certificate;

        -- For admin users: Show full credit card number
        SELECT 
			customer_id,
            credit_card_id AS 'credit_card_id_RAW', 
			CONVERT(VARCHAR, DecryptByKey(credit_card_id_encrypted)) AS 'credit_card_id_DECRYPTED',
            holder_name, 
            expiration_date
        FROM sales.credit_card;
		
		-- Closes the symmetric key after use
		CLOSE SYMMETRIC KEY credit_card_key;
    END
    ELSE
    BEGIN
        -- For regular users: Retrieve masked credit card information
        SELECT 
			customer_id,
            credit_card_id AS 'credit_card_id_RAW', 
			credit_card_id_encrypted  AS 'credit_card_id_ENCRYPTED',
            holder_name, 
            expiration_date
        FROM sales.credit_card;
    END
END
GO


-- Executes the stored procedure as a db_owner
EXEC sales.get_credit_card_info;

-- Creates a test user (normal_user) 
DROP USER IF EXISTS normal_user;
CREATE USER normal_user WITHOUT LOGIN;
GRANT EXECUTE ON sales.get_credit_card_info TO normal_user;
EXECUTE AS USER = 'normal_user';
-- Executes the stored procedure as the normal_user to verify access
EXEC sales.get_credit_card_info;
REVERT;


-- Cleanup
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'credit_card_key')
BEGIN
    DROP SYMMETRIC KEY credit_card_key;
END;

IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'credit_card_certificate')
BEGIN
    DROP CERTIFICATE credit_card_certificate;
END;

DROP USER IF EXISTS normal_user;



-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (23, 'Sensitive data obfuscation');
