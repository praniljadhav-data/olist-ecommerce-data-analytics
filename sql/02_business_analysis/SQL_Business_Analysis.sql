
USE Olist_Ecommerce


-- TotalOrders & DeliveredOrders
SELECT 
	COUNT(*) AS TotalOrders,

	SUM(
			CASE
				WHEN order_status = 'delivered'
					THEN 1
				ELSE 0
			END
	) AS DeliveredOrders

FROM Olist_Ecommerce..orders

-- TotalCustomers
SELECT
	COUNT(DISTINCT customer_unique_id) AS TotalCustomers
FROM customers

-- TotalProducts
SELECT
	COUNT(DISTINCT product_id) AS TotalProducts
FROM products

-- TotalSellers
SELECT
	COUNT(DISTINCT seller_id) AS TotalSellers
FROM sellers

-- TotalOrderValue
SELECT
	SUM(price + freight_value) AS TotalOrderValue
FROM order_items


-- AverageOrderValue
WITH AverageOrderValue AS
(
	SELECT
		order_id,
		SUM(price + freight_value) AS TotalOrderValue
	FROM order_items
	GROUP BY order_id
)

SELECT
	AVG(TotalOrderValue) AS AverageOrderValue
FROM AverageOrderValue

-- OnTimeDeliveryRate

SELECT
	ROUND(
		SUM(
			CAST(
				CASE
					WHEN order_delivered_customer_date <= order_estimated_delivery_date
						THEN 1
					ELSE 0
				END 
			AS FLOAT)
		)

	/

	CAST(COUNT(order_delivered_customer_date) AS FLOAT) * 100,
	2) AS OnTimeDeliveryRate
FROM orders
WHERE order_status = 'delivered'

-- LateDeliveryRate


SELECT
	100-
	ROUND(
		SUM(
			CAST(
				CASE
					WHEN order_delivered_customer_date <= order_estimated_delivery_date
						THEN 1
					ELSE 0
				END 
			AS FLOAT)
		)

	/

	CAST(COUNT(order_delivered_customer_date) AS FLOAT) * 100,
	2) AS LateDeliveryRate
FROM orders
WHERE order_status = 'delivered'

----------------------------------Customer & Order Analysis----------------------------------------------------------------------------------------
--RepeatCustomerRate
WITH base_data AS

(
	SELECT 
		o.order_id,
		o.customer_id,
		c.customer_unique_id
	FROM orders o
	INNER JOIN customers c
	ON o.customer_id = c.customer_id
),

TotalOrder AS 
(
	SELECT 
		customer_unique_id,
		COUNT(*) AS TotalOrder
	FROM base_data
	GROUP BY customer_unique_id
)

SELECT
	ROUND(
		CAST(
			SUM(
				CASE 
					WHEN TotalOrder > 1 
						THEN 1 
					ELSE 0 
				END
			) 
		AS FLOAT)
	/
	CAST(
		COUNT(*) AS FLOAT
	) * 100,2
	) AS RepeatCustomerRate
FROM TotalOrder

--AverageOrdersPerCustomer
WITH BaseData AS
(
	SELECT 
		o.order_id,
		o.customer_id,
		c.customer_unique_id
	FROM orders o
	INNER JOIN customers c
		ON o.customer_id = c.customer_id
)

SELECT
	ROUND(
		CAST(COUNT(order_id) AS FLOAT)
		/
		CAST(COUNT(DISTINCT customer_unique_id) AS FLOAT),
		2
	) AS AverageOrdersPerCustomer
FROM BaseData

--OneTimeCustomerPercentage
WITH base_data AS

(
	SELECT 
		o.order_id,
		o.customer_id,
		c.customer_unique_id
	FROM orders o
	INNER JOIN customers c
	ON o.customer_id = c.customer_id
),

TotalOrder AS 
(
	SELECT 
		customer_unique_id,
		COUNT(*) AS TotalOrder
	FROM base_data
	GROUP BY customer_unique_id
)

SELECT
	ROUND(
		CAST(
			SUM(
				CASE 
					WHEN TotalOrder = 1 
						THEN 1 
					ELSE 0 
				END
			) 
		AS FLOAT)
	/
	CAST(
		COUNT(*) AS FLOAT
	) * 100,2
	) AS OneTimeCustomerPercentage
FROM TotalOrder


--Top10CustomersByTotalSpending.

WITH CustomerTotalOrders AS
(
	SELECT
		C.customer_unique_id,
		COUNT(DISTINCT O.order_id) AS TotalNumberOfOrders,
		SUM(I.price + I.freight_value) AS TotalSpending,
		DENSE_RANK() OVER(
			ORDER BY SUM(I.price + I.freight_value) DESC
		) AS SpendingRank
	FROM Olist_Ecommerce..customers C
	INNER JOIN Olist_Ecommerce..orders O
	ON C.customer_id = O.customer_id
	INNER JOIN Olist_Ecommerce..order_items I
	ON O.order_id = I.order_id
	GROUP BY C.customer_unique_id
)

