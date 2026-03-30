-- ============================================================
-- 00_raw_data_cleaning.sql
-- 原始資料系統性清洗說明｜Raw Data Systematic Cleaning
-- ============================================================
-- 
-- 三張原始 CSV 匯入 SQL Server 後存在兩個一致的格式問題：
-- 1. 欄位名稱含雙引號 → 必須使用方括號語法存取
-- 2. 欄位值含雙引號，且所有型態皆為 VARCHAR → 需先去引號再轉型
-- 
-- 本專案不修改原始儲存內容，全部在查詢層處理，確保資料可追溯性。
-- ============================================================

-- ❌ Wrong: column names contain literal double quotes
SELECT Brand, VendorNumber FROM dbo.PurchaseOrders;

-- ✅ Correct: use bracket syntax to reference quoted column names
SELECT ["Brand"], ["VendorNumber"] FROM dbo.PurchaseOrders;


-- Standard cleaning template applied to ALL raw columns throughout this project
-- Date fields
CAST(REPLACE(["date_column"],    '"', '') AS DATE)

-- Integer fields
CAST(REPLACE(["quantity_column"], '"', '') AS INT)

-- Decimal fields
CAST(REPLACE(["amount_column"],  '"', '') AS DECIMAL(10,2))
