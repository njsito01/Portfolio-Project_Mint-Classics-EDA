
/* 

Looking to answer these questions:
1) Where are items stored and if they were rearranged, could a warehouse be eliminated?
2) How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?
3) Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

*/


/*
This section will be looking to get familiar with the 'orderdetails', 'orders', 'products', and 'warehouses' tables.
These tables house information regarding sales and inventory volumes, revenue and costs, as well as capacity of the difference warehouses
*/


-- orderdetails
SELECT *
FROM mintclassics.orderdetails
;

-- orders
SELECT *
FROM mintclassics.orders
;

-- products
SELECT *
FROM mintclassics.products
;

-- warehouses
SELECT *
FROM mintclassics.warehouses
;


/*
This next section will include some exploratory queries, gained at more general information, such as the date range of the dataset, inventory in stock, most
and least sold products, etc.
*/


-- Examining the date range of orders
SELECT
    MIN(orderDate) AS min_date,
    MAX(orderDate) AS max_date
FROM mintclassics.orders
ORDER BY orderDate
;


-- Examining total volumes of products in stock
SELECT
    productLine,
    productCode,
    productName,
    quantityInStock
FROM mintclassics.products
ORDER BY productLine, productCode
;

-- Looking to find the most and least ordered products

WITH quantities_ordered AS (
	SELECT
		pr.productLine AS product_line,
		pr.productName AS product_name,
		SUM(od.quantityOrdered) AS total_ordered,
        pr.quantityInStock AS quantity_in_stock,
		pr.warehouseCode AS warehouse_code
	FROM mintclassics.products AS pr
	LEFT JOIN mintclassics.orderdetails AS od 
		ON od.productCode = pr.productCode
	GROUP BY pr.productLine, pr.productName, pr.warehouseCode, pr.quantityInStock
	ORDER BY pr.warehouseCode, total_ordered DESC
)
SELECT
	warehouse_code,
	product_name,
    total_ordered,
    quantity_in_stock
FROM quantities_ordered
WHERE total_ordered IN (SELECT MAX(total_ordered) FROM quantities_ordered)
	OR total_ordered IN (SELECT MIN(total_ordered) FROM quantities_ordered)
;


-- Looking to display top 20 total products ordered, and which warehouse they were fulfilled out of
SELECT
	pr.productLine AS product_line,
    pr.productCode AS product_code,
	pr.productName AS product_name,
    pr.quantityInStock AS in_stock,
	SUM(od.quantityOrdered) AS total_ordered,
	pr.warehouseCode AS warehouse_code
FROM mintclassics.products AS pr
LEFT JOIN mintclassics.orderdetails AS od 
	ON od.productCode = pr.productCode
GROUP BY pr.productLine, pr.productCode, pr.productName, pr.warehouseCode, in_stock
ORDER BY total_ordered DESC
LIMIT 20
;

-- Looking to display bottom 20 total products ordered, and which warehouse they were fulfilled out of
SELECT
	pr.productLine AS product_line,
    pr.productCode AS product_code,
	pr.productName AS product_name,
    pr.quantityInStock AS in_stock,
	IFNULL(SUM(od.quantityOrdered), 0) AS total_ordered,
	pr.warehouseCode AS warehouse_code
FROM mintclassics.products AS pr
LEFT JOIN mintclassics.orderdetails AS od 
	ON od.productCode = pr.productCode
GROUP BY pr.productLine, pr.productCode, pr.productName, pr.warehouseCode, in_stock
ORDER BY total_ordered ASC
LIMIT 20
;

-- Which items are not ordered at all? 
-- Answer: Product Code S18_3233
SELECT
	pr.warehouseCode,
	pr.productCode,
    pr.productName,
    pr.quantityInStock,
    SUM(od.quantityOrdered) AS totalOrdered
FROM mintclassics.products AS pr
LEFT JOIN mintclassics.orderdetails AS od
	ON pr.productCode = od.productCode
WHERE od.quantityOrdered IS NULL
	OR od.quantityOrdered = 0
GROUP BY
	pr.warehouseCode,
	pr.productCode,
    pr.productName,
    pr.quantityInStock
;



/*
This section will focus on the warehouses, which items are stocked where, capacity, shipping times, etc.
*/


-- Looking at volumes of total products in stock at various warehouses
SELECT
    warehouseCode,
    productLine,
    SUM(quantityInStock) AS inStock    
FROM mintclassics.products
GROUP BY 
	warehouseCode,
    productLine
ORDER BY
	warehouseCode
;


-- Displaying the count of products fulfilled by each warehouse, by product line
SELECT
	pr.productLine,
    COUNT(DISTINCT pr.productCode) AS num_of_products,
    wh.warehouseCode
