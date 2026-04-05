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

<img width="1880" height="944" alt="image" src="https://github.com/user-attachments/assets/e023188d-3700-4c9e-89e7-304e0ed4e366" />


## ⭐ Power BI 星型模型

本專案採用星型模型（Star Schema）設計，以維度表圍繞事實表建立一對多關聯，
篩選方向統一從維度表流向事實表，確保 Power BI 的交叉篩選邏輯正確運作。

`Dim_SKU` 作為橋接表是本模型的關鍵設計 —
事實表只有 SKU 編號（格式：`門市編號_城市_品牌編號`），沒有直接的品牌或門市欄位，
必須透過 `Dim_SKU` 才能讓 `Dim_Store`（門市）和 `Dim_Product`（品牌）同時作用在事實表上。

<img width="1417" height="695" alt="螢幕擷取畫面 2026-03-31 010137" src="https://github.com/user-attachments/assets/76be0f73-90c9-4569-9188-780136cf7713" />


| 來源表（1 端） | → | 目標表（多端） | 關聯欄位 |
|:---:|:---:|:---:|:---:|
| Dim_Product | → | Dim_SKU | 品牌編號 |
| Dim_Product | → | Dim_Brand_Grade | BrandID |
| Dim_Product | → | Dim_LeadTime | BrandID |
| Dim_Product | → | Dim_Vendor | 供應商編號 |
| Dim_SKU | → | RecentInventory | SKU編號 |
| Dim_SKU | → | MonthlyInventorySummary | SKU編號 |
| Dim_Store | → | RecentInventory | 門市編號 |
| Dim_Store | → | MonthlyInventorySummary | StoreID |
| Dim_Date | → | RecentInventory | 日期 |

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

總部視角的全局監控頁面。上方 KPI 卡片一眼掌握庫存總金額、補貨品牌數、滯銷品項數；
中間 ABC/XYZ 九宮格矩陣可快速識別品牌分布；右側散佈圖以覆蓋天數為 X 軸、庫存金額為 Y 軸，
透過顏色區分四種庫存狀態（缺貨風險 / 健康庫存 / 過剩庫存 / 滯銷積壓），
使用者可自訂健康庫存上限與滯銷門檻。下方門市資訊總覽表供跨門市比較。

<img width="1322" height="737" alt="image" src="https://github.com/user-attachments/assets/70593446-cdf1-4c14-9543-c97818194576" />




### 頁面二：門市補貨清單

採購人員的每日行動頁面。選擇特定門市後，系統自動列出所有需要補貨的品牌，
每一列包含 ABC/XYZ 分級、現有庫存、平均日銷量、覆蓋天數、交期、安全庫存、
ROP（再訂購點）、建議補貨量與金額、負責供應商名稱。
左側圓環圖顯示 ABC 補貨品牌占比，右側長條圖列出待補貨金額前 10 大供應商，
清單可直接匯出 Excel 作為採購依據。

<img width="1326" height="744" alt="image" src="https://github.com/user-attachments/assets/8ebf19a3-5c86-486c-9eb1-33631c17ff0c" />




### 頁面三：門市積壓情況

庫存健康度的深度分析頁面。左上堆疊長條圖呈現全年月末庫存金額趨勢（按 ABC 分級），
右上雙軸區域圖對比月末庫存金額與月銷售額的走勢，用於判斷庫存是否跟上銷售節奏。
中間矩陣表展示各月 ABC 分級的庫存週轉率。
下方列出過剩與滯銷商品清單，每筆標註 ABC/XYZ 分級、月末庫存、覆蓋天數，
並根據分級自動建議「暫緩補貨」（A/B 級）或「停補/促銷」（C 級）。

<img width="1326" height="745" alt="image" src="https://github.com/user-attachments/assets/4e33d941-9315-44b6-82ff-7b8b27dc0a25" />


## 📊 Dashboard Demo
![1-ezgif com-optimize](https://github.com/user-attachments/assets/fe109b3d-95e8-49c6-a74f-86818ee01a87)


---

## 🔍 專案重點挑戰

| 挑戰 | 問題 | 解決方案 |
|------|------|---------|
| TEMPDB 空間不足 | 7,500 萬筆計算導致磁碟空間歸零 | 遷移 TEMPDB 至 D 槽 + Stored Procedure 逐月分批寫入 |
| SKU 雙引號殘留 | Power BI JOIN 結果 0 筆匹配 | 全表 UPDATE 清除 75,589,614 筆的引號 |
| 日期格式混用 | 交期計算出現 88 年的荒謬數值 | 雙格式轉換邏輯（TRY_CAST → DATEADD fallback） |
| 維度表不完整 | 3,214 個品牌無法關聯商品維度 | 分批補入 + 售價以 MAX(SalesPrice) 估算 |

---

## 🚀 重現步驟

```
1. 將 data/ 中的 CSV 匯入 SQL Server
2. 依序執行 sql/00 ~ sql/09 建立所有資料表
3. 在 Power BI 中連接 SQL Server，匯入資料表
4. 建立星型模型關聯（參考上方關聯表）
5. 以 DAX 建立 Dim_Date 日期維度表與計算量值
```

---

## 📂 專案結構

```
├── README.md                        ← 你正在看的這份文件
├── images/
│   ├── star_schema.png              ← Power BI 星型模型截圖
│   ├── dashboard_overview.png       ← 儀表板截圖：全公司庫存總覽
│   ├── dashboard_replenishment.png  ← 儀表板截圖：門市補貨清單
│   └── dashboard_overstock.png      ← 儀表板截圖：門市積壓情況
├── data/
│   ├── 期初庫存_樣本.csv
│   ├── 進貨紀錄_樣本.csv
│   └── 銷售紀錄_樣本.csv
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
