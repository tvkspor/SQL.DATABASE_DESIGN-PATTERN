-----------------------------------------------------------------------------------
-- Script 016                                                                 
--       
-- MODELING HIERARCHICAL DATA                   
--       
-- #1  Migration from adjacency list
-- #2  HierarchyID methods
-- #3  Path Enumeration vs HierarchyID
-- #4  HierarchyID Indexes
--
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-----------------------------------------------------------------------------------
-- #1  Migration from adjacency list
-----------------------------------------------------------------------------------

-- Adds path and hierarchy fields to store product category hierarchy
ALTER TABLE production.product_category ADD path VARCHAR(500);
ALTER TABLE production.product_category ADD hierarchy hierarchyid;
GO

-- Extracts the product category hierarchy and saves it into the path field
WITH path_cte AS
(
	SELECT 
		product_category_id, 
		name, 
		CAST(product_category_id AS VARCHAR(500)) AS 'path'
	FROM production.product_category
	WHERE parent_category_id IS NULL

	UNION ALL

	SELECT pc.product_category_id, 
		pc.name, 
		CAST(CONCAT(cte.path, '|', pc.product_category_id) AS VARCHAR(500))
	FROM path_cte AS cte 
		JOIN production.product_category AS pc ON cte.product_category_id = pc.parent_category_id
	WHERE parent_category_id IS NOT NULL
)
UPDATE production.product_category
	SET product_category.path = path_cte.path
FROM path_cte
WHERE product_category.product_category_id = path_cte.product_category_id
GO


-- Extracts the product category tree and saves it into the hierarchy field
WITH product_category_row_number AS
(
  SELECT 
	(
		CASE 
			WHEN parent_category_id IS NULL THEN 0
			ELSE parent_category_id
		END
	) AS 'parent_category_id',
	product_category_id, 
	name,
	ROW_NUMBER() OVER
	(
		PARTITION BY parent_category_id 
		ORDER BY product_category_id
	) AS 'row_number'
  FROM production.product_category
), hierarchy_cte AS
(
	SELECT 
		0 as product_category_id, 
		name, 
		CAST('/' AS VARCHAR(500)) AS 'hierarchy'
	FROM production.product_category
	WHERE parent_category_id IS NULL

	UNION ALL

	SELECT pcrn.product_category_id, 
		pcrn.name, 
		CAST(hierarchy + CAST(pcrn.row_number AS VARCHAR(20)) + '/' AS VARCHAR(500))
	FROM hierarchy_cte AS cte 
		JOIN product_category_row_number AS pcrn ON cte.product_category_id = pcrn.parent_category_id
	WHERE parent_category_id IS NOT NULL
)
UPDATE production.product_category
	SET product_category.hierarchy = hierarchy_cte.hierarchy
FROM hierarchy_cte
WHERE product_category.product_category_id = hierarchy_cte.product_category_id
GO

-- The parent_category_id field and fk_parent_category constraint are no longer needed 
-- so it can be dropped
ALTER TABLE production.product_category DROP CONSTRAINT fk_product_category_self
ALTER TABLE production.product_category DROP COLUMN parent_category_id;


-----------------------------------------------------------------------------------
-- #2  HierarchyID methods
-----------------------------------------------------------------------------------

--
--  IsDescendantOf(node HIERARCHYID)
--  Retrieves ancestors of Headphones
--
SELECT 
	product_category_id,
	name,
	hierarchy.ToString() AS 'hierarchy'
FROM production.product_category pc
WHERE HIERARCHYID::Parse('/1/2/1/').IsDescendantOf(hierarchy) = 1;


--
--  IsDescendantOf(node HIERARCHYID)
--  Retrieves descendants of Headphones
--
SELECT 
	product_category_id,
	name,
	hierarchy.ToString() AS 'hierarchy'
FROM production.product_category pc
WHERE hierarchy.IsDescendantOf(HIERARCHYID::Parse('/1/2/1/')) = 1;


