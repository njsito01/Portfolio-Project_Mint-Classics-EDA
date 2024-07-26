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
- Tableau Public: Visualization tool for producing informative graphs

#### Tables
From the provided dataset, I found these 4 tables to be the most relevant to answering the proposed questions:
- _products_ - Houses information about individual products, including product codes and names, warehouse, stocking price
- _orders_ - Contains information about the order fulfillment, such as order status, order date, and shipping date
- _orderdetails_ - Contains information about the makeup of the orders, including quantities of sold items, purchase prices
- _warehouses_ - Houses information about the warehouses, including the warehouse name and the percent of capacity that is full

## Analysis

#### Question 1 - Where are items stored and if they were rearranged, could a warehouse be eliminated?
To answer the first question, I looked into the _warehouses_ and _products_ tables to determine where inventory was held, and after familiarizing myself with various information like _"What product lines are stored in which warehouse, and how many unique products are there?"_, I compiled results that broke down the inventory volumes of each warehouse by product line and product.

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

>_Results here are limited if only in order to show the produced format:_

|Warehouse Name|Warehouse Code|Product Line|Product Code|Qty In Stock|
|:---|:---:|:---|:---:|:---:|
|North|a|Motorcycles|S10_1678|7933|
|North|a|Motorcycles|S10_2016|6625|
|North|a|Motorcycles|S10_4698|5582|
|North|a|Motorcycles|S12_2823|9997|
|North|a|Motorcycles|S18_2625|4357|


Additionally I narrowed down to determine which product lines are stored in which warehouse:

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
>The query above produced these results:

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

>Keeping in mind that there are other factors that can impact this calculation, such as packaging sizes, the above query yielded the following estimated results:

|Warehouse Code|Warehouse Name|Quantity In Stock|Warehouse Percent Capacity| Est. Total Capacity|Est. Open Spaces|
|:---:|:---|:---:|:---:|:---:|:---:|
|a|North|131688|72|182900|51212|
|b|East|219183|67|327139|107956|
|c|West|124880|50|249760|124880|
|d|South|79380|75|105840|26460|

#### Question 2 - How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?

In order to answer this question, I put together the average number of units sold per year, for each product.  I also included the total number of units in stock, in order to compare.

``` sql
WITH yearly_qty AS (
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
)
SELECT
  product_line,
  product_code,
  product_name,
  ROUND(AVG(qty_ordered), 0) AS avg_qty_ordered,
  qty_in_stock
FROM yearly_qty
WHERE order_year <> 2005
GROUP BY product_line, product_code, product_name
ORDER BY
  avg_qty_ordered DESC
;
```
> I've limited the results, here, in order to show the types of results produced:

|product_line|product_code|product_name|avg_qty_ordered|qty_in_stock|
|:---|:---:|:---|:---:|:---:|
|Classic Cars|S18_3232|1992 Ferrari 360 Spider red|731|8347|
|Planes|S18_1662|1980s Black Hawk Helicopter|448|5330|
|Ships|S700_2610|The USS Constitution Ship|445|7083|
|Vintage Cars|S18_1342|1937 Lincoln Berline|445|8693|
|Classic Cars|S12_1108|2001 Ferrari Enzo|442|3619|



#### Question 3 - Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

To answer this question, the first task is to identify which products have been ordered the least over the date range covered in the dataset:

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

From there, I was able to identify a specific product that has not sold any units in the entire date range of the dataset:

|Warehouse Code|Product Code|Product Name|Qty In Stock|Total Ordered|
|:---:|:---:|:---|:---:|:---:|
|b|S18_3233|1985 Toyota Supra|7733|0|


## Findings
Here, I will show, using visualizations(?), what the data is suggesting

#### Question 1 - Where are items stored and if they were rearranged, could a warehouse be eliminated?

#### Question 2 - How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?

To answer this question, I made some distinctions between the current inventory counts of individual products. An 'occurrence' is a single year for a unique product where the total quantity ordered for that year is of a certain percentage of the total current inventory of that product.  'High' would be a product-year where the total sold was less than 10% of the current inventory of that product. Any product-year between 10% and 30% would be 'Appropriate', between 30% and 100% would be 'Low', and anything where the product-year greater than the current total inventory is marked as 'Not enough in stock to meet demand'

This does not indicate that these products were not in stock at the time, but merely gives insight into how much inventory is on hand for an individual product, based on prior years sales figures. The data would suggest that while the inventory counts for some products could be increased to more accurately line up with their demand, many products are well overstocked (for example, for any products in the 'High' category, it would take around 10 years to fully diminish the current inventory, without restocking).

| Inventory Level | Occurrences |
|:---|:---:|
|High|222|
|Approriate|66|
|Low|26|
|Not enough in stock to meet demand|13|



#### Question 3 - Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

## Conclusions
Here, I will provide my suggestions to resolve the business questions, as well as next steps, and potentially I'll include some further steps that could be taken, past the original questions
