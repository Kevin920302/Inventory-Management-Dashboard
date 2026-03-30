-- ============================================================
-- 03_MonthlyInventorySummary.sql
-- 月層級銷售與庫存彙總｜2,119,239 rows
-- ============================================================
--
-- [建構邏輯]
-- SalesInvoices 有 1,000 萬筆銷售明細，每次計算月銷售量都要全表掃描，
-- Power BI 的互動效能會非常差。此表將銷售和庫存預先彙總到月層級，
-- 讓月度分析指標（週轉率、趨勢、熱力圖）都能在毫秒內回應。
--
-- 來源分兩部分 JOIN：
--   1. 銷售量/額 ← SalesInvoices（按門市、SKU、年月分組）
--   2. 月初/月末/月平均庫存 ← DailyInventorySnapshot（按門市、SKU、年月分組）
--
-- [NULL 值說明 — 11.65%]
-- 246,831 筆的月庫存欄位為 NULL。
-- 這些屬於有銷售但期初庫存無紀錄的 3,214 個品牌（多為 C 級低貢獻品牌），
-- 在 Power BI 中以「資料不足」標示，不強制補 0，避免產生虛假的低週轉率。
-- ============================================================


WITH MonthlySales AS (
    -- Monthly sales quantity & amount from SalesInvoices
    SELECT
        CAST(REPLACE(["Store"], '"', '') AS INT)                       AS StoreID,
        REPLACE(["InventoryId"], '"', '')                               AS SKU編號,
        YEAR(CAST(REPLACE(["SalesDate"], '"', '') AS DATE))             AS 年,
        MONTH(CAST(REPLACE(["SalesDate"], '"', '') AS DATE))            AS 月,
        SUM(CAST(REPLACE(["SalesQuantity"], '"', '') AS INT))           AS 月銷售量,
        SUM(CAST(REPLACE(["SalesDollars"], '"', '') AS DECIMAL(10,2)))  AS 月銷售額
    FROM dbo.SalesInvoices
    GROUP BY
        CAST(REPLACE(["Store"], '"', '') AS INT),
        REPLACE(["InventoryId"], '"', ''),
        YEAR(CAST(REPLACE(["SalesDate"], '"', '') AS DATE)),
        MONTH(CAST(REPLACE(["SalesDate"], '"', '') AS DATE))
),

MonthlyStock AS (
    -- Month-start, month-end, and average stock from DailyInventorySnapshot
    SELECT
        門市編號,
        SKU編號,
        YEAR(日期)  AS 年,
        MONTH(日期) AS 月,
        MIN(CASE WHEN DAY(日期) = 1  THEN 庫存數量 END)         AS 月初庫存,
        MAX(CASE WHEN 日期 = EOMONTH(日期) THEN 庫存數量 END)   AS 月末庫存,
        AVG(庫存數量)                                            AS 月平均庫存
    FROM dbo.DailyInventorySnapshot
    GROUP BY 門市編號, SKU編號, YEAR(日期), MONTH(日期)
)

INSERT INTO dbo.MonthlyInventorySummary
SELECT
    s.StoreID,
    s.SKU編號,
    s.年,
    s.月,
    s.月銷售量,
    s.月銷售額,
    i.月初庫存,
    i.月末庫存,
    i.月平均庫存,
    -- Turnover rate: NULL when avg stock = 0 to avoid divide-by-zero
    CASE
        WHEN i.月平均庫存 = 0 THEN NULL
        ELSE CAST(s.月銷售量 AS DECIMAL(10,2)) / i.月平均庫存
    END AS 月庫存週轉率
FROM MonthlySales s
LEFT JOIN MonthlyStock i
    ON  s.StoreID  = i.門市編號
    AND s.SKU編號  = i.SKU編號
    AND s.年       = i.年
    AND s.月       = i.月;