--
--  GetAncestor(level INT)
--  Returns the parent of Headphones
--
SELECT 
	product_category_id, 
	name, 
	hierarchy.ToString() AS 'hierarchy' 
FROM production.product_category 
WHERE hierarchy.ToString() LIKE '/1/2/%' ORDER BY hierarchy 

SELECT 
	product_category_id,
	name,
	hierarchy.ToString() AS 'target_node',
	hierarchy.GetAncestor(1).ToString() AS 'parent_node'
FROM production.product_category
WHERE hierarchy = (HIERARCHYID::Parse('/1/2/1/'));


--
--  GetDescendant(child_1, child_2) 
--  Generates a new descendant of Headphones
--
SELECT 
	product_category_id, 
	name, 
	hierarchy.ToString() AS 'hierarchy' 
FROM production.product_category 
WHERE hierarchy.ToString() LIKE '/1/2/1/%' ORDER BY hierarchy;

SELECT 
	product_category_id,
	name,
	hierarchy.ToString() AS 'target_node',
	hierarchy.GetDescendant('/1/2/1/3/', NULL).ToString() AS 'new_descendant'
FROM production.product_category
WHERE hierarchy = (HIERARCHYID::Parse('/1/2/1/'));


--
--  GetLevel()
--
SELECT HIERARCHYID::Parse('/1/2/1/').GetLevel(); 


--
--  ToString()
--
SELECT HIERARCHYID::Parse('/1/2/1/');
SELECT HIERARCHYID::Parse('/1/2/1/').ToString();

--
--  GetRoot()
--
SELECT HIERARCHYID::GetRoot();


-----------------------------------------------------------------------------------
-- #3  Path Enumeration vs HierarchyID
-----------------------------------------------------------------------------------

--
-- Retrieving subcategories (descendants) of Cameras
--
DECLARE @camera_descendants_path AS VARCHAR(500) 
	= (SELECT path FROM production.product_category WHERE name = 'Cameras')
DECLARE @camera_descendants_hierarchy AS HIERARCHYID 
	= (SELECT hierarchy FROM production.product_category WHERE name = 'Cameras')

SELECT 
	product_category_id,
	name,
	path,
	hierarchy.ToString() AS 'hierarchy'
FROM production.product_category
WHERE path LIKE @camera_descendants_path + '%'  

SELECT 
	product_category_id,
	name,
	path,
	hierarchy.ToString() AS 'hierarchy'
FROM production.product_category pc
WHERE pc.hierarchy.IsDescendantOf(@camera_descendants_hierarchy) = 1;


--
-- Retrieving parent categories (ancestors) of Gaming Tablets
--
DECLARE @gaming_tablets_ancestors_path AS VARCHAR(500) 
	= (SELECT path FROM production.product_category WHERE name = 'Gaming Tablets')
DECLARE @gaming_tablets_ancestors_hierarchy AS HIERARCHYID 
	= (SELECT hierarchy FROM production.product_category WHERE name = 'Gaming Tablets')

SELECT 
	product_category_id,
	name,
	path,
	hierarchy.ToString() AS 'hierarchy'
FROM production.product_category  pc
WHERE @gaming_tablets_ancestors_path LIKE pc.path + '%'
 
SELECT
	product_category_id,
	name,
	path,
	hierarchy.ToString() AS 'hierarchy'
FROM production.product_category pc
WHERE @gaming_tablets_ancestors_hierarchy.IsDescendantOf(hierarchy) = 1;


--
-- Moves the descendants of Headphones to Other Hardware Products (HierarchyID example)
--
BEGIN TRANSACTION

DECLARE @old_parent AS HIERARCHYID 
	= (SELECT hierarchy FROM production.product_category WHERE name = 'Headphones')
DECLARE @new_parent AS HIERARCHYID 
	= (SELECT hierarchy FROM production.product_category WHERE name = 'Other Hardware Products')

SELECT -- product_category before the move
	product_category_id,
	name, 
	hierarchy.ToString() AS 'hierarchy' 
