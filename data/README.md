# 📂 資料集說明

## 🔗 資料來源

**Kaggle：** [Inventory Analysis Case Study](https://www.kaggle.com/datasets/bhanupratapbiswas/inventory-analysis-case-study/data)

> 本資料集模擬一間中型零售業公司的庫存管理情境，包含完整的進銷存交易紀錄，
> 適合用於庫存分析、ABC 分類、補貨策略等零售與供應鏈分析專案。

---

## ℹ️ 資料基本資訊

| 項目 | 內容 |
|------|------|
| 資料性質 | 模擬資料（Case Study，非真實企業資料） |
| 資料期間 | 2016 年 1 月 1 日 ─ 2016 年 12 月 31 日 |
| 產業情境 | 零售業門市庫存管理 |
| 資料來源 | Kaggle 公開資料集（Version 1，總計 571.68 MB） |

---

## 📁 資料集總覽

原始資料集共包含 6 個 CSV 檔案，本專案使用其中 3 張作為核心輸入：

| 檔案名稱 | 本專案使用 | 說明 |
|----------|:----------:|------|
| `BegInvFINAL12312016.csv` | ✅ 使用 | 期初庫存紀錄（2016年初各商品庫存狀態） |
| `PurchasesFINAL12312016.csv` | ✅ 使用 | 全年進貨紀錄（採購明細） |
| `SalesFINAL12312016.csv` | ✅ 使用 | 全年銷售紀錄（門市銷售明細） |
| `EndInvFINAL12312016.csv` | ❌ 未使用 | 期末庫存紀錄（可作為驗證對照） |
| `InvoicePurchases12312016.csv` | ❌ 未使用 | 採購發票明細 |
| `2017PurchasePricesDec.csv` | ❌ 未使用 | 2017年12月採購價格參考表 |

---

## 📋 使用資料集欄位說明

### 1. `BegInvFINAL12312016.csv`｜期初庫存

記錄 2016 年 1 月 1 日各門市、各商品的起始庫存狀態。

| 欄位 | 說明 |
|------|------|
| InventoryId | 庫存唯一識別碼（格式：`門市編號_城市_品牌編號`） |
| Store | 門市編號 |
| City | 門市所在城市 |
| Brand | 品牌編號 |
| Description | 商品描述 |
| Size | 商品規格 |
| onHand | 期初在手庫存量 |
| Price | 商品售價 |
| startDate | 庫存起算日期 |

---

### 2. `PurchasesFINAL12312016.csv`｜進貨紀錄

記錄 2016 年全年所有進貨交易明細，包含供應商資訊與採購數量。

| 欄位 | 說明 |
|------|------|
| InventoryId | 庫存唯一識別碼（格式：`門市編號_城市_品牌編號`） |
| Store | 門市編號 |
| Brand | 品牌編號 |
| Description | 商品描述 |
| Size | 商品規格 |
| VendorNumber | 供應商編號 |
| VendorName | 供應商名稱 |
| PONumber | 採購單編號 |
| PODate | 採購日期 |
| ReceivingDate | 實際到貨日期 |
| InvoiceDate | 發票日期 |
| PayDate | 付款日期 |
| PurchasePrice | 採購單價 |
| Quantity | 進貨數量 |
| Dollars | 進貨總金額 |
| Classification | 商品分類 |

---

### 3. `SalesFINAL12312016.csv`｜銷售紀錄

記錄 2016 年全年所有門市銷售明細，為計算每日庫存消耗的核心來源。

| 欄位 | 說明 |
|------|------|
| InventoryId | 庫存唯一識別碼（格式：`門市編號_城市_品牌編號`） |
| Store | 門市編號 |
| Brand | 品牌編號 |
| Description | 商品描述 |
| Size | 商品規格 |
| SalesQuantity | 銷售數量 |
| SalesDollars | 銷售金額 |
| SalesPrice | 銷售單價 |
| SalesDate | 銷售日期 |
| Volume | 容量（ml） |
| Classification | 商品分類 |
| ExciseTax | 消費稅 |
| VendorNo | 供應商編號 |
| VendorName | 供應商名稱 |

---

## 📊 資料規模

| 項目 | 數值 |
|------|------|
| 門市數量 | 79 間 |
| 品牌數量 | 8,094 個 |
| 原始三表合計筆數 | 約 1,000 萬+ 筆 |
| SQL 處理後每日庫存快照 | 75,589,614 筆 |
| 最終匯入 Power BI 筆數 | 約 1,300 萬筆（減少 83%） |

---

## ⚠️ 注意事項

- `data/` 資料夾內的 CSV 為**樣本資料（各取前 1,000 筆）**，完整資料請至 Kaggle 下載
- 原始資料存在以下資料品質問題，已於 `sql/00_raw_data_cleaning.sql` 中處理：
  - SKU 欄位含雙引號殘留，導致 JOIN 失敗
  - 日期欄位格式混用（標準字串與 Excel 數字序列並存）
  - 部分品牌（3,214 個）無法關聯商品維度，已分批補入
