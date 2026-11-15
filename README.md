# Olist Brazilian E-Commerce Data Analytics Project

## Project Overview

An end-to-end data analytics portfolio project exploring the Brazilian e-commerce marketplace using the Olist public dataset.

The project analyses sales performance, customer purchasing behaviour, payment methods, seller performance and delivery operations to identify business trends and actionable insights.

The project follows a complete analytics workflow, from Python-based data preparation and SQL analysis to interactive Power BI reporting.

## Tools & Technologies

- **Python:** Data exploration, cleaning and preparation using Pandas.
- **SQL Server:** Relational database development, data quality checks, business analysis and reusable SQL views.
- **Power BI:** Data modelling, DAX measures, interactive slicers and dashboard visualisation.

## Business Objectives

- Evaluate overall sales and order performance.
- Understand customer purchasing frequency and revenue segments.
- Analyse payment methods and customer preferences.
- Evaluate seller performance and geographic distribution.
- Monitor delivery performance and identify operational issues.
- Identify trends and opportunities for business improvement.

## Project Workflow

1. **Data Preparation:** Explored, cleaned and prepared the source datasets using Python and Pandas.
2. **Database Development:** Loaded the prepared datasets into SQL Server and established relational connections.
3. **Data Quality & Analysis:** Performed data validation, quality checks and business analysis using SQL.
4. **SQL Views:** Developed and validated 18 active SQL views to support Power BI reporting.
5. **Power BI Development:** Created the data model, DAX measures, interactive date slicers and dashboard visuals.
6. **Business Insights:** Analysed the results and developed recommendations based on the findings.

**Architecture:** Python (Pandas) → SQL Server → Power BI

SQL views handle the core reporting calculations and aggregations, while Power BI focuses primarily on interactive visualisation and analysis.

## Key Business Findings

- **Total Orders:** 99,441
- **Delivered Orders:** 96,478
- **Unique Customers:** 96,096
- **Total Sellers:** 3,095
- **Total Sales Value:** R$15.84 million
- **Average Order Value:** R$160.58
- Credit cards contributed approximately **78.34%** of total payment value.
- Approximately **3.12%** of customers were repeat customers.
- November 2017 recorded the highest monthly sales value at approximately **R$1.18 million**.

## Power BI Dashboard

The interactive dashboard contains three report pages:

### 1. Executive Overview
- Overall business KPIs.
- Monthly sales performance and trends.
- Order status distribution.
- Payment method analysis and insights.

### 2. Customer & Sales Insights
- Customer purchasing frequency.
- Customer revenue segmentation.
- Customer behaviour and repeat purchase analysis.

### 3. Delivery & Operations Performance
- Delivery performance KPIs.
- On-time and late delivery analysis.
- Freight costs by customer state.
- Monthly seller performance.

The report includes a synced date slicer that allows users to analyse specific time periods across all three pages.

**Dashboard files and screenshots:**
- [Power BI Dashboard](Olist_Ecommerce_Dashboard.pbix)
- [Dashboard Screenshots](screenshots/)

## Business Recommendations

- Develop customer retention strategies to encourage repeat purchases.
- Investigate the causes of late deliveries and improve logistics coordination.
- Monitor seller performance to identify operational improvement opportunities.
- Review payment preferences to improve the customer payment experience.
- Use monthly sales trends to support business planning and forecasting.

## Repository Structure

```text
olist-ecommerce-data-analytics/
│
├── README.md
├── Olist_Ecommerce_Dashboard.pbix
│
├── screenshots/
│   ├── Executive Overview
│   ├── Customer & Sales Insights
│   └── Delivery & Operations Performance
│
├── python/
│   └── data_cleaning/
│       └── 01_Olist_Data_Exploration_GitHub.ipynb
│
└── sql/
    ├── 01_database_setup/
    │   ├── Table_Inspection_Query.sql
    │   ├── Table_Modification_Query.sql
    │   └── PrimaryKey_ForeignKey.sql
    │
    ├── 02_business_analysis/
    │   └── SQL_Business_Analysis.sql
    │
    └── 03_powerbi_views/
        └── Final_Active_PowerBI_Views.sql
```

## Dataset

The project uses the **Brazilian E-Commerce Public Dataset by Olist**, a public dataset containing information about orders, customers, sellers, products, payments, reviews and delivery.

The original dataset covers transactions from 2016 to 2018.

## Project Status

- Python data exploration notebook completed and published.
- SQL database development and business analysis completed.
- 18 active Power BI SQL views validated.
- Three-page interactive Power BI dashboard completed.
- GitHub portfolio documentation and publishing in progress.
