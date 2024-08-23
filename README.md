# Portfolio Project - Exploratory Data Analysis for Mint Classics Company

## Introduction
The presented project was to take the role of an entry-level data analyst, and perform an exploratory data analysis for the fictional Mint Classics Company. The goal of which is to
identify any patterns or themes in the data that might influence re-organizing or reducing inventory at their warehouse facilities. 

For more information and access to the provided dataset, please see the [Coursera Project](https://www.coursera.org/projects/showcase-analyze-data-model-car-database-mysql-workbench)

## Background
The scenario for this project was as follows:

>_Mint Classics Company, a retailer of classic model cars and other vehicles, is looking at closing one of their storage facilities._

>_To support a data-based business decision, they are looking for suggestions and recommendations for reorganizing or reducing inventory,
>while still maintaining timely service to their customers. For example, they would like to be able to ship a product to a customer within 24 hours of the order being placed._

In this exploratory analysis, I looked to answer three questions:

1) Where are items stored and if they were rearranged, could a warehouse be eliminated?
2) How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?
3) Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

## Approach

#### Tools
For this project, I utilized the following tools:
- SQL: The language of the code written
- MySQL Workbench: The environment I interacted with and queried the database from
- MySQL Server: The database where the dataset was stored

#### Tables
From the provided dataset, I found these 4 tables to be the most relevant to answering the proposed questions:
- _products_ - Houses information about individual products, including product codes and names, warehouse, stocking price
- _orders_ - Contains information about the order fulfillment, such as order status, order date, and shipping date
- _orderdetails_ - Contains information about the makeup of the orders, including quantities of sold items, purchase prices
- _warehouses_ - Houses information about the warehouses, including the warehouse name and the percent of capacity that is full

## Analysis

#### Question 1 - Where are items stored and if they were rearranged, could a warehouse be eliminated?
To answer the first question, I looked into the _warehouses_ and _products_ tables to determine where inventory was held, and started by familiarizing myself with various information like _"What product lines are stored in which warehouse, and how many unique products are there?"_. Below are the compiled results that breaks down the inventory volumes of each warehouse by product line and product.

<details>
	<summary><sub>Expand SQL</sub></summary>
``` SQL
SELECT
  wh.warehouseName AS warehouse_name,
  wh.warehouseCode AS warehouse_code,
  pr.productLine AS product_line,
  pr.productCode AS product_code,
  SUM(pr.quantityInStock) AS qty_in_stock
FROM mintclassics.warehouses AS wh
JOIN mintclassics.products AS pr
	ON wh.warehouseCode = pr.warehouseCode
GROUP BY warehouse_name, warehouse_code, product_line, product_code
ORDER BY warehouse_code, product_line, product_code
;
```
</details>

>_Results here are limited if only in order to show the produced format:_

|Warehouse Name|Warehouse Code|Product Line|Product Code|Qty In Stock|
|:---|:---:|:---|:---:|:---:|
|North|a|Motorcycles|S10_1678|7933|
|North|a|Motorcycles|S10_2016|6625|
|North|a|Motorcycles|S10_4698|5582|
|North|a|Motorcycles|S12_2823|9997|
|North|a|Motorcycles|S18_2625|4357|


Additionally I narrowed down to determine which product lines are stored in which warehouse:

<details>
	<summary><sub>Expand SQL</sub></summary>

``` sql
SELECT
  wh.warehouseName AS warehouse_name,
  wh.warehouseCode AS warehouse_code,
  pr.productLine AS product_line,
  SUM(quantityInStock) AS in_stock    
FROM mintclassics.products AS pr
JOIN mintclassics.warehouses AS wh
  ON pr.warehouseCode = wh.warehouseCode
GROUP BY 
  warehouse_code,
  warehouse_name,
  product_line
ORDER BY
  warehouse_code
;
```
</details>

>_The query above produced these results:_

|Warehouse Name|Warehouse Code|Product Line|In Stock|
|:---|:---:|:---|:---:|
|North|a|Motorcycles|69401|
|North|a|Planes|62287|
|East|b|Classic Cars|219183|
|West|c|Vintage Cars|124880|
|South|d|Ships|26833|
|South|d|Trains|16696|
|South|d|Trucks and Buses|35851|


The next piece required to answer this was to estimate what the storage capacity actually is for each warehouse. I did this by aggregating the current total inventory in each warehouse and reverse-calculating that against the warehouse percent capacity to determine the estimated total capacity, as well as estimated open spaces.


<details>
	<summary><sub>Expand SQL</sub></summary>
	
