-----------------------------------------------------------------------------------
-- Script 005                                                                 
--       
-- SPLITTING THE NAME COLUMN                      
--          
-- #1@Problem definition
-- #2  Scaffolding code
-- #3  Data migration
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-----------------------------------------------------------------------------------
-- #1  Problem definition
-----------------------------------------------------------------------------------

-- The SELECT query below breaks down the 'name' column by finding the space 
-- between the first and last names and uses the SUBSTRING function to extract 
-- both parts
SELECT  
	name,
	first_name = SUBSTRING(name, 0, CHARINDEX(' ', name, 1)),
	last_name  = SUBSTRING(name, CHARINDEX(' ',name) + 1, LEN(name)) 
FROM person.customer;
GO

-- Add new columns to hold the separated first name and last name
ALTER TABLE person.customer ADD first_name VARCHAR(100);
ALTER TABLE person.customer ADD last_name VARCHAR(100);
GO



-----------------------------------------------------------------------------------
-- #2  Scaffolding code
-----------------------------------------------------------------------------------

-- Trigger used to synchronize data during transition period
-- to support both old and new clients
CREATE OR ALTER TRIGGER person.on_instead_customer_inserted_updated
    ON person.customer
    INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Insert operation
        IF NOT EXISTS (SELECT 1 FROM DELETED)
        BEGIN
            INSERT INTO person.customer (
                customer_id, name, first_name, last_name, address, city, state, zip_code, phone, email, wishlist, description
            )
            SELECT
                customer_id,
				ISNULL(
					name, 
					CASE 
						WHEN (first_name IS NOT NULL) AND (last_name IS NOT NULL) 
							THEN first_name + ' ' + last_name
						ELSE NULL
					END
				) AS name,
                ISNULL(first_name, LEFT(name, CHARINDEX(' ', name) - 1)) AS first_name,
                ISNULL(last_name, LTRIM(RIGHT(name, LEN(name) - CHARINDEX(' ', name + ' ')))) AS last_name,
                address,
                city,
                state,
                zip_code,
                phone,
                email,
                wishlist,
                description
            FROM INSERTED;
        END
        ELSE
        BEGIN
            -- Update operation
            UPDATE c
            SET
                name = CASE 
                    WHEN i.name != d.name THEN i.name
					WHEN (i.first_name IS NULL) AND (i.last_name IS NULL) THEN NULL
                    ELSE i.first_name + ' ' + i.last_name
                END,
                first_name = CASE 
                    WHEN i.first_name != d.first_name THEN i.first_name
                    WHEN i.name IS NULL THEN NULL
                    ELSE LEFT(i.name, CHARINDEX(' ', i.name) - 1)
                END,
                last_name = CASE 
                    WHEN i.last_name != d.last_name THEN i.last_name
					WHEN i.name IS NULL THEN NULL
                    ELSE LTRIM(RIGHT(i.name, LEN(i.name) - CHARINDEX(' ', i.name)))
                END,
                c.address = i.address,
                c.city = i.city,
                c.state = i.state,
                c.zip_code = i.zip_code,
                c.phone = i.phone, 
                c.email = i.email,
                c.wishlist = i.wishlist,
                c.description = i.description
            FROM person.customer AS c
            INNER JOIN INSERTED AS i ON c.customer_id = i.customer_id
            INNER JOIN DELETED AS d ON c.customer_id = d.customer_id;
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO


-- Old client: Inserts name 
SET IDENTITY_INSERT person.customer ON; 
    DECLARE @old_customer_id INT = 20001;
    DECLARE @old_name NVARCHAR(100) = 'FirstName1 LastName1';
    DECLARE @old_address NVARCHAR(100) = '1234 Maple Lane';
    DECLARE @old_city NVARCHAR(50) = 'Chicago';
    DECLARE @old_state NVARCHAR(50) = 'IL';
    DECLARE @old_zip_code NVARCHAR(10) = '91405';
    DECLARE @old_phone NVARCHAR(15) = '(505)-569-0957';
    DECLARE @old_email NVARCHAR(100) = 'oliver.sanderson@mail.com';

    INSERT INTO person.customer (customer_id, name, address, city, state, zip_code, phone, email) 
        VALUES (@old_customer_id, @old_name, @old_address, @old_city, @old_state, @old_zip_code, @old_phone, @old_email);
    SELECT * FROM person.customer WHERE customer_id = @old_customer_id;
