
USE Olist_Ecommerce;
GO

-- =============================================
-- PAGE 1: EXECUTIVE OVERVIEW
-- =============================================

CREATE OR ALTER VIEW dbo.vw_ExecutiveKPIs
AS
SELECT
    (SELECT COUNT(*) FROM dbo.orders) AS TotalOrders,
    (SELECT COUNT(*) FROM dbo.orders WHERE order_status = 'delivered') AS DeliveredOrders,
    (SELECT COUNT(DISTINCT customer_unique_id) FROM dbo.customers) AS TotalCustomers,
    (SELECT COUNT(*) FROM dbo.sellers) AS TotalSellers,
    (SELECT CAST(SUM(price + freight_value) AS DECIMAL(18,2)) FROM dbo.order_items) AS TotalSalesValue,
    (SELECT CAST(SUM(price + freight_value) / NULLIF(COUNT(DISTINCT order_id), 0) AS DECIMAL(18,2)) FROM dbo.order_items) AS AverageOrderValue;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyExecutiveKPIs
AS
SELECT
    DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
    COUNT(DISTINCT O.order_id) AS TotalOrders,
    COUNT(DISTINCT CASE WHEN O.order_status = 'delivered' THEN O.order_id END) AS DeliveredOrders,
    COUNT(DISTINCT C.customer_unique_id) AS TotalCustomers,
    COUNT(DISTINCT I.seller_id) AS TotalSellers,
    CAST(SUM(I.price + I.freight_value) AS DECIMAL(18,2)) AS TotalSalesValue,
    CAST(SUM(I.price + I.freight_value) / NULLIF(COUNT(DISTINCT I.order_id), 0) AS DECIMAL(18,2)) AS AverageOrderValue
FROM dbo.orders O
LEFT JOIN dbo.customers C ON O.customer_id = C.customer_id
LEFT JOIN dbo.order_items I ON O.order_id = I.order_id
WHERE O.order_purchase_timestamp IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1);
GO

CREATE OR ALTER VIEW dbo.vw_MonthlySalesPerformance
AS
WITH RequiredDate AS
(
    SELECT
        DATEADD(DAY, 1, EOMONTH(MIN(O.order_purchase_timestamp), -1)) AS StartMonth,
        DATEADD(DAY, 1, EOMONTH(MAX(O.order_purchase_timestamp), -1)) AS EndMonth
    FROM dbo.orders O
    INNER JOIN dbo.order_items I ON O.order_id = I.order_id
),
CalendarMonth AS
(
    SELECT StartMonth, EndMonth
    FROM RequiredDate
    UNION ALL
    SELECT DATEADD(MONTH, 1, StartMonth), EndMonth
    FROM CalendarMonth
    WHERE StartMonth < EndMonth
),
BaseData AS
(
    SELECT
        LEFT(DATENAME(MONTH, O.order_purchase_timestamp), 3) + '''' +
        RIGHT(DATEPART(YEAR, O.order_purchase_timestamp), 2) AS MonthYear,
        DATEADD(DAY, 1, EOMONTH(O.order_purchase_timestamp, -1)) AS DateSort,
        I.order_item_id,
        I.order_id,
        I.price,
        I.freight_value
    FROM dbo.orders O
    INNER JOIN dbo.order_items I ON O.order_id = I.order_id
),
MonthlyTrend AS
(
    SELECT
        MonthYear,
        COUNT(DISTINCT order_id) AS TotalNumberOfOrders,
        COUNT(order_id) AS TotalQuantitySold,
        COALESCE(SUM(price + freight_value), 0) AS TotalSalesValue,
        DateSort
    FROM BaseData
    GROUP BY MonthYear, DateSort
),
FinalData AS
(
    SELECT
        LEFT(DATENAME(MONTH, C.StartMonth), 3) + '''' +
        RIGHT(DATEPART(YEAR, C.StartMonth), 2) AS MonthYear,
        COALESCE(M.TotalNumberOfOrders, 0) AS TotalNumberOfOrders,
        COALESCE(M.TotalQuantitySold, 0) AS TotalQuantitySold,
        COALESCE(M.TotalSalesValue, 0) AS TotalSalesValue,
        LAG(COALESCE(M.TotalSalesValue, 0)) OVER (ORDER BY C.StartMonth) AS PrevMonthSales,
        CAST(LAG(COALESCE(M.TotalNumberOfOrders, 0)) OVER (ORDER BY C.StartMonth) AS FLOAT) AS PrevMonthOrders,
        CAST(LAG(COALESCE(M.TotalQuantitySold, 0)) OVER (ORDER BY C.StartMonth) AS FLOAT) AS PrevMonthQuantity,
        C.StartMonth AS DateSort
    FROM CalendarMonth C
    LEFT JOIN MonthlyTrend M ON C.StartMonth = M.DateSort
)
SELECT
    MonthYear,
    DateSort,
    TotalSalesValue,
    PrevMonthSales,
    ROUND((TotalSalesValue - PrevMonthSales) / NULLIF(PrevMonthSales, 0) * 100, 2) AS MonthlyGrowthPercent,
    TotalNumberOfOrders,
    PrevMonthOrders,
    ROUND((TotalNumberOfOrders - PrevMonthOrders) / NULLIF(PrevMonthOrders, 0) * 100, 2) AS MonthlyOrderGrowthPercent,
    TotalQuantitySold,
    PrevMonthQuantity,
    ROUND((TotalQuantitySold - PrevMonthQuantity) / NULLIF(PrevMonthQuantity, 0) * 100, 2) AS MonthlyQuantityGrowthPercent