``` sql
WITH storage_spaces AS (
  SELECT
    wh.warehouseCode AS warehouse_code,
    wh.warehouseName AS warehouse_name,
    SUM(pr.quantityInStock) AS qty_in_stock,
    wh.warehousePctCap AS warehouse_pct_cap,
    -- Performing a simpilfied calculation to find the estimated total capacity of each warehouse
    ROUND(SUM(pr.quantityInStock) / (wh.warehousePctCap / 100), 0) AS est_total_capacity 
  FROM mintclassics.warehouses AS wh
  JOIN mintclassics.products AS pr
    ON wh.warehouseCode = pr.warehouseCode
  GROUP BY
    warehouse_code,
    warehouse_pct_cap
)
SELECT
  *,
  est_total_capacity - qty_in_stock AS est_open_spaces
FROM storage_spaces
;
```
</details>

>_Keeping in mind that there are other factors that can impact this calculation (such as packaging sizes), the above query yielded the following estimated results:_

|Warehouse Code|Warehouse Name|Quantity In Stock|Warehouse Percent Capacity| Est. Total Capacity|Est. Open Spaces|
|:---:|:---|:---:|:---:|:---:|:---:|
|a|North|131688|72|182900|51212|
|b|East|219183|67|327139|107956|
|c|West|124880|50|249760|124880|
|d|South|79380|75|105840|26460|

#### Question 2 - How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?

In order to answer this question, I put together the average number of units sold per year, for each product.  I also included the total number of units in stock, in order to compare.

However, I started with a temporary table to base a few calculations on:


<details>
	<summary><sub>Expand SQL</sub></summary>
	
``` sql
CREATE TEMPORARY TABLE yearly_qty AS
SELECT
  EXTRACT(YEAR FROM os.orderDate) AS order_year,
  pr.productLine AS product_line,
  pr.productCode AS product_code,
  pr.productName AS product_name,
  pr.quantityInStock AS qty_in_stock,
  SUM(od.quantityOrdered) AS qty_ordered
FROM mintclassics.orders AS os
JOIN mintclassics.orderdetails AS od
  ON os.orderNumber = od.orderNumber
JOIN mintclassics.products AS pr
  ON od.productCode = pr.productCode
GROUP BY order_year, product_line, product_code, qty_in_stock
ORDER BY product_code, order_year
;
```
</details>

Then I proceeded to find the average quantity ordered for each product each year, and their respective quantities in stock. I did not include the year 2005, as the dataset does not cover the entirety of that year.


<details>
	<summary><sub>Expand SQL</sub></summary>
	
``` sql
SELECT
  product_line,
  product_code,
  product_name,
  ROUND(AVG(qty_ordered), 0) AS avg_qty_ordered,
  ROUND((ROUND(AVG(qty_ordered), 0) / qty_in_stock) * 100, 2) AS pct_of_inventory,
  qty_in_stock
FROM yearly_qty
WHERE order_year <> 2005
GROUP BY product_line, product_code, product_name, qty_in_stock
ORDER BY
  avg_qty_ordered DESC
;
```
</details>

>_I've limited the results, here, in order to show the types of results produced:_

|Product Line|Product Code|Product Name|Average Quantity Ordered|Qty In Stock|
|:---|:---:|:---|:---:|:---:|
|Classic Cars|S18_3232|1992 Ferrari 360 Spider red|731|8347|
|Planes|S18_1662|1980s Black Hawk Helicopter|448|5330|
|Ships|S700_2610|The USS Constitution Ship|445|7083|
|Vintage Cars|S18_1342|1937 Lincoln Berline|445|8693|
|Classic Cars|S12_1108|2001 Ferrari Enzo|442|3619|


Next, I took that output and found the percentage of the total inventory the average quantity ordered comprises. From that, I placed each unit into a category based on the amount of the total inventory a product's yearly average sales would comprise, in order to illustrate how much inventory there is per the demand.

- **_High_** inventory level is anything where the average sold per year is less than 10% of the current total inventory
	- It would take potentially 10 years or more before these products would sell out
- **_Medium_** is anything where the average falls between 10% and 50% of the current total
	- These could take 2 to 10 years to sell out of the current inventory
- **_Low_** is between 50% and 100%
	- These could be sold out within a year or two
- **_Not enough on hand_** reflects any product where the current total inventory will not be sufficient to cover the average quantity sold per year

With that, I took the number of products in each category and showed how many fell into each category.


<details>
	<summary><sub>Expand SQL</sub></summary>
	
