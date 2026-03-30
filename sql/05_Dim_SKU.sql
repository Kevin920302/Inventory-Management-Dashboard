-- ============================================================
-- 05_Dim_SKU.sql
-- 門市商品橋接表｜275,401 rows (206,529 + 64,044 + 4,828)
-- ============================================================
--
-- [建構邏輯]
-- SKU 格式為「門市編號_城市_品牌編號」（如 1_HARDERSFIELD_1001），
-- 本身隱含門市與品牌資訊。此表作為橋接，讓星型模型能同時從
-- Dim_Store（門市）和 Dim_Product（品牌）兩個維度篩選事實表。
--
-- 💡 若沒有 Dim_SKU，Dim_Store 和 Dim_Product 就無法同時作用在
--    RecentInventory 上，因為 RecentInventory 只有 SKU 編號，
--    沒有直接的品牌編號欄位。
--
-- 分三批建立以確保所有 SKU 都被涵蓋：
--   Batch 1: 206,529 筆 ← BegInventory
--   Batch 2:  64,044 筆 ← SalesInvoices（有銷售但不在期初庫存）
--   Batch 3:   4,828 筆 ← PurchaseOrders（有進貨但不在前兩批）
-- ============================================================


-- Batch 1: SKUs from opening inventory (206,529 rows)
INSERT INTO dbo.Dim_SKU (SKU編號, 門市編號, 品牌編號)
SELECT DISTINCT
    REPLACE(["InventoryId"], '"', ''),
    CAST(REPLACE(["Store"], '"', '') AS INT),
    REPLACE(["Brand"], '"', '')
FROM dbo.BegInventory;


-- Batch 2: SKUs with sales but not in opening inventory (64,044 rows)
INSERT INTO dbo.Dim_SKU (SKU編號, 門市編號, 品牌編號)
SELECT DISTINCT
    REPLACE(["InventoryId"], '"', ''),
    CAST(REPLACE(["Store"], '"', '') AS INT),
    REPLACE(["Brand"], '"', '')
FROM dbo.SalesInvoices
WHERE REPLACE(["InventoryId"], '"', '')
    NOT IN (SELECT SKU編號 FROM dbo.Dim_SKU);


-- Batch 3: SKUs with purchases but not in previous batches (4,828 rows)
INSERT INTO dbo.Dim_SKU (SKU編號, 門市編號, 品牌編號)
SELECT DISTINCT
    REPLACE(["InventoryId"], '"', ''),
    CAST(REPLACE(["Store"], '"', '') AS INT),
    REPLACE(["Brand"], '"', '')
FROM dbo.PurchaseOrders
WHERE REPLACE(["InventoryId"], '"', '')
    NOT IN (SELECT SKU編號 FROM dbo.Dim_SKU);
