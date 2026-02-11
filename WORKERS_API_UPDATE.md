# 🔧 Cloudflare Workers API 修正ガイド

## 🚨 問題点

現在、Flutter側から送信されたファイル名が無視され、Workers側で独自のファイル名が生成されています。

**現在の動作:**
```
Flutter側送信: 1025L290001_1.jpg
↓
Workers側保存: 1767164762649_0_1767164762649.jpg (ランダム生成)
```

**期待される動作:**
```
Flutter側送信: 1025L290001_1.jpg
↓
Workers側保存: 1025L290001_1.jpg (同じファイル名)
```

---

## ✅ 解決方法

### Flutter側の対応（✅ 実装済み）

Flutter側は、ファイル名を **URLパラメータ** と **Multipart filename** の両方で送信するように修正しました。

```dart
// ファイル名をURLパラメータとして追加
final uploadUrl = Uri.parse('$uploadEndpoint?filename=$fileName');

// Multipartリクエストを作成
final request = http.MultipartRequest('POST', uploadUrl);
request.files.add(
  http.MultipartFile.fromBytes(
    'file',
    imageBytes,
    filename: fileName,  // ← Multipart filenameも設定
  ),
);
```

**送信例:**
```
POST https://image-upload-api.jinkedon2.workers.dev/upload?filename=1025L290001_1.jpg
Content-Type: multipart/form-data
```

---

### Workers側の修正（🔧 要対応）

Workers API (`https://image-upload-api.jinkedon2.workers.dev`) のコードを以下のように修正してください。

#### 修正前のコード（推測）

```javascript
export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const formData = await request.formData();
    const file = formData.get('file');
    
    // ❌ 問題: 独自のファイル名を生成している
    const fileName = `${Date.now()}_${Math.floor(Math.random() * 1000)}_${Date.now()}.jpg`;
    
    await env.MY_BUCKET.put(fileName, file);
    
    return new Response(JSON.stringify({
      url: `https://pub-300562464768499b8fcaee903d0f9861.r2.dev/${fileName}`
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
}
```

#### ✅ 修正後のコード

```javascript
export default {
  async fetch(request, env) {
    // CORS対応
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        }
      });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    try {
      // ✅ URLパラメータからファイル名を取得
      const url = new URL(request.url);
      let fileName = url.searchParams.get('filename');
      
      const formData = await request.formData();
      const file = formData.get('file');
      
      if (!file) {
        return new Response(JSON.stringify({ error: 'No file uploaded' }), { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      
      // ✅ URLパラメータがない場合はMultipartのfilenameを使用
      if (!fileName) {
        fileName = file.name || `${Date.now()}.jpg`;
      }
      
      // ✅ .jpg拡張子を確保
      if (!fileName.endsWith('.jpg') && !fileName.endsWith('.jpeg')) {
        fileName = `${fileName}.jpg`;
      }
      
      console.log(`📤 Uploading file: ${fileName}`);
      
      // R2にアップロード
      await env.MY_BUCKET.put(fileName, file);
      
      // 公開URLを返す
      const publicUrl = `https://pub-300562464768499b8fcaee903d0f9861.r2.dev/${fileName}`;
      
      return new Response(JSON.stringify({
        url: publicUrl,
        fileName: fileName
      }), {
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
      
    } catch (error) {
      console.error('Upload error:', error);
      return new Response(JSON.stringify({ 
        error: error.message 
      }), { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
}
```

---

## 🔍 修正のポイント

### 1. URLパラメータからファイル名を取得
```javascript
const url = new URL(request.url);
let fileName = url.searchParams.get('filename');
```

### 2. フォールバック処理
```javascript
if (!fileName) {
  fileName = file.name || `${Date.now()}.jpg`;
}
```

### 3. 拡張子の確保
```javascript
if (!fileName.endsWith('.jpg') && !fileName.endsWith('.jpeg')) {
  fileName = `${fileName}.jpg`;
}
```

---

## 🧪 テスト方法

### テスト1: Flutter側から画像アップロード

1. Flutterアプリで商品を撮影
2. SKUコード入力: `1025L290001`
3. 商品確定ボタンを押す
4. コンソールログで確認:
   ```
   📦 File name: 1025L290001_1.jpg
   📤 Uploading to Cloudflare Workers: https://image-upload-api.jinkedon2.workers.dev/upload?filename=1025L290001_1.jpg
   ✅ Workers経由でアップロード成功: https://pub-300562464768499b8fcaee903d0f9861.r2.dev/1025L290001_1.jpg
   ```

### テスト2: curlでテスト

```bash
curl -X POST \
  'https://image-upload-api.jinkedon2.workers.dev/upload?filename=TEST_1.jpg' \
  -F 'file=@/path/to/test.jpg'
```

**期待されるレスポンス:**
```json
{
  "url": "https://pub-300562464768499b8fcaee903d0f9861.r2.dev/TEST_1.jpg",
  "fileName": "TEST_1.jpg"
}
```

---

## 📋 修正チェックリスト

- [ ] Workers API コードを修正
- [ ] Cloudflare Workers にデプロイ
- [ ] curlコマンドでテスト
- [ ] Flutterアプリからテスト
- [ ] R2バケットでファイル名を確認
- [ ] 複数画像のアップロードテスト

---

## 🔗 関連ファイル

### Flutter側
- `/lib/services/cloudflare_storage_service.dart` - アップロード処理
- `/lib/screens/detail_screen.dart` - 商品確定時のアップロード

### Workers側
- Workers URL: `https://image-upload-api.jinkedon2.workers.dev`
- R2 Bucket: (バケット名を確認してください)
- Public Domain: `pub-300562464768499b8fcaee903d0f9861.r2.dev`

---

## 📞 サポート

Workers API の修正後、以下を確認してください:

1. ✅ ファイル名が正しく保存されているか
2. ✅ 画像URLが正しい形式か
3. ✅ 複数画像のアップロードが正常に動作するか

問題が発生した場合は、Workers のログを確認してください。

---

**最終更新日**: 2024-12-31  
**対応状況**: Flutter側 ✅完了 / Workers側 🔧要対応
