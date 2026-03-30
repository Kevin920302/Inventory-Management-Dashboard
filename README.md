# 🏭 庫存管理儀表板｜Inventory Management Dashboard

> 從三張原始 CSV 出發，運用 SQL Server 資料工程 + Power BI 視覺化，
> 打造一套可操作的門市庫存監控與智慧補貨決策系統。

---

## 🎯 專案目標與使用者

**目標使用者：** 零售業區域經理、門市店長、採購人員

**解決的核心問題：**

原始資料只記錄了「期初有多少庫存」、「進了多少貨」、「賣出了多少」三件事，
但管理者真正需要回答的問題是：

- **今天每間門市、每個商品的庫存還剩多少？**
- **哪些商品快要缺貨了？該補多少？跟哪個供應商訂？**
- **哪些商品積壓過多，應該停止補貨或促銷出清？**
- **不同品牌的銷售穩定度和貢獻度如何？該怎麼分級管理？**

本專案透過資料工程將三張原始表轉換為每日庫存水位，再彙總為可分析的結構，
最終以 Power BI 儀表板呈現，讓使用者能即時掌握全公司 79 間門市、8,094 個品牌的庫存狀態。

---

## 🛠️ 技術架構

| 層級 | 技術 | 用途 |
|------|------|------|
| 資料儲存 | SQL Server 2019 | 原始資料匯入、清洗、轉換、建模 |
| 資料處理 | T-SQL | 資料清洗（雙引號處理、型態轉換）、累計計算、視窗函數、Stored Procedure 分批寫入 |
| 分析方法 | ABC-XYZ 分析 | 帕累托分析（銷售貢獻）+ 變異係數分析（需求穩定性），產出九宮格管理策略 |
| 視覺化 | Power BI + DAX | 星型模型設計、互動式儀表板、補貨清單自動生成 |

**關鍵技術亮點：**
- 7,500 萬筆每日庫存快照的批次建構策略（避免 TEMPDB 溢出）
- 雙格式日期轉換（標準字串 + Excel 數字序列）
- 資料量從 7,558 萬筆優化至 1,300 萬筆匯入 Power BI（減少 83%）

---

## 📊 資料工程流程

```
┌──────────────────────────────────────────────────────────┐
│                   3 張原始 CSV 資料表                      │
│   BegInventory ─── PurchaseOrders ─── SalesInvoices      │
│     (20萬筆)         (數十萬筆)        (1,000萬筆)        │
└──────┬───────────────────┬───────────────────┬───────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────────┐
│         DailyInventorySnapshot — 核心計算表               │
│           75,589,614 筆（全年每日庫存水位）                 │
│    當日庫存 = 期初庫存 + Σ進貨 − Σ銷售（負值歸零）          │
└──────┬───────────────────────────────────────┬───────────┘
       │                                       │
       ▼                                       ▼
  RecentInventory                    MonthlyInventorySummary
   (784萬筆)                            (211萬筆)
  近期庫存水位                          月銷售量/額/週轉率
  → Power BI 播放軸                   → 月度分析 & ABC-XYZ
       │                                       │
       ▼                                       ▼
┌──────────────────────────────────────────────────────────┐
│                      維度表群組                            │
│                                                          │
│  Dim_Product ── 11,308 筆 ── 商品主檔（含供應商）          │
│  Dim_SKU ────── 275,401 筆 ─ 門市×商品橋接表              │
│  Dim_Store ──── 79 筆 ────── 門市主檔                     │
│  Dim_Vendor ─── 129 筆 ───── 供應商主檔                   │
│  Dim_Brand_Grade 11,237 筆 ─ ABC-XYZ 九宮格分級           │
│  Dim_LeadTime ─ 10,664 筆 ─ 品牌交期                     │
└──────────────────────────────────────────────────────────┘

        Power BI 匯入總量：~1,300 萬筆（較原始減少 83%）
```

---

## 📁 資料表與 SQL 語法索引

所有 SQL 建表語法與邏輯說明收錄在 [`sql/`](./sql/) 資料夾：

### 事實表 / 彙總表