SET IDENTITY_INSERT person.customer OFF; 
GO

-- New client: Inserts first_name and last_name
SET IDENTITY_INSERT person.customer ON; 
    DECLARE @new_customer_id INT = 20002;
    DECLARE @new_first_name NVARCHAR(50) = 'FirstName2';
    DECLARE @new_last_name NVARCHAR(50) = 'LastName2';
    DECLARE @new_address NVARCHAR(100) = '1234 Maple Lane';
    DECLARE @new_city NVARCHAR(50) = 'Chicago';
    DECLARE @new_state NVARCHAR(50) = 'IL';
    DECLARE @new_zip_code NVARCHAR(10) = '91405';
    DECLARE @new_phone NVARCHAR(15) = '(505)-569-0957';
    DECLARE @new_email NVARCHAR(100) = 'oliver.sanderson@mail.com';

    INSERT INTO person.customer (customer_id, first_name, last_name, address, city, state, zip_code, phone, email) 
        VALUES (@new_customer_id, @new_first_name, @new_last_name, @new_address, @new_city, @new_state, @new_zip_code, @new_phone, @new_email);
    SELECT * FROM person.customer WHERE customer_id = @new_customer_id;
SET IDENTITY_INSERT person.customer OFF; 
GO

-- Old client: Updates name
DECLARE @old_customer_id INT = 20001;
DECLARE @updated_old_name NVARCHAR(100) = 'FirstName3 LastName3';

SELECT 'BEFORE: ', * FROM person.customer WHERE customer_id = @old_customer_id;
UPDATE person.customer 
SET name = @updated_old_name
WHERE customer_id = @old_customer_id;
SELECT 'AFTER: ', * FROM person.customer WHERE customer_id = @old_customer_id;



-- New client: Updates first_name and last_name
DECLARE @new_customer_id INT = 20002;
DECLARE @updated_new_first_name NVARCHAR(50) = 'FirstName4';
DECLARE @updated_new_last_name NVARCHAR(50) = 'LastName4';

SELECT 'BEFORE: ', * FROM person.customer WHERE customer_id = 20002;
UPDATE person.customer 
    SET first_name = @updated_new_first_name,
        last_name = @updated_new_last_name
WHERE customer.customer_id = @new_customer_id;
SELECT 'AFTER: ', * FROM person.customer WHERE customer_id = @new_customer_id;


-- Deletes 20001, 20002 customers
DELETE FROM person.customer WHERE customer_id IN (20001, 20002);


-- After the transition period the trigger can be deleted
DROP TRIGGER IF EXISTS person.on_instead_customer_inserted_updated;



-----------------------------------------------------------------------------------
-- #3  Data migration
-----------------------------------------------------------------------------------
-- Data migration in one go (only recommended for very small datasets)
UPDATE person.customer 
	SET first_name = SUBSTRING(name, 0, CHARINDEX(' ', name, 1)),
		last_name  = SUBSTRING(name, CHARINDEX(' ',name) + 1, LEN(name));
GO

-- Data migration in batches (recommended)
-- Deleting or updating more than 4000 rows at the same time 
-- may result in exclusive lock on the table
-- it is advisable to run statements in batches
DECLARE @batchId INT;
DECLARE @batchSize INT;
DECLARE @rows_affected INT;

SET @rows_affected= 1;
SET @batchSize = 100;
SET @batchId = (SELECT MIN(customer_id) FROM person.customer);

IF @batchId IS NULL RETURN;

WHILE (@rows_affected > 0)
BEGIN
	BEGIN TRAN;

	UPDATE person.customer 
	SET first_name = SUBSTRING(name, 0, CHARINDEX(' ', name)),
		last_name  = SUBSTRING(name, CHARINDEX(' ', name) + 1, LEN(name)) 
	WHERE (person.customer.customer_id >= @batchId
		AND person.customer.customer_id < @batchId + @batchSize);

	SET @rows_affected = @@ROWCOUNT;
	SET @batchId = @batchId + @batchSize;

	COMMIT TRAN;
END
	

ALTER TABLE person.customer DROP COLUMN name;
ALTER TABLE person.customer ALTER COLUMN first_name VARCHAR(100) NOT NULL;
ALTER TABLE person.customer ALTER COLUMN last_name  VARCHAR(100) NOT NULL;
GO

-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
 INSERT INTO dbo.migration_history(migration_history_id, description) 
	VALUES (5, 'Splitting the name column');
