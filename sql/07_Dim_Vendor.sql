-- ============================================================
-- 07_Dim_Vendor.sql
-- 供應商維度主檔｜129 rows
-- ============================================================
--
-- [建構邏輯]
-- 兩張原始表的供應商欄位名稱不同：
--   PurchaseOrders → VendorNumber / VendorName
--   SalesInvoices  → VendorNo / VendorName
-- 使用 UNION 合併後取 DISTINCT。
--
-- 透過 Dim_Product[供應商編號] → Dim_Vendor[供應商編號] 建立 1:多 關聯。
-- ============================================================


INSERT INTO dbo.Dim_Vendor (供應商編號, 供應商名稱)
SELECT DISTINCT
    CAST(REPLACE(["VendorNumber"], '"', '') AS INT),
    REPLACE(["VendorName"], '"', '')
FROM dbo.PurchaseOrders
UNION
SELECT DISTINCT
    CAST(REPLACE(["VendorNo"], '"', '') AS INT),
    REPLACE(["VendorName"], '"', '')
FROM dbo.SalesInvoices;
