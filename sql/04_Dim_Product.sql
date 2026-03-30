-- ============================================================
-- 04_Dim_Product.sql
-- 商品維度主檔｜11,308 rows (8,094 + 3,214)
-- ============================================================
--
-- [建構邏輯]
-- 以品牌編號（BrandID）為主鍵，代表一個獨立商品品項，不區分門市。
-- 分兩批建立以確保維度完整性：
--   Batch 1: 8,094 筆 ← BegInventory（含標準售價）
--   Batch 2: 3,214 筆 ← SalesInvoices 補入（有銷售但無期初庫存的品牌）
--
-- [售價估算]
-- 第二批品牌的售價以 MAX(SalesPrice) 估算，
-- 取最高成交價而非平均，因為銷售價格可能因折扣而偏低，MAX 最接近標準售價。
--
-- [後期補入供應商欄位]
-- 初始版本沒有供應商欄位，導致 Dim_Vendor 在 Power BI 中孤立。
-- 後期透過 ALTER TABLE 新增，以最近一筆進貨的供應商填入。
-- 29 個有多個供應商的品牌 → 取最近收貨日期的供應商
-- 821 個無進貨紀錄的品牌 → 供應商保持 NULL（均為 C 級）
-- ============================================================


-- ────────────────────────────────────────
-- Batch 1: brands from opening inventory (8,094 rows)
-- Use ROW_NUMBER to deduplicate (same brand appears in multiple stores)
-- ────────────────────────────────────────
WITH RankedProducts AS (
    SELECT
        REPLACE(["Brand"], '"', '')                            AS 品牌編號,
        REPLACE(["Description"], '"', '')                      AS 品項名稱,
        REPLACE(["Size"], '"', '')                             AS 規格,
        CAST(REPLACE(["Price"], '"', '') AS DECIMAL(10,2))     AS 售價,
        ROW_NUMBER() OVER (
            PARTITION BY REPLACE(["Brand"], '"', '')
            ORDER BY REPLACE(["Brand"], '"', '')
        ) AS rn
    FROM dbo.BegInventory
)
INSERT INTO dbo.Dim_Product (品牌編號, 品項名稱, 規格, 售價)
SELECT 品牌編號, 品項名稱, 規格, 售價
FROM RankedProducts
WHERE rn = 1;


-- ────────────────────────────────────────
-- Batch 2: brands with sales but no opening inventory (3,214 rows)
-- Price estimated using MAX(SalesPrice) — closest to list price
-- ────────────────────────────────────────
INSERT INTO dbo.Dim_Product (品牌編號, 品項名稱, 規格, 售價)
SELECT
    REPLACE(["Brand"], '"', ''),
    MAX(REPLACE(["Description"], '"', '')),
    MAX(REPLACE(["Size"], '"', '')),
    MAX(CAST(REPLACE(["SalesPrice"], '"', '') AS DECIMAL(10,2)))
FROM dbo.SalesInvoices
WHERE REPLACE(["Brand"], '"', '') NOT IN (SELECT 品牌編號 FROM dbo.Dim_Product)
GROUP BY REPLACE(["Brand"], '"', '');


-- ────────────────────────────────────────
-- Post-build: add vendor column and populate
-- ────────────────────────────────────────
ALTER TABLE dbo.Dim_Product ADD 供應商編號 INT NULL;

WITH 最近供應商 AS (
    SELECT
        CAST(REPLACE(["Brand"], '"', '') AS VARCHAR)            AS 品牌編號,
        CAST(REPLACE(["VendorNumber"], '"', '') AS INT)         AS 供應商編號,
        ROW_NUMBER() OVER (
            PARTITION BY REPLACE(["Brand"], '"', '')
            ORDER BY TRY_CAST(REPLACE(["ReceivingDate"], '"', '') AS DATE) DESC
        ) AS rn
    FROM dbo.PurchaseOrders
    WHERE TRY_CAST(REPLACE(["ReceivingDate"], '"', '') AS DATE) IS NOT NULL
)
UPDATE p
SET p.供應商編號 = s.供應商編號
FROM dbo.Dim_Product p
INNER JOIN 最近供應商 s
    ON s.品牌編號 = p.品牌編號
    AND s.rn = 1;
