-----------------------------------------------------------------------------------
-- Script 021                                                                 
--       
-- DENORMALIZATION WITH JSON          
--     
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Query to retrieve reviews for product with ID 'PRD0001'
SELECT 
	CONCAT(c.first_name, ', ', c.last_name) AS customer_name,
    r.content AS review_content,
    r.rating AS review_rating,
    r.review_date AS review_date,
    STRING_AGG(ri.image_url, ', ') AS review_image_urls
FROM production.review r
	INNER JOIN person.customer c ON r.author_id = c.customer_id
	LEFT JOIN production.review_image ri ON r.product_id = ri.product_id 
		  AND r.author_id = ri.author_id
WHERE r.product_id = 'PRD0001'
GROUP BY c.first_name, c.last_name, r.content, r.rating, r.review_date
ORDER BY review_date;


-- Creates product_review table to store product's reviews, rating, images, etc,.
CREATE TABLE production.product_review (
	product_id	VARCHAR(7)		NOT NULL,
	review_id	INT				NOT NULL,
	content		VARCHAR(4000)	NOT NULL,
	CONSTRAINT pk_product_review PRIMARY KEY (product_id, review_id),
	CONSTRAINT fk_product_review_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE,
	CONSTRAINT chk_product_review_content_is_formatted_as_json CHECK (ISJSON(content)=1)
);
GO


-- Migrates data from the review table to the product_review table
INSERT INTO production.product_review
SELECT
	t1.product_id, 
	ROW_NUMBER() OVER(ORDER BY review_date ASC) AS 'review_id',
	(
		SELECT 
			t1.author_id, 
			(
				SELECT 
					CONCAT(c.first_name, ' ', c.last_name)
				FROM person.customer c
				WHERE c.customer_id = t1.author_id
			) AS 'author_name', 
			t1.rating, 
			t1.content AS 'text',
			t1.review_date,
			JSON_QUERY
			(
				'["' +
				(
					SELECT 
						STRING_AGG(ci.image_url,'","')
					FROM production.review_image ci
					WHERE t2.product_id = ci.product_id 
					  AND t2.author_id = ci.author_id
				) + '"]'
			) AS 'images'
		FROM production.review AS t2 
		WHERE t1.product_id = t2.product_id 
		  AND t1.author_id = t2.author_id
		FOR JSON PATH, WITHOUT_ARRAY_WRAPPER 
	) AS 'content'
FROM production.review AS t1;
GO


-- Query to retrieve reviews for product with ID 'PRD0001', after the migration
SET STATISTICS IO ON;
SELECT 
	CONCAT(c.first_name, ', ', c.last_name) AS customer_name,
    r.content AS review_content,
    r.rating AS review_rating,
    r.review_date AS review_date,
    STRING_AGG(ri.image_url, ', ') AS review_image_urls
FROM production.review r
	INNER JOIN person.customer c ON r.author_id = c.customer_id
	LEFT JOIN production.review_image ri ON r.product_id = ri.product_id 
		  AND r.author_id = ri.author_id
WHERE r.product_id = 'PRD0001'
GROUP BY c.first_name, c.last_name, r.content, r.rating, r.review_date
ORDER BY review_date;

SELECT 
	author_name,
    text,
    rating,
    review_date,
    images
FROM production.product_review
	CROSS APPLY OPENJSON(content, '$') 
	WITH (   
		author_name		VARCHAR(255)  '$."author_name"',
		text			VARCHAR(4000) '$."text"',
		rating			TINYINT       '$."rating"',
		review_date		DATETIME      '$.review_date',
		images			NVARCHAR(MAX) '$.images' AS JSON
	) AS content
WHERE product_id = 'PRD0001';

-- After the migration period is over old table can be deleted
-- Drops the old review table
DROP TABLE production.review;
-- Drops the old review_image table
DROP TABLE production.review_image;
GO


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (21, 'Denormalization with json');