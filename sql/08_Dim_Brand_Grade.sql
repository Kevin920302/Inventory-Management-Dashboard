-- ============================================================
-- 08_Dim_Brand_Grade.sql
-- 品牌 ABC + XYZ 組合分級表｜11,237 rows
-- ============================================================
--
-- ┌──────────────────────────────────────────────────────┐
-- │              ABC-XYZ 分析方法論說明                    │
-- └──────────────────────────────────────────────────────┘
--
-- 這是庫存管理領域的進階分類框架，透過兩個獨立維度的交叉分析，
-- 產出九種管理策略，讓每個品牌都有量化且可操作的管理定位。
--
-- ── ABC 分析（銷售貢獻｜Pareto Analysis）──
--
-- 核心假設：少數品牌貢獻大部分營收（80/20 法則的延伸）
-- 計算方式：
--   1. 加總每個品牌全年銷售額
--   2. 按銷售額遞減排序
--   3. 計算累計銷售額占比（使用視窗函數 SUM OVER）
--   4. 依閾值分級：
--      A 級：累計占比 ≤ 70%  →   994 品牌，貢獻 69.9% 營收
--      B 級：累計占比 70~90% → 1,618 品牌，貢獻 19.9% 營收
--      C 級：累計占比 > 90%  → 8,625 品牌，貢獻  9.6% 營收
--
-- ── XYZ 分析（需求穩定性｜Coefficient of Variation）──
--
-- 核心指標：CV = STDEV(月銷售量) / AVG(月銷售量)
-- CV 越高 → 銷售越不規律 → 需要越多安全庫存
-- CV 越低 → 銷售越穩定 → 補貨計劃越容易執行
-- 分級閾值：
--   X 級：CV ≤ 0.5  → 4,547 品牌，平均 CV = 0.32（穩定）
--   Y 級：CV 0.5~1.0 → 4,444 品牌，平均 CV = 0.71（波動）
--   Z 級：CV > 1.0  → 2,246 品牌，平均 CV = 1.25（不規律）
--
-- ── 特殊處理：只有 1 個月銷售紀錄的品牌（898 筆）──
--
-- STDEV() 需要至少 2 筆資料才能計算，
-- 只有 1 個月銷售的品牌 → StdDevSales = NULL → 無法算 CV
-- 處理決策：全部歸為 Z 級（資料不足 = 高度不確定性，Z 級最保守）
--
-- ── 九宮格策略矩陣 ──
--
--   AX (682, 46.7%)  → 核心品牌，嚴控缺貨
--   AY (276, 18.3%)  → 高銷售有波動，備安全庫存
--   AZ  (36,  1.6%)  → 高銷售不穩定，密切監控
--   BX (1108, 13.1%) → 穩定中銷售，正常管理
--   BY (423,  5.0%)  → 中銷售有波動，適度備貨
--   BZ  (87,  1.0%)  → 中銷售不穩定，謹慎補貨
--   CX (2757,  4.8%) → 低銷售穩定，少量維持
--   CY (3745,  3.5%) → 低銷售波動，視情況處理
--   CZ (2123,  1.2%) → 低銷售不穩定，優先評估停補
--
-- ============================================================


-- ────────────────────────────────────────
-- Step 1: ABC classification (revenue contribution)
-- ────────────────────────────────────────
WITH 品牌銷售 AS (
    SELECT 品牌編號, SUM(月銷售額) AS 總銷售額
    FROM dbo.MonthlyInventorySummary
    GROUP BY 品牌編號
),
累計占比 AS (
    SELECT
        品牌編號,
        總銷售額,
        SUM(總銷售額) OVER (ORDER BY 總銷售額 DESC
            ROWS UNBOUNDED PRECEDING)
        / SUM(總銷售額) OVER () AS CumPct
    FROM 品牌銷售
)
SELECT 品牌編號, 總銷售額, CumPct,
    CASE
        WHEN CumPct <= 0.70 THEN 'A'   -- top 70% cumulative revenue
        WHEN CumPct <= 0.90 THEN 'B'   -- next 20%
        ELSE 'C'                         -- bottom 10%
    END AS ABC
INTO #ABC
FROM 累計占比;


-- ────────────────────────────────────────
-- Step 2: XYZ classification (demand variability via CV)
-- ────────────────────────────────────────
SELECT
    品牌編號,
    AVG(月銷售量)    AS AvgMonthlySales,
    STDEV(月銷售量)  AS StdDevSales,
    CASE
        WHEN AVG(月銷售量) = 0 THEN NULL
        ELSE STDEV(月銷售量) / AVG(月銷售量)
    END AS CV,
    CASE
        WHEN STDEV(月銷售量) / AVG(月銷售量) <= 0.5 THEN 'X'  -- stable
        WHEN STDEV(月銷售量) / AVG(月銷售量) <= 1.0 THEN 'Y'  -- volatile
        ELSE 'Z'                                                 -- erratic
    END AS XYZ
INTO #XYZ
FROM dbo.MonthlyInventorySummary
GROUP BY 品牌編號;


-- ────────────────────────────────────────
-- Step 3: combine ABC + XYZ into final grade
-- ────────────────────────────────────────
INSERT INTO dbo.Dim_Brand_Grade
SELECT
    a.品牌編號,
    a.總銷售額,
    a.ABC,
    x.AvgMonthlySales,
    x.StdDevSales,
    x.CV,
    x.XYZ,
    a.ABC + x.XYZ AS Grade   -- e.g. 'AX', 'BY', 'CZ'
FROM #ABC a
INNER JOIN #XYZ x ON a.品牌編號 = x.品牌編號;


-- ────────────────────────────────────────
-- Step 4: handle brands with only 1 month of sales data
-- STDEV returns NULL → classify as Z (insufficient data = high uncertainty)
-- ────────────────────────────────────────
UPDATE dbo.Dim_Brand_Grade
SET StdDevSales = 0,
    CV          = 0,
    XYZ         = 'Z',
    Grade       = ABC + 'Z'
WHERE StdDevSales IS NULL
  AND ABC IS NOT NULL;
-- Affected: 898 brands


-- Cleanup temp tables
DROP TABLE IF EXISTS #ABC;
DROP TABLE IF EXISTS #XYZ;