SELECT
	customer_unique_id,
	TotalNumberOfOrders,
	TotalSpending
FROM CustomerTotalOrders
WHERE SpendingRank <= 10

----------------------------------Product Category Performance----------------------------------------------------------------------------------------

--Top10ProductCategoriesByTotalSalesValue

WITH BaseData AS
(
	SELECT
		COALESCE(T.product_category_name_english,P.product_category_name) AS ProductCategory,
		COUNT(DISTINCT I.order_id) AS TotalNumberOfOrders,
		COUNT(I.order_id) AS TotalQuantitySold,
		COALESCE(SUM(I.price + I.freight_value),0) AS TotalSalesValue,
		DENSE_RANK() OVER(
			ORDER BY COALESCE(SUM(I.price + I.freight_value),0) DESC
		) AS SalesRank
	FROM 
	(
		SELECT 
			product_id,
			CASE
				WHEN product_category_name IS NULL
					THEN 'Product Unknown'
				ELSE product_category_name
			END AS product_category_name
		FROM products
	) P
	LEFT JOIN order_items I
	ON P.product_id = I.product_id
	LEFT JOIN category_translation T
	ON P.product_category_name = T.product_category_name
	GROUP BY T.product_category_name_english,P.product_category_name
)

SELECT
	ProductCategory,
	TotalNumberOfOrders,
	TotalQuantitySold,
	TotalSalesValue
FROM BaseData
WHERE SalesRank <= 10

----------------------------------Monthly Sales Trend----------------------------------------------------------------------------------------
--MonthlySalesTrend
WITH BaseData AS

(
	SELECT 
		LEFT(DATENAME(MONTH,O.order_purchase_timestamp) ,3) + ''''+
		RIGHT(DATEPART(YEAR,O.order_purchase_timestamp),2) AS MonthYear,

		DATEADD(D,1,EOMONTH(O.order_purchase_timestamp,-1)) AS DateSort,
		I.order_item_id,
		I.order_id,
		I.price,
		I.freight_value
	FROM orders O
	INNER JOIN order_items I
	ON O.order_id = I.order_id
)
SELECT
	MonthYear,
	COUNT(DISTINCT order_id) AS TotalNumberOfOrders,
	COUNT(order_id) AS TotalQuantitySold,
	COALESCE(SUM(price + freight_value),0) AS TotalSalesValue,
	DateSort
FROM BaseData
GROUP BY MonthYear,DateSort
ORDER BY CAST(DateSort AS DATE)

--MonthOnMonthGrowth Monthly Summary
/*
CREATE OR ALTER VIEW dbo.vw_MonthlySalesPerformance

AS

WITH RequiredDate AS
(
	SELECT
		DATEADD(D,1,EOMONTH(MIN(O.order_purchase_timestamp),-1)) AS StartMonth,
		DATEADD(D,1,EOMONTH(MAX(O.order_purchase_timestamp),-1)) AS EndMonth
	FROM orders O
	INNER JOIN  order_items I 
	ON O.order_id = I.order_id
),

CalendarMonth AS
(
	SELECT
		StartMonth,
		EndMonth
	FROM RequiredDate

	UNION ALL

	SELECT
		DATEADD(M,1,StartMonth),
		EndMonth
	FROM CalendarMonth
	WHERE StartMonth < EndMonth
),

BaseData AS

(
	SELECT 
		LEFT(DATENAME(MONTH,O.order_purchase_timestamp) ,3) + ''''+
		RIGHT(DATEPART(YEAR,O.order_purchase_timestamp),2) AS MonthYear,

		DATEADD(D,1,EOMONTH(O.order_purchase_timestamp,-1)) AS DateSort,
		I.order_item_id,
		I.order_id,
		I.price,
		I.freight_value
	FROM orders O
	INNER JOIN order_items I
	ON O.order_id = I.order_id
),

MonthlyTrend AS
(
	SELECT
		MonthYear,
		COUNT(DISTINCT order_id) AS TotalNumberOfOrders,
		COUNT(order_id) AS TotalQuantitySold,
		COALESCE(SUM(price + freight_value),0) AS TotalSalesValue,
		DateSort
	FROM BaseData
	GROUP BY MonthYear,DateSort
),