FROM FinalData;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyOrderStatusDistribution
AS
SELECT
    DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS MonthStart,
    order_status AS OrderStatus,
    COUNT(DISTINCT order_id) AS TotalOrders
FROM dbo.orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1), order_status;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyPaymentMethodPerformance
AS
SELECT
    DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
    P.payment_type AS PaymentMethod,
    COUNT(DISTINCT P.order_id) AS TotalOrders,
    SUM(P.payment_value) AS TotalPaymentValue
FROM dbo.payments P
INNER JOIN dbo.orders O ON P.order_id = O.order_id
WHERE O.order_purchase_timestamp IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1), P.payment_type;
GO

CREATE OR ALTER VIEW dbo.vw_PaymentMethodPerformance
AS
WITH PaymentSummary AS
(
    SELECT
        payment_type AS PaymentMethod,
        SUM(payment_value) AS TotalPaymentValue,
        COUNT(DISTINCT order_id) AS TotalOrders
    FROM dbo.payments
    GROUP BY payment_type
)
SELECT
    PaymentMethod,
    TotalPaymentValue,
    TotalOrders,
    CAST(TotalPaymentValue * 100.0 / SUM(TotalPaymentValue) OVER() AS DECIMAL(5,2)) AS PaymentContributionPercent
FROM PaymentSummary;
GO

-- =============================================
-- PAGE 2: CUSTOMER & SALES INSIGHTS
-- =============================================