| 資料表 | 筆數 | 說明 | SQL |
|--------|------|------|-----|
| DailyInventorySnapshot | 75,589,614 | 全年每日庫存水位（核心計算表，不匯入 Power BI） | [`01_DailyInventorySnapshot.sql`](./sql/01_DailyInventorySnapshot.sql) |
| RecentInventory | 7,848,102 | 近期庫存萃取（Power BI 主要來源） | [`02_RecentInventory.sql`](./sql/02_RecentInventory.sql) |
| MonthlyInventorySummary | 2,119,239 | 月層級銷售與庫存彙總 | [`03_MonthlyInventorySummary.sql`](./sql/03_MonthlyInventorySummary.sql) |

### 維度表

| 資料表 | 筆數 | 說明 | SQL |
|--------|------|------|-----|
| Dim_Product | 11,308 | 商品主檔（含供應商欄位） | [`04_Dim_Product.sql`](./sql/04_Dim_Product.sql) |
| Dim_SKU | 275,401 | 門市×商品橋接表 | [`05_Dim_SKU.sql`](./sql/05_Dim_SKU.sql) |
| Dim_Store | 79 | 門市主檔 | [`06_Dim_Store.sql`](./sql/06_Dim_Store.sql) |
| Dim_Vendor | 129 | 供應商主檔 | [`07_Dim_Vendor.sql`](./sql/07_Dim_Vendor.sql) |
| Dim_Brand_Grade | 11,237 | ABC-XYZ 九宮格分級 | [`08_Dim_Brand_Grade.sql`](./sql/08_Dim_Brand_Grade.sql) |
| Dim_LeadTime | 10,664 | 品牌平均交期 | [`09_Dim_LeadTime.sql`](./sql/09_Dim_LeadTime.sql) |

> 📌 每個 `.sql` 檔案頂部都包含該表的建構邏輯說明、遭遇的問題與處理方式。

---

## 📸 儀表板成果展示

### 頁面一：全公司庫存總覽

> KPI 卡片 + ABC/XYZ 九宮格矩陣 + 品牌庫存狀態散佈圖 + 門市資訊總覽表

<img width="1324" height="738" alt="image" src="https://github.com/user-attachments/assets/21d65939-d2b7-486b-a098-e164046078d9" />



### 頁面二：門市補貨清單

> 單一門市的補貨行動清單，含 ABC/XYZ 分級、覆蓋天數、ROP、安全庫存、
> 建議補貨量與金額、供應商名稱，可直接匯出 Excel 給採購人員使用

<img width="1326" height="746" alt="image" src="https://github.com/user-attachments/assets/a488c089-153e-4167-8ce2-bd97628d9cbb" />


### 頁面三：門市積壓情況

> 月末庫存金額趨勢、庫存/銷售對比、各月 ABC 週轉率、
> 過剩/滯銷商品清單（含建議動作：暫緩補貨 or 停補/促銷）

<img width="1327" height="746" alt="image" src="https://github.com/user-attachments/assets/c6f05d8d-b37a-492c-b303-aad414c52fed" />


---

## 🔍 專案重點挑戰

| 挑戰 | 問題 | 解決方案 |
|------|------|---------|
| TEMPDB 空間不足 | 7,500 萬筆計算導致磁碟空間歸零 | 遷移 TEMPDB 至 D 槽 + Stored Procedure 逐月分批寫入 |
| SKU 雙引號殘留 | Power BI JOIN 結果 0 筆匹配 | 全表 UPDATE 清除 75,589,614 筆的引號 |
| 日期格式混用 | 交期計算出現 88 年的荒謬數值 | 雙格式轉換邏輯（TRY_CAST → DATEADD fallback） |
| 維度表不完整 | 3,214 個品牌無法關聯商品維度 | 分批補入 + 售價以 MAX(SalesPrice) 估算 |

---

## 📂 專案結構

```
├── README.md                        ← 你正在看的這份文件
├── dashboard_overview.png           ← 儀表板截圖：全公司庫存總覽
├── dashboard_replenishment.png      ← 儀表板截圖：門市補貨清單
├── dashboard_overstock.png          ← 儀表板截圖：門市積壓情況
└── sql/
    ├── 00_raw_data_cleaning.sql     ← 原始資料系統性清洗說明
    ├── 01_DailyInventorySnapshot.sql
    ├── 02_RecentInventory.sql
    ├── 03_MonthlyInventorySummary.sql
    ├── 04_Dim_Product.sql
    ├── 05_Dim_SKU.sql
    ├── 06_Dim_Store.sql
    ├── 07_Dim_Vendor.sql
    ├── 08_Dim_Brand_Grade.sql       ← 含 ABC-XYZ 方法論完整說明
    └── 09_Dim_LeadTime.sql
```