FROM mintclassics.orderdetails AS od
JOIN mintclassics.products AS pr
JOIN mintclassics.warehouses AS wh
	ON od.productCode = pr.productCode AND pr.warehouseCode = wh.warehouseCode
GROUP BY
	pr.productLine, wh.warehouseCode
ORDER BY
    wh.warehouseCode,
    num_of_products DESC
;


-- Looking at total storage capacity for each warehosue
WITH storage_spaces AS (
	SELECT
		wh.warehouseCode AS warehouseCode,
		SUM(pr.quantityInStock) AS qty_in_stock,
		wh.warehousePctCap AS warehousePctCap,
        -- Performing a simpilfied calculation to find the estimated total capacity of each warehouse
		ROUND(SUM(pr.quantityInStock) / (wh.warehousePctCap / 100), 0) AS est_total_capacity
	FROM mintclassics.warehouses AS wh
	JOIN mintclassics.products AS pr
		ON wh.warehouseCode = pr.warehouseCode
	GROUP BY
		wh.warehouseCode,
		wh.warehousePctCap
)
SELECT
	*,
    est_total_capacity - qty_in_stock AS est_open_spaces
FROM storage_spaces
;


-- Identifying any orders that should not be counted against shipping times
-- Longest first
SELECT 
	orderNumber,
	`status`,
    comments,
    orderDate,
    DATEDIFF(shippedDate, orderDate) AS fulfillment_time
FROM mintclassics.orders
ORDER BY fulfillment_time DESC
;

-- Shortest first
SELECT 
	orderNumber,
    `status`,
    comments,
    orderDate,
    DATEDIFF(shippedDate, orderDate) AS fulfillment_time
FROM mintclassics.orders
ORDER BY fulfillment_time
;

-- Don't count these order against shipping times, as they were either due to the customer, or near the end of the dataset's date range
SELECT 
	orderNumber,
    `status`,
    comments,
    orderDate,
    DATEDIFF(shippedDate, orderDate) AS fulfillment_time
FROM mintclassics.orders
WHERE orderNumber = 10165
	OR (`status` = 'In Process' AND orderDate >= 2005-05-20)
;

-- Looking at aggregated order-to-ship info for each warehouse
WITH shipment_info AS (
	SELECT
		pr.warehouseCode AS warehouseCode,
		os.orderNumber AS orderNumber,
		os.orderDate AS orderDate,
		os.shippedDate AS shippedDate
	FROM mintclassics.orders AS os
	JOIN mintclassics.orderdetails AS od
		ON os.orderNumber = od.orderNumber
	JOIN mintclassics.products AS pr
		ON od.productCode = pr.productCode
	WHERE os.shippedDate IS NOT NULL
		AND od.orderNumber <> 10165 -- This order was identified as an outlier due to customer payment issues, not fulfillment issues. See notes in the query above
)
SELECT
	warehouseCode,
    MIN(DATEDIFF(shippedDate, orderDate)) AS min_ship_days,
    MAX(DATEDIFF(shippedDate, orderDate)) AS max_ship_days,
	AVG(DATEDIFF(shippedDate, orderDate)) AS avg_ship_days
FROM shipment_info
GROUP BY
	warehouseCode
ORDER BY
	warehouseCode
;


-- Looking at total warehouse fulfillment volumes, by month
SELECT
	pr.warehouseCode,
    EXTRACT(YEAR FROM os.orderDate) AS order_year,
    EXTRACT(MONTH FROM os.orderDate) AS order_month,
    SUM(od.quantityOrdered) AS total_ordered
FROM mintclassics.products AS pr
LEFT JOIN mintclassics.orderdetails AS od
	ON pr.productCode = od.productCode
LEFT JOIN mintclassics.orders AS os
	ON os.orderNumber = od.orderNumber
GROUP BY
	pr.warehouseCode,
    order_year,
    order_month
HAVING
	total_ordered IS NOT NULL
ORDER BY
	pr.warehouseCode,
    order_year,
    order_month
;


-- Looking to determine how many orders did not ship before their required date (the results say zero)
WITH shipment_info AS (
	SELECT
		pr.warehouseCode AS warehouseCode,
		os.orderNumber AS orderNumber,
		os.orderDate AS orderDate,
        os.requiredDate AS requiredDate,
		os.shippedDate AS shippedDate
	FROM mintclassics.orders AS os
	JOIN mintclassics.orderdetails AS od
		ON os.orderNumber = od.orderNumber
	JOIN mintclassics.products AS pr
		ON od.productCode = pr.productCode
	WHERE os.shippedDate IS NOT NULL
		AND od.orderNumber <> 10165 -- This order was identified as an outlier due to customer payment issues, not fulfillment issues. See notes in the query above
)
SELECT
	warehouseCode,
    COUNT(orderNumber) AS orders_overdue
