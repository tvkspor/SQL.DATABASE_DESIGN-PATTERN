---------------------------------------------------------------------------------
-- Script 006                                                                 
--       
-- SIMPLE FORMAT                     
--                                                                               
---------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Removes non-numeric characters from customer's phone field
UPDATE person.customer
	SET phone = TRIM(
					REPLACE(
						TRANSLATE(phone, x, REPLICATE('*', LEN(x))),
						'*', 
						''
					)
				)
FROM person.customer 
CROSS APPLY (VALUES(' ABCDEFGHIJKLMNOPQRSTUVWXYZ/\+()-')) AS x(x);


-- Adds constraint to prevent insertion of non-numerical characters 
-- into the phone column in the future
ALTER TABLE person.customer 
	ADD CONSTRAINT chk_customer_phone_contains_only_numbers 
	CHECK (phone NOT LIKE '%[^0-9]%' AND LEN(phone) = 10);


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
 INSERT INTO dbo.migration_history(migration_history_id, description) 
	VALUES (6, 'Simple format');
