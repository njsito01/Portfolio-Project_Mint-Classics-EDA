# Portfolio Project - Mint Classics EDA

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
From the provided dataset, I chose to focus my queries on 4 specific tables:
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
Keeping in mind that there are other factors that can impact this calculation, such as packaging sizes, the above query yielded the following estimated results:


|Warehouse Code|Warehouse Name|Quantity In Stock|Warehouse Percent Capacity| Est. Total Capacity|Est. Open Spaces|
|:---:|:---:|:---:|:---:|:---:|:---:|
|a|North|131688|72|182900|51212|
|b|East|219183|67|327139|107956|
|c|West|124880|50|249760|124880|
|d|South|79380|75|105840|26460|

#### Question 2 - How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?

#### Question 3 - Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

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
