-----------------------------------------------------------------------------------
-- Script 022                                                                 
--       
-- COMPUTED COLUMN                 
--       
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-- Adds number_of_reviews and sum_of_ratings fields to the product table
-- The fields will be updated by a trigger
ALTER TABLE production.product ADD number_of_reviews INT NOT NULL 
	CONSTRAINT df_product_number_of_reviews_0 DEFAULT 0;

ALTER TABLE production.product ADD sum_of_ratings INT NOT NULL
	CONSTRAINT df_product_sum_of_ratings_0 DEFAULT 0;
GO


-- Adds a calculated column average_rating and index on it 
ALTER TABLE production.product ADD average_rating 
AS 
	ROUND(CAST(sum_of_ratings AS FLOAT) / NULLIF(CAST(number_of_reviews AS FLOAT), 0), 2) PERSISTED;

CREATE INDEX ix_product_average_rating ON production.product(average_rating DESC);
GO


-- Data Migration
-- Calculates the number_of_reviews and sum_of_ratings for each product based
-- on the data in product_review table
UPDATE production.product
	SET number_of_reviews = pr.number_of_reviews,
		sum_of_ratings = pr.sum_of_ratings
FROM
(
	SELECT 
		pr.product_id, 
		COUNT(*) AS 'number_of_reviews', 
		SUM(CAST(JSON_VALUE(pr.content, '$.rating') AS INT)) AS 'sum_of_ratings'
	FROM production.product_review pr
		JOIN production.product p ON p.product_id = pr.product_id
	GROUP BY pr.product_id
) pr
WHERE production.product.product_id = pr.product_id
GO

-- Displays a leaf level page of the ix_product_average_rating index
EXEC dbo.get_index_leaf_page_content 'ix_product_average_rating';
GO


-- A trigger that updates the 'number_of_reviews' and 'sum_of_ratings' columns 
-- in the 'production.product' table whenever a review is inserted, updated, or deleted.
CREATE OR ALTER TRIGGER production.on_after_product_review_inserted_updated_deleted 
	ON production.product_review AFTER INSERT, DELETE, UPDATE
AS
BEGIN
    -- Updates product ratings and review counts
    UPDATE production.product
    SET 
        number_of_reviews = number_of_reviews +
            ISNULL((SELECT COUNT(*) FROM INSERTED WHERE product_id = production.product.product_id), 0) -
            ISNULL((SELECT COUNT(*) FROM DELETED WHERE product_id = production.product.product_id), 0),
        sum_of_ratings = sum_of_ratings +
            ISNULL((SELECT SUM(CAST(JSON_VALUE(INSERTED.content, '$.rating') AS INT)) 
                    FROM INSERTED WHERE product_id = production.product.product_id), 0) -
            ISNULL((SELECT SUM(CAST(JSON_VALUE(DELETED.content, '$.rating') AS INT)) 
                    FROM DELETED WHERE product_id = production.product.product_id), 0)
    WHERE product_id IN (
        SELECT product_id FROM INSERTED
        UNION
        SELECT product_id FROM DELETED
    );
END
GO


-- Adds three reviews for a product with ID = PRD0016
DECLARE @max_review_id INT = COALESCE((SELECT MAX(pr.review_id) FROM production.product_review pr), 0);
INSERT INTO production.product_review(
	product_id, 
	review_id, 
	content
)
VALUES('PRD0016', @max_review_id + 1, '{"author_id": 1, "author_name": "Sam Bond", "rating": 5, "text": "Good Product",  "review_date": "2024-01-01T14:09:00", "images": [ "https://blob.storage/image/10011"]}'),
	  ('PRD0016', @max_review_id + 2, '{"author_id": 2, "author_name": "Sam Bond", "rating": 5, "text": "Great Product",  "review_date": "2024-01-01T12:09:00", "images": [ "https://blob.storage/image/10012"]}'),
	  ('PRD0016', @max_review_id + 3, '{"author_id": 3, "author_name": "Sam Bond", "rating": 5, "text": "OK",  "review_date": "2024-01-01T16:09:00", "images": [ "https://blob.storage/image/10013"]}');


-- This query retrieves the average_rating and product_id of products 
-- where the average rating is greater than 3.4.
SELECT 
	average_rating,
	product_id
FROM production.product
WHERE average_rating > 3.4;


-- This query retrieves product data
-- within the 'Cameras' category that have an average rating greater than 3.1
WITH camera_hierarchy AS (
    SELECT hierarchy
    FROM production.product_category
    WHERE name = 'Cameras'
)
SELECT 
    average_rating,
    p.product_id,
    pc.product_category_id,
	pc.path,
    pc.name
FROM production.product p
JOIN production.product_category pc 
    ON p.product_category_id = pc.product_category_id
JOIN camera_hierarchy ch
    ON pc.hierarchy.IsDescendantOf(ch.hierarchy) = 1
WHERE average_rating > 3.1
ORDER BY average_rating DESC;



-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (22, 'Computed column');


 