FROM shipment_info
WHERE shippedDate > requiredDate
GROUP BY
	warehouseCode
ORDER BY
	warehouseCode
;



/*
This section will focus on the earnings vs. cost of available products
*/


-- Finding the monthly ordered volumes, cost, revenue, by product
SELECT
	pr.productLine AS product_line,
    pr.productCode AS product_code,
    pr.warehouseCode AS warehouse_code,
    EXTRACT(MONTH FROM os.orderDate) AS order_month,
    EXTRACT(YEAR FROM os.orderDate) AS order_year,
    SUM(od.quantityOrdered) AS monthly_order_volume,
    SUM(pr.buyPrice * od.quantityOrdered) AS monthly_product_cost,
    SUM(od.priceEach * od.quantityOrdered) AS monthly_product_revenue,
    SUM(od.priceEach * od.quantityOrdered) - SUM(pr.buyPrice * od.quantityOrdered) AS monthly_net
FROM mintclassics.orderdetails AS od
JOIN mintclassics.products AS pr
	ON od.productCode = pr.productCode
JOIN mintclassics.orders AS os
	ON os.orderNumber = od.orderNumber
WHERE os.status <> 'Cancelled' -- Eliminating any cancelled orders
GROUP BY warehouse_code, order_year, order_month, product_line, product_code
ORDER BY warehouse_code, order_year, order_month, product_line, product_code
;



/*
This section is focused on looking for any relationship between sales and inventory volume
*/

WITH sales_volumes AS (
	SELECT
		pr.productCode,
		SUM(od.quantityOrdered) AS volume_ordered,
		pr.quantityInStock AS quantity_in_stock,
		pr.quantityInStock - SUM(od.quantityOrdered) AS difference,
		ROUND((SUM(od.quantityOrdered) / pr.quantityInStock) * 100, 2) AS pct_of_stock_sold
	FROM mintclassics.products AS pr
	LEFT JOIN mintclassics.orderdetails AS od
		ON pr.productCode = od.productCode
	GROUP BY
		pr.productCode
	ORDER BY
		pr.productCode
)
SELECT
	*,
    CASE
		WHEN pct_of_stock_sold < 20 THEN 'Very High Inventory'
        WHEN pct_of_stock_sold BETWEEN 20 AND 40 THEN 'High Inventory'
        WHEN pct_of_stock_sold BETWEEN 40 AND 70 THEN 'Appropriate Inventory'
        WHEN pct_of_stock_sold BETWEEN 70 AND 100 THEN 'Low Inventory'
        WHEN pct_of_stock_sold > 100 THEN 'More orders than in Inventory'
	END AS inventory_level,
    volume_ordered * 2 AS suggested_volume,
    ROUND(AVG((volume_ordered / ROUND(quantity_in_stock * 0.95) * 100)) OVER(), 2) AS avg_pct_of_stock_sold,
    pct_of_stock_sold - ROUND(AVG((volume_ordered / ROUND(quantity_in_stock * 0.95) * 100)) OVER(), 2) AS dev_from_average_stock_pct,
    ROUND(quantity_in_stock * 0.95, 0) AS adj_in_stock, -- Also seeing how removing inventory would affect this
    ROUND(volume_ordered / ROUND(quantity_in_stock * 0.95, 0) * 100, 2) AS adj_pct_of_stock,
    DENSE_RANK() OVER(ORDER BY volume_ordered DESC) AS ranking
FROM sales_volumes
WHERE volume_ordered IS NOT NULL -- Not including products that sold more than are in stock, or that haven't sold at all, as they are addressed separately
ORDER BY ranking
;


-- "What-if?" Looking at number of products not in stock if overall on-hand quantity is reduced by 5%
-- Which ordered items are then not fully in stock?
SELECT
	pr.productLine AS product_line,
	pr.productName AS product_name,
    pr.quantityInStock AS in_stock,
    ROUND(pr.quantityInStock * 0.95, 0) AS adjusted_in_stock,
	SUM(od.quantityOrdered) AS total_ordered,
	pr.warehouseCode AS warehouse_code
FROM mintclassics.products AS pr
LEFT JOIN mintclassics.orderdetails AS od 
	ON od.productCode = pr.productCode
GROUP BY pr.productLine, pr.productName, pr.warehouseCode, in_stock
HAVING adjusted_in_stock < SUM(od.quantityOrdered)
ORDER BY pr.warehouseCode, total_ordered DESC
;




