# 📦 Cloudflare R2 画像アップロード仕様書

## 🎯 概要

このFlutterアプリは、商品画像を**Cloudflare R2**に自動アップロードし、外部WEBアプリに引き渡す機能を実装しています。

---

## 🔄 データフロー

```
【①WEBアプリ】CSV登録
    ↓ (D1 Database)
    
【②スマホアプリ(Flutter)】
    ├─ SKUで商品検索
    ├─ 商品情報追記
    ├─ 商品画像撮影
    └─ Cloudflare R2に保存
    ↓
    
【③WEBアプリ】白抜き・修正
    ├─ 画像URL取得
    └─ AI処理・編集
```

---

## 📸 画像アップロード仕様

### ✅ Q1: 画像はCloudflare R2に保存されますか?

**回答: はい、Cloudflare R2に保存されます!**

- **保存先**: Cloudflare R2バケット
- **アップロード方法**: Cloudflare Workers API経由
- **Workers URL**: `https://image-upload-api.jinkedon2.workers.dev/upload`

---

### 📋 Q2: 画像のURL形式

**R2公開URL形式:**
```
https://pub-300562464768499b8fcaee903d0f9861.r2.dev/{ファイル名}
```

**具体例:**
```
https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_1.jpg
https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_2.jpg
https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_3.jpg
```

---

### 🔑 Q3: 画像ファイル名にSKUコードは含まれますか?

**回答: はい、SKUコードが含まれます!**

**ファイル名形式:**
```
{SKU}_{連番}.jpg
```

**構成要素:**
- **SKU**: 商品のSKUコード（例: `1025L190003`）
- **連番**: 画像の順番（1から始まる）

**例:**
```
1025L190003_1.jpg  ← 1枚目の画像
1025L190003_2.jpg  ← 2枚目の画像
1025L190003_3.jpg  ← 3枚目の画像
```

---

## 🔧 技術仕様

### アップロード処理

**実装ファイル:**
- `/lib/services/cloudflare_storage_service.dart` - Cloudflare R2アップロードサービス
- `/lib/screens/detail_screen.dart` - 商品確定時のアップロード処理

**アップロードフロー:**

1. **商品確定ボタン押下**
2. **画像データ取得** (Web: blob URL / Mobile: ファイルパス)
3. **SKUコード + 連番でファイルID生成**
4. **Cloudflare Workers API経由でR2にアップロード**
5. **R2公開URLを取得して保存**

**コード例:**
```dart
// SKUコード + 連番でファイルIDを生成
final skuCode = _skuController.text.isNotEmpty ? _skuController.text : 'NOSKU';
final imageNumber = i + 1;  // 1から始まる連番
final fileId = '${skuCode}_$imageNumber';

// アップロード例: fileId = "1025L190003_1"
// 生成されるファイル名: "1025L190003_1.jpg"

// Workers経由でアップロード
final uploadedUrl = await CloudflareWorkersStorageService.uploadImage(
  imageBytes,
  fileId,
);

// uploadedUrl = "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_1.jpg"
```

---

## 🌐 外部WEBアプリへのデータ送信

### 送信ボタン

商品詳細画面に「**外部WEBアプリに送信**」ボタンを配置

### 送信データ形式

**JSON形式:**
```json
{
  "sku": "1025L190003",
  "barcode": "4901234567890",
  "name": "デニムジャケット",
  "brand": "Levi's",
  "category": "ジャケット/アウター",
  "size": "M",
  "color": "ブルー",
  "material": "デニム",
  "condition": "目立った傷や汚れなし",
  "productRank": "B",
  "price": "8000",
  "description": "着用回数3回程度。目立った傷や汚れなし。",
  "images": [
    "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_1.jpg",
    "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_2.jpg",
    "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_3.jpg"
  ],
  "r2_domain": "pub-300562464768499b8fcaee903d0f9861.r2.dev",
  "timestamp": "2024-12-30T12:34:56.789Z"
}
```

### URL形式

**送信URL:**
```
https://your-webapp.example.com/process?data={Base64エンコードされたJSON}
```

**Base64エンコード:**
- JSONデータをBase64Urlエンコード（URLセーフ）
- URLパラメータとして送信

---

## 🔐 セキュリティ

### Cloudflare Workers経由のアップロード

- **API トークン非公開**: Workers側でR2 APIトークンを管理
- **CORS対応**: Workers側でCORSヘッダーを設定
- **安全なアップロード**: クライアント側にAPIトークンを露出しない

---

## 📝 WEBアプリ側の実装例

### データ受信

**JavaScript例:**
```javascript
// URLパラメータからデータを取得
const urlParams = new URLSearchParams(window.location.search);
const encodedData = urlParams.get('data');

// Base64デコード
const jsonString = atob(encodedData.replace(/-/g, '+').replace(/_/g, '/'));

// JSONパース
const productData = JSON.parse(jsonString);

console.log('SKU:', productData.sku);
console.log('画像URL:', productData.images);

// 画像URL例:
// productData.images[0] = "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_1.jpg"
// productData.images[1] = "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_2.jpg"
// productData.images[2] = "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_3.jpg"
```

### 画像ダウンロード

**Python例:**
```python
import requests

# 商品データを取得（base64デコード後）
product_data = {
    "sku": "1025L190003",
    "images": [
        "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_1.jpg",
        "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_2.jpg",
        "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_3.jpg"
    ]
}

# 各画像をダウンロード
for i, image_url in enumerate(product_data['images'], start=1):
    response = requests.get(image_url)
    
    if response.status_code == 200:
        # ファイル名はSKU + 連番で保存
        filename = f"{product_data['sku']}_{i}.jpg"
        with open(filename, 'wb') as f:
            f.write(response.content)
        print(f"✅ 画像{i}をダウンロード: {filename}")
    else:
        print(f"❌ 画像{i}のダウンロード失敗")
```

---

## 🎯 まとめ

### ✅ 実装完了事項

1. ✅ **画像をCloudflare R2に保存**
2. ✅ **SKUコードを含むファイル名で保存**
3. ✅ **R2公開URLを生成**
4. ✅ **外部WEBアプリへのデータ送信**
5. ✅ **複数画像の一括アップロード**

### 📋 URL形式

**R2画像URL:**
```
https://pub-300562464768499b8fcaee903d0f9861.r2.dev/{SKU}_{連番}.jpg
```

**例:**
```
https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L190003_1.jpg
```

### 🔑 ファイル名構造

```
{SKU}_{連番}.jpg

例: 1025L190003_1.jpg
    ↑           ↑
    SKU         連番
```

---

## 🚀 次のステップ

### WEBアプリ側の実装

1. **データ受信エンドポイント作成**
2. **画像URLからダウンロード処理**
3. **AI白抜き・画像編集処理**
4. **D1 Databaseへの保存**

### 設定変更

**外部WEBアプリURLの設定:**

`/lib/screens/detail_screen.dart` の以下の行を変更:

```dart
// 🌐 外部WEBアプリのURL（ここを実際のURLに変更してください）
final webAppUrl = 'https://your-webapp.example.com/process';
```

↓

```dart
// 🌐 外部WEBアプリのURL
final webAppUrl = 'https://実際のWEBアプリURL/process';
```

---

## 📞 サポート

質問や問題が発生した場合は、開発チームにお問い合わせください。

- 📧 Email: support@example.com
- 💬 Slack: #flutter-support

---

**最終更新日**: 2024-12-30  
**バージョン**: 1.0.0