FROM production.product_category
WHERE hierarchy.ToString() LIKE '/1/2/1/%' 
   OR hierarchy.ToString() LIKE '/1/6/%'
ORDER BY hierarchy 

UPDATE production.product_category
	SET hierarchy = hierarchy.GetReparentedValue(@old_parent, @new_parent)
WHERE hierarchy.IsDescendantOf(@old_parent) = 1
  AND hierarchy.ToString() != @old_parent;

SELECT -- product_category after the move 
	product_category_id,
	name, 
	hierarchy.ToString() AS 'hierarchy' 
FROM production.product_category
WHERE hierarchy.ToString() LIKE '/1/2/1/%' 
   OR hierarchy.ToString() LIKE '/1/6/%'
ORDER BY hierarchy 

ROLLBACK

--
-- Moves the descendants of Headphones to Other Hardware Products (Path Enumeration example)
--
BEGIN TRANSACTION

DECLARE @old_parent_path AS VARCHAR(500) 
	= (SELECT [path] FROM production.product_category WHERE name = 'Headphones')
DECLARE @new_parent_path AS VARCHAR(500) 
	= (SELECT [path] FROM production.product_category WHERE name = 'Other Hardware Products')

SELECT -- product_category before the movement
	product_category_id,
	name, 
	path
FROM production.product_category
WHERE hierarchy.ToString() LIKE '/1/2/1/%' 
   OR hierarchy.ToString() LIKE '/1/6/%'
ORDER BY hierarchy 

UPDATE production.product_category
	SET path = @new_parent_path + SUBSTRING(path, LEN(@old_parent_path) + 1, LEN(path)) 
WHERE path LIKE @old_parent_path + '%_' -- the underscore is needed in order not to overwrite the old_parent_path 

SELECT -- product_category after the movement 
	product_category_id,
	name, 
	path
 FROM production.product_category
WHERE hierarchy.ToString() LIKE '/1/2/1/%' 
   OR hierarchy.ToString() LIKE '/1/6/%'
ORDER BY path 

ROLLBACK

-----------------------------------------------------------------------------------
-- #4  HierarchyID Indexes (depth-first vs breadth-first)
-----------------------------------------------------------------------------------

-- Adds a hierarchy level field
ALTER TABLE production.product_category ADD level AS hierarchy.GetLevel();
GO

-- Adds a depth-first type of index
CREATE INDEX ix_product_category_hierarchy_depth_first ON production.product_category(hierarchy)
-- Adds a breadth-first type of index
CREATE INDEX ix_product_category_hierarchy_breadth_first ON production.product_category(level, hierarchy)
GO

-- Shows leaf nodes of the indexes
EXEC dbo.get_index_leaf_page_content 'ix_product_category_hierarchy_depth_first'
EXEC dbo.get_index_leaf_page_content 'ix_product_category_hierarchy_breadth_first'


 -- Query optimal for the depth-first index
SELECT
	product_category_id, 
	hierarchy.ToString() hierarchyPath
FROM production.product_category
WHERE hierarchy.IsDescendantOf('/1/1/') = 1
ORDER BY hierarchy
 -- Query optimal for the breadth-first index
SELECT
	product_category_id, 
	hierarchy.ToString() hierarchyPath
FROM production.product_category
WHERE hierarchy.GetAncestor(2) = '/1/1/'


-- HierarchyID preserves the sort order
BEGIN TRANSACTION
DECLARE @hierarchyString NVARCHAR(100) = '/1/18.5/';
DECLARE @hierarchyId HIERARCHYID;
SET @hierarchyId = HIERARCHYID::Parse(@hierarchyString);

INSERT production.product_category (name, [path], hierarchy) 
   VALUES ('Some New Category','1|46', @hierarchyId);  

SELECT product_category_id, hierarchy.ToString()
FROM production.product_category 
ORDER BY hierarchy.ToString()

SELECT product_category_id, hierarchy.ToString()
FROM production.product_category 
ORDER BY hierarchy 

ROLLBACK

-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (16, 'Modeling hierarchical data');