-- ============================================================
-- 09_Dim_LeadTime.sql
-- 品牌交期維度表｜10,664 rows
-- ============================================================
--
-- [建構邏輯]
-- 從 PurchaseOrders 計算每品牌每筆訂單的交期（收貨日 − 訂購日），
-- 再依品牌分組取平均值、最小值和最大值。
--
-- [遭遇問題 — 最重要的資料品質處理]
--
-- ⚠️ 日期格式混用問題：
-- PurchaseOrders 的 PODate 和 ReceivingDate 欄位混用兩種格式：
--   大部分：標準字串日期（如 "2015-12-21"）
--   部  分：Excel 數字序列格式（如 "10547"，從 1900-01-01 起算天數）
-- 當 Excel 序列被當成字串處理時，TRY_CAST 失敗，DATEDIFF 算出荒謬結果。
-- → 54 個品牌的平均交期超過 30,000 天（約 88 年）
--
-- 處理方案：
--   1. 實作雙格式轉換（TRY_CAST 優先 → DATEADD fallback）
--   2. 清除後仍有 54 品牌平均交期 > 180 天 → 確認為無法修復的異常
--   3. 刪除這 54 筆，以全體平均交期 7 天補入估算值
--   4. 補入的 54 筆將訂單筆數設為 NULL 作為估算標記
--
-- 💡 正常交期分布：最短 3 天，最長 14 天，整體平均 7 天，
--    符合一般零售業補貨週期。
-- ============================================================


-- ────────────────────────────────────────
-- Main query: dual-format date conversion + lead time calculation
-- ────────────────────────────────────────
WITH CleanDates AS (
    SELECT
        REPLACE(["Brand"], '"', '') AS 品牌編號,
        -- Handle standard string dates AND Excel serial numbers
        CASE
            WHEN TRY_CAST(REPLACE(["PODate"], '"', '') AS DATE) IS NOT NULL
                THEN TRY_CAST(REPLACE(["PODate"], '"', '') AS DATE)
            WHEN TRY_CAST(REPLACE(["PODate"], '"', '') AS INT) IS NOT NULL
                THEN DATEADD(DAY,
                     CAST(REPLACE(["PODate"], '"', '') AS INT) - 2,
                     '1900-01-01')
            ELSE NULL
        END AS PODate,
        CASE
            WHEN TRY_CAST(REPLACE(["ReceivingDate"], '"', '') AS DATE) IS NOT NULL
                THEN TRY_CAST(REPLACE(["ReceivingDate"], '"', '') AS DATE)
            WHEN TRY_CAST(REPLACE(["ReceivingDate"], '"', '') AS INT) IS NOT NULL
                THEN DATEADD(DAY,
                     CAST(REPLACE(["ReceivingDate"], '"', '') AS INT) - 2,
                     '1900-01-01')
            ELSE NULL
        END AS ReceivingDate
    FROM dbo.PurchaseOrders
)

INSERT INTO dbo.Dim_LeadTime (品牌編號, 平均交期天數, 最短交期天數, 最長交期天數, 訂單筆數)
SELECT
    品牌編號,
    AVG(DATEDIFF(DAY, PODate, ReceivingDate)) AS 平均交期天數,
    MIN(DATEDIFF(DAY, PODate, ReceivingDate)) AS 最短交期天數,
    MAX(DATEDIFF(DAY, PODate, ReceivingDate)) AS 最長交期天數,
    COUNT(*)                                   AS 訂單筆數
FROM CleanDates
WHERE PODate IS NOT NULL AND ReceivingDate IS NOT NULL
GROUP BY 品牌編號;


-- ────────────────────────────────────────
-- Post-build: remove anomalous brands and backfill with estimate
-- ────────────────────────────────────────

-- Remove 54 brands with avg lead time > 180 days (unfixable data anomaly)
DELETE FROM dbo.Dim_LeadTime WHERE 平均交期天數 > 180;

-- Backfill with overall average of 7 days
-- NULL order count serves as a marker for estimated values
INSERT INTO dbo.Dim_LeadTime (品牌編號, 平均交期天數, 訂單筆數)
SELECT 品牌編號, 7, NULL
FROM (
    -- List of 54 anomalous brands previously deleted
    SELECT DISTINCT 品牌編號
    FROM dbo.Dim_Brand_Grade
    WHERE 品牌編號 NOT IN (SELECT 品牌編號 FROM dbo.Dim_LeadTime)
) anomalous;