CREATE OR ALTER VIEW dbo.vw_CustomerInsightsKPIs
AS
SELECT
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN TotalNumberOfOrders > 1 THEN 1 ELSE 0 END) AS RepeatCustomers,
    CAST(SUM(CASE WHEN TotalNumberOfOrders > 1 THEN 1.0 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS RepeatCustomerPercent,
    CAST(AVG(CAST(TotalNumberOfOrders AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS AverageOrdersPerCustomer
FROM dbo.vw_CustomerPerformance;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyCustomerInsightsKPIs
AS
WITH MonthlyCustomerOrders AS
(
    SELECT
        DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
        C.customer_unique_id,
        COUNT(DISTINCT O.order_id) AS TotalNumberOfOrders
    FROM dbo.orders O
    INNER JOIN dbo.customers C ON O.customer_id = C.customer_id
    WHERE O.order_purchase_timestamp IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1), C.customer_unique_id
)
SELECT
    MonthStart,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN TotalNumberOfOrders > 1 THEN 1 ELSE 0 END) AS RepeatCustomers,
    CAST(SUM(CASE WHEN TotalNumberOfOrders > 1 THEN 1.0 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)) AS RepeatCustomerPercent,
    CAST(AVG(TotalNumberOfOrders * 1.0) AS DECIMAL(10,2)) AS AverageOrdersPerCustomer
FROM MonthlyCustomerOrders
GROUP BY MonthStart;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyCustomerPurchaseFrequency
AS
WITH MonthlyCustomerOrders AS
(
    SELECT
        DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
        C.customer_unique_id,
        COUNT(DISTINCT O.order_id) AS PurchaseFrequency
    FROM dbo.orders O
    INNER JOIN dbo.customers C ON O.customer_id = C.customer_id
    WHERE O.order_purchase_timestamp IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1), C.customer_unique_id
)
SELECT
    MonthStart,
    CASE WHEN PurchaseFrequency >= 3 THEN '3+ Orders'
         ELSE CONCAT(PurchaseFrequency, ' Order(s)') END AS PurchaseFrequency,
    CASE WHEN PurchaseFrequency >= 3 THEN 3 ELSE PurchaseFrequency END AS FrequencySort,
    COUNT(*) AS TotalCustomers
FROM MonthlyCustomerOrders
GROUP BY
    MonthStart,
    CASE WHEN PurchaseFrequency >= 3 THEN '3+ Orders'
         ELSE CONCAT(PurchaseFrequency, ' Order(s)') END,
    CASE WHEN PurchaseFrequency >= 3 THEN 3 ELSE PurchaseFrequency END;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyCustomerRevenueSegment
AS
WITH MonthlyCustomerSpending AS
(
    SELECT
        DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
        C.customer_unique_id,
        SUM(I.price + I.freight_value) AS TotalSpending
    FROM dbo.orders O
    INNER JOIN dbo.customers C ON O.customer_id = C.customer_id
    INNER JOIN dbo.order_items I ON O.order_id = I.order_id
    WHERE O.order_purchase_timestamp IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1), C.customer_unique_id
),
CustomerSegments AS
(
    SELECT
        MonthStart,
        customer_unique_id,
        TotalSpending,
        CASE
            WHEN TotalSpending < 500 THEN 'Low Value'
            WHEN TotalSpending < 2000 THEN 'Medium Value'
            ELSE 'High Value'
        END AS CustomerSegment
    FROM MonthlyCustomerSpending
),
SegmentSummary AS
(
    SELECT
        MonthStart,
        CustomerSegment,
        COUNT(*) AS TotalCustomers,
        SUM(TotalSpending) AS TotalRevenue
    FROM CustomerSegments
    GROUP BY MonthStart, CustomerSegment
)
SELECT
    MonthStart,
    CustomerSegment,
    TotalCustomers,
    CAST(TotalRevenue AS DECIMAL(18,2)) AS TotalRevenue,
    CAST(TotalRevenue * 100.0 / NULLIF(SUM(TotalRevenue) OVER(PARTITION BY MonthStart), 0) AS DECIMAL(6,2)) AS RevenueContributionPercent
FROM SegmentSummary;
GO

-- =============================================
-- PAGE 3: DELIVERY & OPERATIONS PERFORMANCE
-- =============================================

CREATE OR ALTER VIEW dbo.vw_DeliveryKPIs
AS
SELECT
    COUNT(DISTINCT CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
        THEN order_id END) AS DeliveredOrders,

    COUNT(DISTINCT CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date <= order_estimated_delivery_date
        THEN order_id END) AS OnTimeOrders,

    COUNT(DISTINCT CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date > order_estimated_delivery_date
        THEN order_id END) AS LateOrders,

    CAST(AVG(CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date IS NOT NULL
         AND order_purchase_timestamp IS NOT NULL
        THEN DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) * 1.0
    END) AS DECIMAL(10,2)) AS AverageDeliveryDays
