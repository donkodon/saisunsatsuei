# 画像削除機能の完全ガイド

## 📋 目次
1. [システム構成](#システム構成)
2. [削除機能の動作フロー](#削除機能の動作フロー)
3. [過去に発生した問題と解決策](#過去に発生した問題と解決策)
4. [トラブルシューティング](#トラブルシューティング)
5. [デバッグ方法](#デバッグ方法)

---

## システム構成

### アーキテクチャ概要

```
Flutter App (Web/Mobile)
    ↓
CloudflareStorageService (Dart)
    ↓
Cloudflare Workers API
    ↓
Cloudflare R2 Storage (実ファイル保存)
```

### 関連ファイル

#### 1. Flutter側
- **`lib/services/cloudflare_storage_service.dart`**: 画像アップロード・削除のメインロジック
- **`lib/screens/detail_screen.dart`**: 差分削除の実行ロジック（850-905行目）

#### 2. Cloudflare Workers側
- **`image_upload_workers_with_sku_folder.js`**: 画像アップロード・削除API実装
- **デプロイURL**: `https://image-upload-api.jinkedon2.workers.dev`

---

## 削除機能の動作フロー

### 1. URL構造

#### R2バケット内のファイルパス構造
```
R2バケット (PRODUCT_IMAGES)
├── test_company/              ← company_id
│   ├── 1025L190001/           ← SKU
│   │   ├── 1025L190001_uuid1.jpg       ← 元画像
│   │   ├── 1025L190001_uuid1_white.jpg ← 白抜き画像
│   │   ├── 1025L190001_uuid1_mask.png  ← マスク画像
│   │   ├── 1025L190001_uuid2.jpg
│   │   └── ...
│   └── 1025L280001/
│       └── ...
└── other_company/
    └── ...
```

#### 公開URL形式
```
https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg
                                                 ↑             ↑           ↑
                                                 company_id    SKU         fileName
```

---

### 2. 差分削除の計算ロジック

**実装場所**: `lib/screens/detail_screen.dart` (794-905行目)

#### Phase 1: 画像URLリストの統合
```dart
// 既存画像 + 新規画像を統合
final allImageUrls = [...existingUrls, ...imageUrls];
```

#### Phase 2: 元画像の差分削除
```dart
// DBの古い元画像 - 最終元画像リスト = 削除対象
final urlsToDeleteOriginal = oldImageUrls
    .where((url) => !url.contains('_white.jpg') && !url.contains('_mask.png'))
    .toSet()
    .difference(allImageUrls.toSet());
```

#### Phase 3: 白抜き画像の差分削除
```dart
// 期待される白抜き画像を生成
final expectedWhiteUrls = allImageUrls.map((url) {
  return url.replaceAll(RegExp(r'\.(jpg|jpeg)$'), '_white.jpg');
}).toSet();

// DBから古い白抜き画像を抽出
final oldWhiteUrls = oldImageUrls
    .where((url) => url.contains('_white.jpg'))
    .toSet();

// 削除対象 = 古い白抜き - 期待される白抜き
final whiteUrlsToDelete = oldWhiteUrls.difference(expectedWhiteUrls);
```

#### Phase 4: マスク画像の差分削除
```dart
// 期待されるマスク画像を生成
final expectedMaskUrls = allImageUrls.map((url) {
  return url.replaceAll(RegExp(r'\.(jpg|jpeg)$'), '_mask.png');
}).toSet();

// DBから古いマスク画像を抽出
final oldMaskUrls = oldImageUrls
    .where((url) => url.contains('_mask.png'))
    .toSet();

// 削除対象 = 古いマスク - 期待されるマスク
final maskUrlsToDelete = oldMaskUrls.difference(expectedMaskUrls);
```

#### Phase 5: 最終削除対象の統合
```dart
// 元画像 + 白抜き画像 + マスク画像の削除対象を統合
final urlsToDelete = {
  ...urlsToDeleteOriginal,
  ...whiteUrlsToDelete,
  ...maskUrlsToDelete
};
```

---

### 3. 削除API呼び出しフロー

**実装場所**: `lib/services/cloudflare_storage_service.dart` (227-296行目)

#### ステップ1: URLからファイルパスを抽出

**重要**: この部分が過去に何度もバグの原因になっています！

```dart
static Future<Map<String, dynamic>> deleteImageWithDetails(String imageUrl) async {
  final uri = Uri.tryParse(imageUrl);
  
  // URLのpathSegmentsを解析
  // 例: https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg
  // pathSegments = ["test_company", "1025L190001", "1025L190001_uuid.jpg"]
  
  String filePath;
  if (uri.pathSegments.length >= 3) {
    // ✅ 正しい: company_id + SKU + fileName
    final companyId = uri.pathSegments[uri.pathSegments.length - 3];  // "test_company"
    final sku = uri.pathSegments[uri.pathSegments.length - 2];         // "1025L190001"
    final fileName = uri.pathSegments.last;                            // "1025L190001_uuid.jpg"
    filePath = '$companyId/$sku/$fileName';                           // "test_company/1025L190001/1025L190001_uuid.jpg"
    debugPrint('🔧 フルパス（company_id含む）: $filePath');
  } else if (uri.pathSegments.length == 2) {
    // 🔄 後方互換性: SKU + fileName（古い形式）
    filePath = '${uri.pathSegments[0]}/${uri.pathSegments[1]}';
    debugPrint('🔄 SKUフォルダパス（company_idなし）: $filePath');
  } else {
    // 🔄 後方互換性: fileName のみ（最古の形式）
    filePath = uri.pathSegments.last;
    debugPrint('🔄 ファイル名のみ: $filePath');
  }
  
  // ... 削除処理続く
}
```

#### ステップ2: Workers APIへ削除リクエスト送信

```dart
// Workers削除エンドポイント
final deleteUrl = Uri.parse('$workerBaseUrl/delete?filename=$filePath');

debugPrint('🗑️ Cloudflare削除リクエスト: $deleteUrl');
debugPrint('📁 削除するファイルパス: $filePath');

final response = await http.delete(deleteUrl).timeout(
  Duration(seconds: 15),
  onTimeout: () => http.Response('{"error":"タイムアウト"}', 408),
);

debugPrint('📨 削除レスポンス: ${response.statusCode}');

if (response.statusCode == 200 || response.statusCode == 204) {
  debugPrint('✅ 画像削除成功: $filePath');
  return {
    'success': true,
    'reason': null,
    'statusCode': response.statusCode,
  };
}
```

---

### 4. Cloudflare Workers APIの削除処理

**実装場所**: `image_upload_workers_with_sku_folder.js` (133-191行目)

```javascript
// 削除エンドポイント
if (url.pathname === '/delete' && request.method === 'DELETE') {
  const filename = url.searchParams.get('filename');
  
  if (!filename) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'filename パラメータが必要です' 
    }), { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } });
  }
  
  console.log('🗑️ 削除リクエスト:', filename);
  
  try {
    // R2から削除
    await env.PRODUCT_IMAGES.delete(filename);
    
    console.log('✅ 削除成功:', filename);
    
    return new Response(JSON.stringify({
      success: true,
      deletedFile: filename,
    }), { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } });
  } catch (error) {
    console.error('❌ 削除エラー:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
    }), { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } });
  }
}
```

---

## 過去に発生した問題と解決策

### 🚨 問題1: company_idが削除パスに含まれない（2025年2月11日修正）

#### 症状
- コンソールログ: `✅ 画像削除成功: 1025L190001/1025L190001_uuid.jpg`
- 削除API呼び出し: `DELETE /delete?filename=1025L190001/1025L190001_uuid.jpg`
- **結果**: R2バケットから削除されない（実際のパスは `test_company/1025L190001/1025L190001_uuid.jpg`）

#### 原因
**`cloudflare_storage_service.dart`の240-250行目のURL解析ロジックのバグ**

```dart
// ❌ 間違ったコード（修正前）
if (uri.pathSegments.length >= 2) {
  filePath = '${uri.pathSegments[uri.pathSegments.length - 2]}/${uri.pathSegments.last}';
}
// 結果: "1025L190001/1025L190001_uuid.jpg" （company_idが欠落）
```

**問題の詳細**:
```dart
// URL: https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg
uri.pathSegments = ["test_company", "1025L190001", "1025L190001_uuid.jpg"]
uri.pathSegments.length = 3  // >= 2 なので if ブロック実行

// 間違った計算:
filePath = '${uri.pathSegments[3 - 2]}/${uri.pathSegments.last}'
         = '${uri.pathSegments[1]}/${uri.pathSegments[2]}'
         = '1025L190001/1025L190001_uuid.jpg'  // ❌ test_company が欠落！
```

#### 解決策
**pathSegmentsの長さで3つのケースに分岐**

```dart
// ✅ 正しいコード（修正後）
String filePath;
if (uri.pathSegments.length >= 3) {
  // ケース1: company_id + SKU + fileName（現在の正規形式）
  final companyId = uri.pathSegments[uri.pathSegments.length - 3];
  final sku = uri.pathSegments[uri.pathSegments.length - 2];
  final fileName = uri.pathSegments.last;
  filePath = '$companyId/$sku/$fileName';
  debugPrint('🔧 フルパス（company_id含む）: $filePath');
} else if (uri.pathSegments.length == 2) {
  // ケース2: SKU + fileName（古い形式：company_idなし）
  filePath = '${uri.pathSegments[0]}/${uri.pathSegments[1]}';
  debugPrint('🔄 SKUフォルダパス（company_idなし）: $filePath');
} else {
  // ケース3: fileName のみ（最古の形式）
  filePath = uri.pathSegments.last;
  debugPrint('🔄 ファイル名のみ: $filePath');
}
```

#### 修正手順
```bash
# 1. コードを修正
# lib/services/cloudflare_storage_service.dart の240-260行目を上記コードに置き換え

# 2. キャッシュを完全クリア
cd /home/user/flutter_app
rm -rf build/ .dart_tool/
flutter clean

# 3. 完全再ビルド
flutter build web --release

# 4. サーバー再起動
cd build/web
python3 -m http.server 5060 --bind 0.0.0.0 &

# 5. ブラウザキャッシュもクリア
# - F12で開発者ツールを開く
# - Networkタブで「Disable cache」にチェック
# - Ctrl + Shift + R で完全リロード
```

---

### 🚨 問題2: 画像の複製（過去に発生）

#### 症状
- 画像を編集・保存すると、古い画像が削除されずに新しい画像が追加される
- R2バケットに同じSKUの画像が複数蓄積される

#### 考えられる原因
1. **差分削除ロジックが実行されていない**
2. **URL形式の不一致**（古い画像と新しい画像でURL構造が異なる）
3. **DBの古い画像URLリストが正しく取得できていない**

#### デバッグ方法
コンソールで以下のログを確認：

```javascript
// Phase 6で既存画像と新規画像が正しく統合されているか
📊 最終画像リスト: X件（既存Y + 新規Z）

// Phase 4で削除対象が正しく計算されているか
🗑️ 差分削除対象: N件
   削除URL: https://...

// 削除が実際に実行されているか
🗑️ 一括削除開始: N件
✅ Cloudflare削除: X件成功, Y件失敗
```

---

### 🚨 問題3: ビルドキャッシュによる修正未反映

#### 症状
- コードを修正したのに、ブラウザで動作が変わらない
- 期待されるログが出力されない

#### 原因
1. **Flutter ビルドキャッシュ**（`.dart_tool/`, `build/`）
2. **ブラウザキャッシュ**（Service Worker、Cache Storage）

#### 解決策

##### Flutter側
```bash
# 完全クリーンビルド
cd /home/user/flutter_app
rm -rf build/ .dart_tool/
flutter clean
flutter build web --release

# サーバー再起動
cd build/web
python3 -m http.server 5060 --bind 0.0.0.0 &
```

##### ブラウザ側
1. **開発者ツールを開く**（F12）
2. **Networkタブで「Disable cache」にチェック**
3. **完全リロード**: `Ctrl + Shift + R`（Windows/Linux）または `Cmd + Shift + R`（Mac）
4. **それでもダメな場合**:
   - ブラウザの設定から「キャッシュと Cookie をクリア」
   - または、シークレットモードで開く

---

## トラブルシューティング

### チェックリスト

#### 1. Workers APIの動作確認
```bash
# 削除エンドポイントが正常に動作するか確認
curl -X DELETE "https://image-upload-api.jinkedon2.workers.dev/delete?filename=test_company/TEST_SKU/test_file.jpg" -v

# 期待されるレスポンス:
# HTTP/2 200
# {"success":true,"deletedFile":"test_company/TEST_SKU/test_file.jpg"}
```

#### 2. Flutter側のURL解析確認
コンソールで以下のログが出力されているか確認：

```
🔧 フルパス（company_id含む）: test_company/1025L190001/1025L190001_uuid.jpg
```

**出力されていない場合**:
- ビルドキャッシュが残っている → 完全クリーンビルド実行
- ブラウザキャッシュが残っている → 完全リロード実行

#### 3. pathSegmentsの長さ確認
削除対象のURLを1つ選んで、手動で解析：

```dart
// 例: https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg
final uri = Uri.parse('https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg');
print('pathSegments.length: ${uri.pathSegments.length}');  // 期待値: 3
print('pathSegments: ${uri.pathSegments}');                // 期待値: ["test_company", "1025L190001", "1025L190001_uuid.jpg"]
```

#### 4. R2バケットの確認
削除APIが200を返しているのに画像が残っている場合：

```bash
# 画像が実際に存在するか確認
curl -I "https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg"

# 期待される結果:
# - 削除成功: HTTP/2 404
# - まだ存在する: HTTP/2 200
```

---

## デバッグ方法

### 1. ブラウザコンソールでのデバッグログ確認

#### 削除対象の確認
```
🗑️ 差分削除対象: X件
   削除URL: https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/xxxxx.jpg
```

**確認ポイント**:
- URLに `test_company/` が含まれているか
- SKUフォルダが含まれているか
- ファイル名が正しいか

#### URL解析結果の確認
```
🔧 フルパス（company_id含む）: test_company/1025L190001/1025L190001_uuid.jpg
```

**このログが出ない場合**:
- `uri.pathSegments.length` が3未満
- URL構造が想定と異なる

#### 削除リクエストの確認
```
🗑️ Cloudflare削除リクエスト: https://image-upload-api.jinkedon2.workers.dev/delete?filename=test_company/1025L190001/xxxxx.jpg
📁 削除するファイルパス: test_company/1025L190001/xxxxx.jpg
```

**確認ポイント**:
- `filename` パラメータに完全なパス（company_id + SKU + fileName）が含まれているか

#### 削除レスポンスの確認
```
📨 削除レスポンス: 200
✅ 画像削除成功: test_company/1025L190001/xxxxx.jpg
```

**200以外の場合**:
- `404`: ファイルが存在しないか、パスが間違っている
- `400`: パラメータエラー
- `500`: Workers側のエラー

---

### 2. Workers側のログ確認（Cloudflareダッシュボード）

1. Cloudflareダッシュボードにログイン
2. Workers & Pages → `image-upload-api` を選択
3. Logs タブを開く
4. 削除リクエストのログを確認：

```javascript
🗑️ 削除リクエスト: test_company/1025L190001/1025L190001_uuid.jpg
✅ 削除成功: test_company/1025L190001/1025L190001_uuid.jpg
```

または

```javascript
❌ 削除エラー: [エラーメッセージ]
```

---

### 3. cURLでの直接テスト

#### 削除テスト
```bash
# 正しいパスでの削除テスト
curl -X DELETE "https://image-upload-api.jinkedon2.workers.dev/delete?filename=test_company/1025L190001/1025L190001_uuid.jpg" -v

# 期待されるレスポンス:
# HTTP/2 200
# {"success":true,"deletedFile":"test_company/1025L190001/1025L190001_uuid.jpg"}
```

#### ファイル存在確認
```bash
# 削除前: 200が返る
curl -I "https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg"
# HTTP/2 200

# 削除後: 404が返る
curl -I "https://image-upload-api.jinkedon2.workers.dev/test_company/1025L190001/1025L190001_uuid.jpg"
# HTTP/2 404
```

---

## 重要な注意事項

### ⚠️ 必ず守るべきルール

#### 1. URL構造の一貫性
**必ず `company_id/SKU/fileName` 形式を維持すること**

```
✅ 正しい: test_company/1025L190001/1025L190001_uuid.jpg
❌ 間違い: 1025L190001/1025L190001_uuid.jpg（company_id欠落）
❌ 間違い: 1025L190001_uuid.jpg（フォルダ構造なし）
```

#### 2. pathSegments解析の重要性
**`uri.pathSegments.length` の値によって処理を分岐すること**

```dart
if (uri.pathSegments.length >= 3) {
  // 現在の正規形式: company_id + SKU + fileName
} else if (uri.pathSegments.length == 2) {
  // 古い形式: SKU + fileName
} else {
  // 最古の形式: fileName のみ
}
```

#### 3. デバッグログの活用
**削除処理の各ステップで必ずログを出力すること**

```dart
debugPrint('🔧 フルパス（company_id含む）: $filePath');      // URL解析結果
debugPrint('🗑️ Cloudflare削除リクエスト: $deleteUrl');     // リクエストURL
debugPrint('📁 削除するファイルパス: $filePath');           // 削除パス
debugPrint('📨 削除レスポンス: ${response.statusCode}');   // レスポンス
debugPrint('✅ 画像削除成功: $filePath');                   // 成功確認
```

#### 4. キャッシュクリアの徹底
**コード修正後は必ず以下を実行**

1. Flutter側: `rm -rf build/ .dart_tool/ && flutter clean && flutter build web --release`
2. サーバー再起動
3. ブラウザ: 開発者ツール → Network → Disable cache + 完全リロード

---

## まとめ

### 削除機能が正常に動作する条件

✅ **URL構造**: `company_id/SKU/fileName` 形式が維持されている  
✅ **pathSegments解析**: 長さに応じて正しく分岐処理されている  
✅ **Workers API**: 削除エンドポイントが正常に動作している  
✅ **ビルドキャッシュ**: Flutter・ブラウザのキャッシュがクリアされている  
✅ **デバッグログ**: 各ステップで期待通りのログが出力されている  

### 問題発生時の対処フロー

1. **ブラウザコンソールでログ確認** → URL解析が正しいか確認
2. **`🔧 フルパス（company_id含む）:` ログの有無確認** → なければキャッシュクリア
3. **cURLで直接削除テスト** → Workers APIの動作確認
4. **R2バケット確認** → 実際に削除されているか確認

---

**作成日**: 2025年2月11日  
**最終更新**: 2025年2月11日  
**更新履歴**:
- 2025-02-11: 初版作成（company_id欠落問題の修正を文書化）