``` sql
WITH avg_qtys AS (
  SELECT
    product_line,
    product_code,
    product_name,
    ROUND(AVG(qty_ordered), 0) AS avg_qty_ordered,
    ROUND((ROUND(AVG(qty_ordered), 0) / qty_in_stock) * 100, 2) AS pct_of_inventory,
    qty_in_stock
  FROM yearly_qty
  WHERE order_year <> 2005
  GROUP BY product_line, product_code, product_name, qty_in_stock
  ORDER BY
    avg_qty_ordered DESC
), inv_levels AS (
  SELECT
    *,
    CASE
      WHEN pct_of_inventory < 10 THEN 'High'
      WHEN pct_of_inventory BETWEEN 10 AND 50 THEN 'Medium'
      WHEN pct_of_inventory BETWEEN 50 AND 100 THEN 'Low'
      WHEN pct_of_inventory > 100 THEN 'Not enough on hand'
    END AS inventory_level
  FROM avg_qtys
)
SELECT
  inventory_level,
  COUNT(*) AS occurrences
FROM inv_levels
GROUP BY inventory_level
```
</details>

Which produced this result:

|Inventory Level|Occurrences|
|:---|:---:|
|High|66|
|Medium|33|
|Low|6|
|Not enough on hand|4|

#### Question 3 - Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

To answer this question, the first task is to identify which products have been ordered the least over the date range covered in the dataset:


<details>
	<summary><sub>Expand SQL</sub></summary>
	
``` sql
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
```
</details>

>[!NOTE]
>_From there, I was able to identify a specific product that has not sold any units in the entire date range of the dataset:_

|Warehouse Code|Product Code|Product Name|Qty In Stock|Total Ordered|
|:---:|:---:|:---|:---:|:---:|
|b|S18_3233|1985 Toyota Supra|7733|0|


## Findings

#### Question 1 - Where are items stored and if they were rearranged, could a warehouse be eliminated?

The results below seem the most relevant to answering this question.  If the estimated number of open spaces is accurate, the contents of Warehouse D could be moved, potentially in its entirety, into either Warehouse B or C.  I would suggest performing more research to evaluate the amount of open space based on more applicable metrics (actual three-dimensional space required for each item, for example). However, even if the estimates are not entirely accurate, by splitting up the inventory held at Warehouse D by product line, the data would suggest that even without any other changes to inventory, the remaining warehouses have enough open space to facilitate reorganizing inventories and closing down Warehouse D.

|Warehouse Name|Warehouse Code|Product Line|Qty In Stock|
|:---|:---:|:---|:---:|
|North|a|Motorcycles|69401|
|North|a|Planes|62287|
|East|b|Classic Cars|219183|
|West|c|Vintage Cars|124880|
|South|d|Ships|26833|
|South|d|Trains|16696|
|South|d|Trucks and Buses|35851|

|Warehouse Code|Warehouse Name|Quantity In Stock|Warehouse Percent Capacity| Est. Total Capacity|Est. Open Spaces|
|:---:|:---|:---:|:---:|:---:|:---:|
|a|North|131688|72|182900|51212|
|b|East|219183|67|327139|107956|
|c|West|124880|50|249760|124880|
|d|South|79380|75|105840|26460|

#### Question 2 - How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?

By calculating the yearly average number of units ordered for each product, and comparing it to the total number of each product in stock, the data suggests that we have several products that our inventory is not sufficient to serve.  However, we also have an overwhelming number of products that are highly stocked - to reiterate, the products listed as "High" are stocked in such volumes that would take potentially 10 years to sell all the way through their respective inventories, based on their yearly average volumes sold.

|Inventory Level|Occurrences|
|:---|:---:|
|High|66|
|Medium|33|
|Low|6|
|Not enough on hand|4|

#### Question 3 - Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

We were able to find one product that has not sold any units during the entirety of the dataset's date range. This product has shown a lack of demand in the market, but is stocked at a similar volume to some of our top sellers.

|Warehouse Code|Product Code|Product Name|Qty In Stock|Total Ordered|
|:---:|:---:|:---|:---:|:---:|
|b|S18_3233|1985 Toyota Supra|7733|0|

## Conclusions

The goal of this exploratory data analysis was to identify any patterns or themes in the data that might influence reorganizing or reducing the inventory at the Mint Classics Company facilities.

Through this analysis, I have come up with the following suggestions for next steps:

- Perform an evaluation of Warehouses A, B and C, in order to determine a more accurate measure of their open storage space, and if the that aligns with the estimated calculations performed in this analysis.
- Ensure that the items that fall in the "Low" volume and "Not enough on hand" cateogories are re-stocked to volumes that are at the least, sufficient to keep up with their demand
- For items in the "High"  category, consider re-aligning their volume counts to a level that reflects business objectives and demand, more effectively
  - With re-alignment comes the possibility to again re-evaluate the required warehouse space, which could mean even more savings for the company if fewer warehouses are required
- The data would suggest that product S18-3233, '1985 Toyota Supra' could be potentially eliminated from the product, or at least greatly reduced, due to its lack of any sales over the course of multiple years.

Thank you