FinalData AS
(
	SELECT
		LEFT(DATENAME(MONTH,C.StartMonth) ,3) + ''''+
		RIGHT(DATEPART(YEAR,C.StartMonth),2) AS MonthYear,
		COALESCE(M.TotalNumberOfOrders,0) AS TotalNumberOfOrders,
		COALESCE(M.TotalQuantitySold,0) AS TotalQuantitySold,
		COALESCE(M.TotalSalesValue,0) AS TotalSalesValue,

		LAG(COALESCE(M.TotalSalesValue,0)) OVER(
				ORDER BY C.StartMonth
			) AS PrevMonthSales,

		CAST(LAG(COALESCE(M.TotalNumberOfOrders,0)) OVER(
				ORDER BY C.StartMonth
			) AS FLOAT) AS PrevMonthOrders,

		CAST(LAG(COALESCE(M.TotalQuantitySold,0)) OVER(
				ORDER BY C.StartMonth
			) AS FLOAT) AS PrevMonthQuantity,

		C.StartMonth AS DateSort
	FROM CalendarMonth C
	LEFT JOIN MonthlyTrend M
	ON C.StartMonth = M.DateSort
)

SELECT
	MonthYear,
	DateSort,

	TotalSalesValue,
	PrevMonthSales,
	ROUND((TotalSalesValue - PrevMonthSales) / NULLIF(PrevMonthSales,0) * 100,2) AS MonthlyGrowthPercent,

	TotalNumberOfOrders,
	PrevMonthOrders,
	ROUND((TotalNumberOfOrders - PrevMonthOrders) / NULLIF(PrevMonthOrders,0) * 100,2) AS MonthlyOrderGrowthPercent,

	TotalQuantitySold,
	PrevMonthQuantity,
	ROUND((TotalQuantitySold - PrevMonthQuantity) / NULLIF(PrevMonthQuantity,0) * 100,2) AS MonthlyQuantityGrowthPercent

FROM FinalData
*/

SELECT * FROM dbo.vw_MonthlySalesPerformance
ORDER BY DateSort


--Top10CustomersByTotalOrders.

WITH CustomerTotalOrders AS
(
	SELECT
		C.customer_unique_id,
		COUNT(DISTINCT O.order_id) AS TotalNumberOfOrders,
		ROW_NUMBER() OVER(
			ORDER BY COUNT(DISTINCT O.order_id) DESC,
			customer_unique_id ASC
		) AS OrderRank
	FROM customers C
	INNER JOIN orders O
	ON C.customer_id = O.customer_id
	GROUP BY C.customer_unique_id
)

SELECT
	customer_unique_id,
	TotalNumberOfOrders
FROM CustomerTotalOrders
WHERE OrderRank <= 10

------------------------------------------Customer spending segmentation-------------------------------

WITH CustomerTotalOrders AS
(
	SELECT
		C.customer_unique_id,
		SUM(I.price + I.freight_value) AS TotalSpending
	FROM customers C
	INNER JOIN orders O
	ON C.customer_id = O.customer_id
	INNER JOIN order_items I
	ON O.order_id = I.order_id
	GROUP BY C.customer_unique_id
),

CustomerSegment AS
(
	SELECT
		customer_unique_id,
		TotalSpending,
		CASE
			WHEN TotalSpending >= 5000
				THEN 'High Value'

			WHEN TotalSpending >= 1000
				THEN 'Medium Value'

			ELSE 'Low Value'
		END AS CustomerSegment
	FROM CustomerTotalOrders
)

SELECT
	CustomerSegment,
	COUNT(*) AS CountData,
	SUM(TotalSpending) AS TotalRevenue
FROM CustomerSegment
GROUP BY CustomerSegment

--Customer segment revenue contribution


WITH CustomerTotalOrders AS
(
	SELECT
		C.customer_unique_id,
		SUM(I.price + I.freight_value) AS TotalSpending
	FROM customers C
	INNER JOIN orders O
	ON C.customer_id = O.customer_id
	INNER JOIN order_items I
	ON O.order_id = I.order_id
	GROUP BY C.customer_unique_id
),

CustomerSegment AS
(
	SELECT
		customer_unique_id,
		TotalSpending,
		CASE
			WHEN TotalSpending >= 5000
				THEN 'High Value'

			WHEN TotalSpending >= 1000
				THEN 'Medium Value'

			ELSE 'Low Value'
		END AS CustomerSegment
	FROM CustomerTotalOrders
),

FinalData AS
(
	SELECT
		CustomerSegment,
		COUNT(customer_unique_id) AS CustomerCount,
		SUM(TotalSpending) AS TotalRevenue
	FROM CustomerSegment
	GROUP BY CustomerSegment
),

TotalRevenue AS

(
	SELECT SUM(TotalSpending) AS TotalRevenue FROM CustomerSegment
)

SELECT 
	F.CustomerSegment,
	F.CustomerCount,
	F.TotalRevenue,
	CAST(ROUND(F.TotalRevenue / C.TotalRevenue * 100,2) AS DECIMAL(10,2)) AS RevenueContributionPercent
FROM FinalData F
CROSS JOIN TotalRevenue C

---------------------------------------Customer retention analysis

WITH OrderDetails AS

(
	SELECT 
		C.customer_unique_id,
		COUNT(O.order_id) AS OrderCount
	FROM customers C
	INNER  JOIN orders O
	ON C.customer_id = O.customer_id
	GROUP BY C.customer_unique_id
),

OrderCategoryData AS

(
	SELECT
		customer_unique_id,
		OrderCount,

		CASE
			WHEN OrderCount >= 3
				THEN '3 or more orders'

			WHEN OrderCount = 2
				THEN 'Exactly 2 orders'

			ELSE 'Exactly 1 order'
		END AS OrderCategory,

		CASE
			WHEN OrderCount >= 3
				THEN 3

			WHEN OrderCount = 2
				THEN 2

			ELSE 1
		END AS OrderCategorySort

	FROM OrderDetails
),

FinalData AS
(
	SELECT
		OrderCategory,
		COUNT(*) AS CustomerCount,
		OrderCategorySort
	FROM OrderCategoryData
	GROUP BY OrderCategory,OrderCategorySort
),

TotalNumOfCustomer AS
(
	SELECT SUM(CustomerCount) AS TotalCustomer FROM FinalData
)

SELECT
	F.OrderCategory,
	F.CustomerCount,
	F.OrderCategorySort,
	ROUND(CAST(F.CustomerCount AS FLOAT)/ CAST(T.TotalCustomer AS FLOAT)* 100,2) AS CustomerPercentage
FROM FinalData F
CROSS JOIN TotalNumOfCustomer T

-------------------------------------Payment Method Analysis

--SELECT COUNT(DISTINCT order_id) FROM payments ---99440

--SELECT COUNT(order_id) FROM payments   ---103886


WITH PaymentData AS

(
	SELECT
		payment_type AS PaymentType,
		COUNT(DISTINCT order_id) AS TotalTransactions,
		COUNT(order_id) AS TotalPaymentRecords,
		SUM(payment_value) AS TotalPaymentValue,
		CAST(AVG(payment_value) AS DECIMAL(10,2)) AS AveragePaymentRecordValue
	FROM payments
	GROUP BY payment_type
),

TotalValue AS

(
	SELECT
		SUM(TotalPaymentValue) AS TotalPaymentValue,
		SUM(TotalPaymentRecords) AS TotalPaymentRecords
	FROM PaymentData
)

SELECT
	P.PaymentType,
	P.TotalTransactions,
	P.TotalPaymentValue,
	P.AveragePaymentRecordValue,
	CAST(P.TotalPaymentValue / T.TotalPaymentValue * 100 AS DECIMAL(10,2)) AS PaymentContributionPercent,
	P.TotalPaymentRecords,
	CAST(CAST(P.TotalPaymentRecords AS FLOAT)/ T.TotalPaymentRecords * 100 AS DECIMAL(10,2)) AS PaymentRecordPercentage
FROM PaymentData P
CROSS JOIN TotalValue T

----------------------------------------------Review and customer satisfaction analysis

WITH BaseData AS

(
	SELECT
		review_score,
		COUNT(*) AS TotalReviews,
		COUNT(DISTINCT review_id) AS TotalUniqueCustomerReview
	FROM reviews
	GROUP BY review_score
),

ReviewCount AS
(
	SELECT
		SUM(TotalReviews) AS SumOFReviews
	FROM BaseData
)

SELECT
	B.review_score,
	B.TotalReviews,
	B.TotalUniqueCustomerReview,
	CAST((CAST(B.TotalReviews AS FLOAT) / R.SumOFReviews * 100) AS DECIMAL(10,2)) AS ReviewPercentage
FROM BaseData B
CROSS JOIN ReviewCount R
ORDER BY B.review_score

------------------------------------------------------Seller Performance Analysis

WITH BaseData AS
(
	SELECT
		seller_id,
		COUNT(DISTINCT order_id) AS TotalOrders,
		COUNT(*) AS TotalItemsSold,
		SUM(price + freight_value) AS TotalSalesValue
	FROM order_items
	GROUP BY seller_id
),

FinalData AS

(
	SELECT
		seller_id,
		TotalOrders,
		TotalItemsSold,
		TotalSalesValue,
		DENSE_RANK() OVER(
			ORDER BY TotalSalesValue DESC
		) AS SellersRank
	FROM BaseData
)

SELECT
	seller_id,
	TotalOrders,
	TotalItemsSold,
	TotalSalesValue	
FROM FinalData
WHERE SellersRank <= 10

---------------------------------------------Seller performance by delivery experience

WITH BaseDate AS

(
	SELECT
		S.seller_id,
		COUNT(DISTINCT O.order_id) AS TotalDeliveredOrders,
	
		COUNT(DISTINCT CASE
				WHEN O.order_delivered_customer_date <= O.order_estimated_delivery_date
					THEN O.order_id
				ELSE NULL
			END
		) AS OnTimeDeliveredOrders,

		COUNT(DISTINCT CASE
				WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date
					THEN O.order_id
				ELSE NULL
			END
		) AS LateDeliveredOrders,

		COUNT(DISTINCT CASE
				WHEN O.order_delivered_customer_date IS NOT NULL AND O.order_estimated_delivery_date IS NOT NULL
					THEN O.order_id
				ELSE NULL
			END
		) AS EligibleDeliveredOrders

	FROM sellers S
	INNER JOIN order_items I
	ON S.seller_id = I.seller_id
	INNER JOIN orders O
	ON I.order_id = O.order_id
	WHERE O.order_status = 'delivered'
	GROUP BY S.seller_id
)

	SELECT
		seller_id,
		EligibleDeliveredOrders,
		TotalDeliveredOrders,
		OnTimeDeliveredOrders,
		LateDeliveredOrders,
		CAST(CAST(OnTimeDeliveredOrders AS FLOAT) / NULLIF(EligibleDeliveredOrders,0) * 100 AS DECIMAL(10,2)) AS OnTimeDeliveryRate
	FROM BaseDate

----------------------------------------Seller revenue contribution

WITH BaseData AS

(
	SELECT
		seller_id,
		COUNT(DISTINCT order_id) AS TotalOrders,
		COUNT(order_id) AS TotalItemsSold,
		SUM(price + freight_value) AS TotalSalesValue
	FROM order_items
	GROUP BY seller_id
),

TotalSales AS 

(
	SELECT
		SUM(TotalSalesValue) AS TotalSalesValue
	FROM BaseData
),

FinalData AS

(
	SELECT
		B.seller_id,
		B.TotalOrders,
		B.TotalItemsSold,
		B.TotalSalesValue,
		CAST(B.TotalSalesValue / T.TotalSalesValue * 100 AS DECIMAL(10,2)) AS RevenueContributionPercent,
		DENSE_RANK() OVER(
			ORDER BY B.TotalSalesValue DESC
		) AS SellersRank
	FROM BaseData B
	CROSS JOIN TotalSales T
)

SELECT
	seller_id,
	TotalOrders,
	TotalItemsSold,
	TotalSalesValue,
	RevenueContributionPercent
FROM FinalData
WHERE SellersRank <= 10

-------------------------------Seller average order value

WITH BaseData AS

(
	SELECT
		seller_id,
		COUNT(DISTINCT order_id) AS TotalOrders,
		SUM(price + freight_value) AS TotalSalesValue
	FROM order_items
	GROUP BY seller_id
	HAVING COUNT(DISTINCT order_id) >= 50
),

FinalData AS

(
	SELECT
		B.seller_id,
		B.TotalOrders,
		B.TotalSalesValue,
		CAST(B.TotalSalesValue / B.TotalOrders AS DECIMAL(10,2)) AS AverageOrderValue,
		DENSE_RANK() OVER(
			ORDER BY CAST(B.TotalSalesValue / B.TotalOrders AS DECIMAL(10,2)) DESC
		) AS SellersRank
	FROM BaseData B
)

SELECT
	seller_id,
	TotalOrders,
	TotalSalesValue,
	AverageOrderValue
FROM FinalData
WHERE SellersRank <= 10

----------------------------------Seller geographical performance

WITH BaseData AS
(
	SELECT
		S.seller_state,
		COUNT(DISTINCT S.seller_id) AS TotalSellers,
		COUNT(DISTINCT I.order_id) AS TotalOrders,
		COUNT(I.order_id) AS TotalItemsSold,
		SUM(I.price + I.freight_value) AS TotalSalesValue
	FROM sellers S
	INNER JOIN order_items I
	ON S.seller_id = I.seller_id
	GROUP BY S.seller_state
),

TotalSales AS

(
	SELECT SUM(TotalSalesValue) AS TotalSales FROM BaseData
),

FinalData AS
(
	SELECT
		seller_state,
		TotalSellers,
		TotalOrders,
		TotalItemsSold,
		TotalSalesValue,
		DENSE_RANK() OVER(
			ORDER BY TotalSalesValue DESC
		) AS SellerRank
	FROM BaseData
)

SELECT
	F.seller_state,
	F.TotalSellers,
	F.TotalOrders,
	F.TotalItemsSold,
	F.TotalSalesValue,
	CAST(F.TotalSalesValue / T.TotalSales * 100 AS DECIMAL(10,2)) AS RevenueContributionPercent
FROM FinalData F
CROSS JOIN TotalSales T
WHERE SellerRank <= 10

----------------------------------Delivery time by seller state

WITH BaseData AS
(
	SELECT
		S.seller_state,
		COUNT(DISTINCT CASE
			WHEN O.order_delivered_customer_date IS NOT NULL
			 AND O.order_purchase_timestamp IS NOT NULL
			THEN O.order_id
		END) AS EligibleDeliveredOrders,
		COUNT(DISTINCT O.order_id) AS TotalDeliveredOrders,
		CAST(AVG(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS AverageDeliveryDays,
		CAST(MIN(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS MinDeliveryDays,
		CAST(MAX(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS MaxDeliveryDays,
		ROW_NUMBER() OVER(
			ORDER BY AVG(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0),
					COUNT(DISTINCT O.order_id) DESC
		) AS AvgRank
	FROM sellers S
	INNER JOIN order_items I
	ON S.seller_id = I.seller_id
	INNER JOIN orders O
	ON O.order_id = I.order_id
	WHERE order_status = 'delivered'
	GROUP BY S.seller_state
)

SELECT
	seller_state,
	EligibleDeliveredOrders,
	TotalDeliveredOrders,
	AverageDeliveryDays,
	MinDeliveryDays,
	MaxDeliveryDays
FROM BaseData
WHERE AvgRank <= 10

----------------------------------Product delivery performance

WITH BaseData AS
(
	SELECT
		COALESCE(T.product_category_name_english,P.product_category_name,'Product Unknown') AS ProductCategory,
		COUNT(DISTINCT CASE
			WHEN O.order_delivered_customer_date IS NOT NULL
				AND O.order_purchase_timestamp IS NOT NULL
			THEN O.order_id
		END) AS EligibleDeliveredOrders,
		COUNT(DISTINCT O.order_id) AS TotalDeliveredOrders,
		CAST(AVG(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS AverageDeliveryDays,
		CAST(MIN(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS MinDeliveryDays,
		CAST(MAX(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS MaxDeliveryDays,
		ROW_NUMBER() OVER(
			ORDER BY AVG(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0),
					COUNT(DISTINCT O.order_id) DESC
		) AS AvgRank
	FROM products P
	LEFT JOIN category_translation T
	ON P.product_category_name = T.product_category_name
	INNER JOIN order_items I
	ON I.product_id = P.product_id
	INNER JOIN orders O
	ON O.order_id = I.order_id
	GROUP BY COALESCE(T.product_category_name_english,P.product_category_name,'Product Unknown')
)

SELECT
	ProductCategory,
	EligibleDeliveredOrders,
	TotalDeliveredOrders,
	AverageDeliveryDays,
	MinDeliveryDays,
	MaxDeliveryDays
FROM BaseData
WHERE AvgRank <= 10

----------------------------------Monthly delivery performance

WITH BaseData AS

(
	SELECT
		LEFT(DATENAME(MONTH,O.order_purchase_timestamp) ,3) + ''''+
		RIGHT(DATEPART(YEAR,O.order_purchase_timestamp),2) AS MonthYear,

		DATEADD(D,1,EOMONTH(O.order_purchase_timestamp,-1)) AS DateSort,

		COUNT(DISTINCT CASE
		WHEN O.order_delivered_customer_date IS NOT NULL
		AND O.order_estimated_delivery_date  IS NOT NULL
		THEN O.order_id
		END) AS OnTimeEligibleOrders,

		COUNT(DISTINCT CASE
		WHEN O.order_delivered_customer_date IS NOT NULL
		AND O.order_estimated_delivery_date  IS NOT NULL
		AND O.order_delivered_customer_date <= O.order_estimated_delivery_date
		THEN O.order_id
		END) AS OnTimeDeliveredOrders,

		COUNT(DISTINCT CASE
		WHEN O.order_delivered_customer_date IS NOT NULL
		AND O.order_purchase_timestamp IS NOT NULL
		THEN O.order_id
		END) AS EligibleDeliveredOrders,

		COUNT(DISTINCT O.order_id) AS TotalDeliveredOrders,
		CAST(AVG(DATEDIFF(SECOND,O.order_purchase_timestamp,O.order_delivered_customer_date) / 86400.0) AS DECIMAL(10,2)) AS AverageDeliveryDays
	FROM orders O
	WHERE O.order_status = 'delivered'
	GROUP BY 
		LEFT(DATENAME(MONTH,O.order_purchase_timestamp) ,3) + ''''+
		RIGHT(DATEPART(YEAR,O.order_purchase_timestamp),2),
		DATEADD(D,1,EOMONTH(O.order_purchase_timestamp,-1))
)

SELECT
	MonthYear,
	DateSort,
	OnTimeEligibleOrders,
	OnTimeDeliveredOrders,
	EligibleDeliveredOrders,
	TotalDeliveredOrders,
	AverageDeliveryDays,
	CAST(CAST(OnTimeDeliveredOrders AS FLOAT) / NULLIF(OnTimeEligibleOrders,0) * 100 AS DECIMAL(10,2)) AS OnTimeDeliveryRate
FROM BaseData
ORDER BY DateSort

----------------------------------freight and shipping cost analysis

WITH BaseData AS
(
	SELECT 
		COALESCE(t.product_category_name_english,p.product_category_name,'Unavailable') AS ProductCategory,
		COUNT(I.order_id) AS TotalItemsSold,
		SUM(I.freight_value) AS TotalFreightValue,
		CAST(AVG(I.freight_value) AS DECIMAL(10,2)) AS AverageFreightValue
	FROM products p
	LEFT JOIN category_translation t
	ON p.product_category_name = t.product_category_name
	INNER JOIN order_items I
	ON I.product_id = P.product_id
	GROUP BY t.product_category_name_english,p.product_category_name
),

TotalFreight AS

(
	SELECT SUM(TotalFreightValue) AS TotalFreightValue FROM BaseData
)

SELECT
	B.ProductCategory,
	B.TotalItemsSold,
	B.TotalFreightValue,
	B.AverageFreightValue,
	CAST(B.TotalFreightValue / T.TotalFreightValue * 100 AS DECIMAL(10,2)) AS FreightContributionPercent
FROM BaseData B
CROSS JOIN TotalFreight T
ORDER BY FreightContributionPercent DESC

----------------------------------Freight cost by customer state

SELECT
	C.customer_state,
	COUNT(DISTINCT I.order_id) AS TotalOrders,
	COUNT(I.order_id) AS TotalItemsSold,
	SUM(I.freight_value) AS TotalFreightValue,
	CAST(AVG(I.freight_value) AS DECIMAL(10,2)) AS AverageFreightPerItem
FROM customers C
INNER JOIN orders O
ON C.customer_id = O.customer_id
INNER JOIN order_items I
ON I.order_id = O.order_id
GROUP BY C.customer_state

----------------------------------Freight cost by seller state

SELECT
	S.seller_state,
	COUNT(DISTINCT I.order_id) AS TotalOrders,
	COUNT(I.order_id) AS TotalItemsSold,
	SUM(I.freight_value) AS TotalFreightValue,
	CAST(AVG(I.freight_value) AS DECIMAL(10,2)) AS AverageFreightPerItem
FROM sellers S
INNER JOIN order_items I
ON S.seller_id = I.seller_id
GROUP BY S.seller_state

----------------------------------Freight cost by seller state

SELECT
	COALESCE(T.product_category_name_english,P.product_category_name,'Unavailable') as ProductCategory,
	COUNT(DISTINCT I.order_id) AS TotalOrders,
	COUNT(I.order_id) AS TotalItemsSold,
	SUM(I.freight_value) AS TotalFreightValue,
	CAST(AVG(I.freight_value) AS DECIMAL(10,2)) AS AverageFreightPerItem,
	CAST(SUM(I.freight_value) / SUM(I.price) * 100 AS DECIMAL(10,2)) AS FreightToProductValuePercent
FROM products P
LEFT JOIN category_translation T
ON P.product_category_name = T.product_category_name
INNER JOIN order_items I
ON P.product_id = I.product_id
GROUP BY T.product_category_name_english,P.product_category_name
ORDER BY FreightToProductValuePercent DESC

-------------------------------------------------Customer State Performance

SELECT 
	C.customer_state,
	COUNT(DISTINCT O.order_id) AS TotalOrders,
	SUM(I.price + I.freight_value) AS TotalRevenue,
	CAST(SUM(I.price + I.freight_value) / COUNT(DISTINCT O.order_id) AS DECIMAL(10,2)) AS AverageOrderValue
FROM customers C
INNER JOIN orders O
ON C.customer_id = O.customer_id
INNER JOIN order_items I
ON I.order_id = O.order_id
GROUP BY C.customer_state
ORDER BY AverageOrderValue DESC

-------------------------------------------------Customer State Performance

WITH BaseData AS

(
	SELECT
		O.order_status,
		COUNT(*) AS CountOFOrders
	FROM orders O
	GROUP BY O.order_status
),

TotalOrder AS
(
	SELECT SUM(CountOFOrders) AS Total FROM BaseData
)

SELECT
	B.order_status,
	B.CountOFOrders,
	CAST(CAST(B.CountOFOrders AS FLOAT) / T.Total * 100 AS DECIMAL(10,2)) AS ProportionOfOrders
FROM BaseData B
CROSS JOIN TotalOrder T
ORDER BY ProportionOfOrders DESC

----------------------------------------------Review Performance by Product Category

WITH BaseData AS

(
SELECT
	COALESCE(T.product_category_name_english,P.product_category_name,'Unavailable') AS ProductCategory,
	COUNT(DISTINCT R.review_id) AS TotalReviews,
	AVG(R.review_score) AS AverageReviewScore,
	SUM(
		CASE
			WHEN R.review_score <= 2
				THEN 1
			ELSE 0
		END
	) AS TotalOfBadReview
FROM products P
LEFT JOIN category_translation T
ON P.product_category_name = T.product_category_name
INNER JOIN order_items I
ON P.product_id = I.product_id
INNER JOIN reviews R
ON R.order_id = I.order_id
GROUP BY T.product_category_name_english,P.product_category_name
)

SELECT
	B.ProductCategory,
	B.TotalReviews,
	B.AverageReviewScore,
	CAST(CAST(B.TotalOfBadReview AS FLOAT) / B.TotalReviews * 100 AS DECIMAL(10,2)) AS PercentageOfBadReviews
FROM BaseData B
ORDER BY PercentageOfBadReviews DESC


------------------------------------

WITH OrderCategory AS

(
	SELECT
		DISTINCT order_id,
		COALESCE(T.product_category_name_english,P.product_category_name,'Unavailable') AS ProductCategory
	FROM products P
	LEFT JOIN category_translation T
	ON P.product_category_name = T.product_category_name
	INNER JOIN order_items I
	ON I.product_id = P.product_id
),

ReviewData AS

(
	SELECT
		O.ProductCategory,
		R.review_id,
		R.review_score,
		O.order_id
	FROM OrderCategory O
	INNER JOIN reviews R
	ON O.order_id = R.order_id
)

SELECT
	ProductCategory,
	COUNT(*) AS TotalReviews,
	AVG(review_score) AS AverageReviewScore,

	SUM(
		CASE	
			WHEN review_score <= 2
				THEN 1
			ELSE 0
		END
	) AS TotalBadReviews,

	CAST(
		SUM(
			CASE	
				WHEN review_score <= 2
					THEN 1
				ELSE 0
			END
		)
	/
	CAST(COUNT(*) AS FLOAT) * 100 AS DECIMAL(10,2)) AS BadReviewPercentage
FROM ReviewData
GROUP BY ProductCategory

------------------------------------Pivot

WITH OrderCategory AS

(
	SELECT
		DISTINCT order_id,
		COALESCE(T.product_category_name_english,P.product_category_name,'Unavailable') AS ProductCategory
	FROM products P
	LEFT JOIN category_translation T
	ON P.product_category_name = T.product_category_name
	INNER JOIN order_items I
	ON I.product_id = P.product_id
),

ReviewData AS

(
	SELECT
		O.ProductCategory,
		R.review_id,
		R.review_score,
		O.order_id
	FROM OrderCategory O
	INNER JOIN reviews R
	ON O.order_id = R.order_id
)

SELECT
    ProductCategory,
    [1],
    [2],
    [3],
    [4],
    [5]
FROM
(
    SELECT
        ProductCategory,
        review_score,
        review_id
    FROM ReviewData
) AS SourceTable
PIVOT
(
    COUNT(review_id)
    FOR review_score IN ([1], [2], [3], [4], [5])
) AS PivotTable;


-----------------------------------Payment Behaviour Analysis

WITH BaseData AS

(
	SELECT
		payment_type,
		COUNT(*) AS TotalPaymentRecords,
		COUNT(DISTINCT order_id) AS TotalDistinctOrders,
		SUM(payment_value) AS TotalPaymentValue,
		CAST(AVG(payment_value) AS DECIMAL(10,2)) AS AveragePaymentValue,
		CAST(AVG(CAST(payment_installments AS FLOAT)) AS DECIMAL(10,2)) AS AverageInstalments,
		MAX(payment_installments) AS MaximumInstalments,
		MIN(payment_installments) AS MinimumInstalments
	FROM payments
	GROUP BY payment_type
),

TotalPayment AS

(
	SELECT
		SUM(TotalPaymentValue) AS TotalPayment
	FROM BaseData
)

SELECT
	B.payment_type,
	B.TotalPaymentRecords,
	B.TotalDistinctOrders,
	B.TotalPaymentValue,
	B.AveragePaymentValue,
	CAST(B.TotalPaymentValue / T.TotalPayment * 100 AS DECIMAL(10,2)) AS PaymentContributionPercentage,
	AverageInstalments,
	MaximumInstalments,
	MinimumInstalments
FROM BaseData B
CROSS JOIN TotalPayment T
ORDER BY PaymentContributionPercentage DESC