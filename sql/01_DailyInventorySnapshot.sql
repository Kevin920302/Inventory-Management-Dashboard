-- ============================================================
-- 01_DailyInventorySnapshot.sql
-- 核心計算表 — 全年每日庫存水位｜75,589,614 rows
-- ============================================================
--
-- [建構邏輯]
-- 原始資料只有期初庫存、進貨、銷售三個獨立事件，
-- 但沒有「任意一天的庫存水位」。此表透過累計計算：
--   當日庫存 = 期初庫存 + 截至當日累計進貨量 − 截至當日累計銷售量
-- 為每一天 × 每一門市 × 每一 SKU 產出庫存數量。
-- 負值庫存在現實中不應存在，全部強制設為 0。
--
-- [分批寫入策略]
-- 366天 × 79門市 × 275,401 SKU 的笛卡爾積極大，
-- 一次性計算會導致 TEMPDB 空間不足。
-- 採用 Stored Procedure 逐月 INSERT，每次只處理一個月。
--
-- [遭遇問題]
-- ⚠️ TEMPDB 空間不足：SQL Server 預設 TEMPDB 位於 C 槽，可用空間為 0。
--    修正：將 TEMPDB 全部資料檔與日誌檔遷移至 D 槽，重啟 SQL Server。
-- ⚠️ SKU 雙引號殘留：建表時 SKU 編號仍含雙引號（如 "1_HARDERSFIELD_1000"），
--    導致後續與 MonthlyInventorySummary 的 JOIN 完全失敗（0 筆匹配）。
--    修正：建表後全表 UPDATE 清除引號（見底部）。
-- ============================================================


-- Monthly batch insert procedure
CREATE PROCEDURE dbo.usp_BuildDailySnapshot
    @YearMonth DATE  -- first day of the target month, e.g. '2016-01-01'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartDate DATE = @YearMonth;
    DECLARE @EndDate   DATE = EOMONTH(@YearMonth);

    INSERT INTO dbo.DailyInventorySnapshot
        (日期, 門市編號, SKU編號, SKU品項名稱, 庫存數量)
    SELECT
        d.日期,
        b.門市編號,
        b.SKU編號,
        b.SKU品項名稱,
        -- Clamp negative stock to 0
        GREATEST(0,
            b.期初庫存
            + ISNULL(po.累計進貨, 0)
            - ISNULL(si.累計銷售, 0)
        ) AS 庫存數量
    FROM (
        -- Date spine for the target month
        SELECT DATEADD(DAY, n, @StartDate) AS 日期
        FROM (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
              FROM master.dbo.spt_values) nums
        WHERE DATEADD(DAY, n, @StartDate) <= @EndDate
    ) d
    CROSS JOIN (
        -- Base: opening inventory per store-SKU
        SELECT
            CAST(REPLACE(["Store"], '"', '') AS INT)         AS 門市編號,
            REPLACE(["InventoryId"], '"', '')                 AS SKU編號,
            REPLACE(["Description"], '"', '')                 AS SKU品項名稱,
            CAST(REPLACE(["onHand"], '"', '') AS INT)         AS 期初庫存
        FROM dbo.BegInventory
    ) b
    LEFT JOIN (
        -- Cumulative purchases up to each date
        SELECT
            CAST(REPLACE(["Store"], '"', '') AS INT)          AS 門市編號,
            REPLACE(["InventoryId"], '"', '')                  AS SKU編號,
            CAST(REPLACE(["ReceivingDate"], '"', '') AS DATE)  AS 收貨日期,
            SUM(CAST(REPLACE(["Quantity"], '"', '') AS INT))
                OVER (PARTITION BY ["Store"], ["InventoryId"]
                      ORDER BY CAST(REPLACE(["ReceivingDate"], '"', '') AS DATE)
                      ROWS UNBOUNDED PRECEDING)                AS 累計進貨
        FROM dbo.PurchaseOrders
    ) po ON po.門市編號 = b.門市編號
        AND po.SKU編號  = b.SKU編號
        AND po.收貨日期 = d.日期
    LEFT JOIN (
        -- Cumulative sales up to each date
        SELECT
            CAST(REPLACE(["Store"], '"', '') AS INT)          AS 門市編號,
            REPLACE(["InventoryId"], '"', '')                  AS SKU編號,
            CAST(REPLACE(["SalesDate"], '"', '') AS DATE)      AS 銷售日期,
            SUM(CAST(REPLACE(["SalesQuantity"], '"', '') AS INT))
                OVER (PARTITION BY ["Store"], ["InventoryId"]
                      ORDER BY CAST(REPLACE(["SalesDate"], '"', '') AS DATE)
                      ROWS UNBOUNDED PRECEDING)                AS 累計銷售
        FROM dbo.SalesInvoices
    ) si ON si.門市編號 = b.門市編號
        AND si.SKU編號  = b.SKU編號
        AND si.銷售日期 = d.日期;
END;
GO


-- Execute month by month to avoid TEMPDB overflow
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-01-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-02-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-03-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-04-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-05-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-06-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-07-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-08-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-09-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-10-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-11-01';
EXEC dbo.usp_BuildDailySnapshot @YearMonth = '2016-12-01';


-- ============================================================
-- Post-build fix: remove double quotes from SKU IDs
-- (discovered during Power BI integration — JOIN failure with 0 matches)
-- ============================================================
UPDATE dbo.DailyInventorySnapshot
SET SKU編號 = REPLACE(SKU編號, '"', '')
WHERE SKU編號 LIKE '%"%';
-- Affected rows: 75,589,614


-- ============================================================
-- Clustered index for Power BI query pattern (date + store filters)
-- ============================================================
CREATE CLUSTERED INDEX CIX_Daily
ON dbo.DailyInventorySnapshot (日期, 門市編號, SKU編號);