FROM dbo.orders;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyDeliveryKPIs
AS
SELECT
    DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS MonthStart,

    COUNT(DISTINCT CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
        THEN order_id END) AS DeliveredOrdersWithValidDates,

    COUNT(DISTINCT CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
         AND order_delivered_customer_date <= order_estimated_delivery_date
        THEN order_id END) AS OnTimeOrders,

    COUNT(DISTINCT CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
         AND order_delivered_customer_date > order_estimated_delivery_date
        THEN order_id END) AS LateOrders,

    CAST(AVG(CASE
        WHEN order_status = 'delivered'
         AND order_delivered_customer_date IS NOT NULL
         AND order_purchase_timestamp IS NOT NULL
        THEN DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) * 1.0
    END) AS DECIMAL(10,2)) AS AverageDeliveryDays
FROM dbo.orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1);
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyDeliveryPerformance
AS
WITH MonthlyData AS
(
    SELECT
        DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS DateSort,
        COUNT(DISTINCT CASE
            WHEN order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN order_id END) AS DeliveredOrders,
        COUNT(DISTINCT CASE
            WHEN order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date <= order_estimated_delivery_date
            THEN order_id END) AS OnTimeOrders,
        COUNT(DISTINCT CASE
            WHEN order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date > order_estimated_delivery_date
            THEN order_id END) AS LateOrders
    FROM dbo.orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1)
)
SELECT
    FORMAT(DateSort, 'MMM') + '''' + RIGHT(CAST(YEAR(DateSort) AS VARCHAR(4)), 2) AS MonthYear,
    DateSort,
    DeliveredOrders,
    OnTimeOrders,
    LateOrders,
    CAST(OnTimeOrders * 100.0 / NULLIF(DeliveredOrders, 0) AS DECIMAL(6,2)) AS OnTimeDeliveryPercent
FROM MonthlyData;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlyFreightByCustomerState
AS
SELECT
    DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
    C.customer_state AS CustomerState,
    COUNT(DISTINCT O.order_id) AS TotalOrders,
    CAST(SUM(I.freight_value) AS DECIMAL(18,2)) AS TotalFreightValue,
    CAST(SUM(I.freight_value) / NULLIF(COUNT(DISTINCT O.order_id), 0) AS DECIMAL(18,2)) AS AverageFreightPerOrder
FROM dbo.orders O
INNER JOIN dbo.customers C ON O.customer_id = C.customer_id
INNER JOIN dbo.order_items I ON O.order_id = I.order_id
WHERE O.order_purchase_timestamp IS NOT NULL
GROUP BY
    DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1),
    C.customer_state;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlySellerPerformance
AS
SELECT
    DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1) AS MonthStart,
    I.seller_id AS SellerID,
    LEFT(I.seller_id, 8) + '...' AS SellerShortID,
    COUNT(DISTINCT O.order_id) AS TotalOrders,
    COUNT(*) AS TotalItemsSold,
    CAST(SUM(I.price + I.freight_value) AS DECIMAL(18,2)) AS TotalSalesValue
FROM dbo.orders O
INNER JOIN dbo.order_items I ON O.order_id = I.order_id
WHERE O.order_purchase_timestamp IS NOT NULL
GROUP BY
    DATEFROMPARTS(YEAR(O.order_purchase_timestamp), MONTH(O.order_purchase_timestamp), 1),
    I.seller_id;
GO

-- =============================================
-- VERIFY THE 15 ACTIVE VIEWS
-- =============================================

SELECT
    name AS ViewName,
    'Available' AS ViewStatus
FROM sys.views
WHERE schema_id = SCHEMA_ID('dbo')
  AND name IN
  (
      'vw_ExecutiveKPIs',
      'vw_MonthlyExecutiveKPIs',
      'vw_MonthlySalesPerformance',
      'vw_MonthlyOrderStatusDistribution',
      'vw_MonthlyPaymentMethodPerformance',
      'vw_PaymentMethodPerformance',
      'vw_CustomerInsightsKPIs',
      'vw_MonthlyCustomerInsightsKPIs',
      'vw_MonthlyCustomerPurchaseFrequency',
      'vw_MonthlyCustomerRevenueSegment',
      'vw_DeliveryKPIs',
      'vw_MonthlyDeliveryKPIs',
      'vw_MonthlyDeliveryPerformance',
      'vw_MonthlyFreightByCustomerState',
      'vw_MonthlySellerPerformance'
  )
ORDER BY name;
GO
