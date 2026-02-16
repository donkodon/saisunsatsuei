# 🔍 ログ出力確認ガイド

## 📱 ログが出ない原因と対処法

### ✅ 追加した強制ログ

以下の3箇所に **必ず出力される** ログを追加しました（`kDebugMode` に関係なく `print()` で出力）:

#### 1️⃣ **アプリ起動時ログ** (`lib/main.dart`)
```
🚀🚀🚀 アプリ起動しました！ 🚀🚀🚀
⏰ 起動時刻: 2025-01-21 10:30:45.123
🔍 このログが見えない場合、ログ出力環境に問題があります
```

#### 2️⃣ **商品詳細画面への遷移ログ** (`lib/screens/add_item_screen.dart`)
「次へ」ボタンを押したとき:
```
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📱 商品詳細画面への遷移
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📏 AI自動採寸トグル: ✅ ON または ❌ OFF
📸 画像数: 3枚
📦 商品名: テストシャツ
🏷️  SKU: TEST001
→ DetailScreen に aiMeasureEnabled=true を渡す
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
```

#### 3️⃣ **商品確定ボタン押下ログ** (`lib/screens/detail_screen.dart`)
「商品確定」ボタンを押したとき:
```
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
✅ 商品確定ボタンが押されました
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📏 AI自動採寸トグル: ✅ ON または ❌ OFF
📸 アップロード済み画像: ✅ あり または ❌ なし
📸 画像数: 3枚
🎯 最初の画像URL: https://...
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
```

#### 4️⃣ **MeasurementService 実行ログ** (`lib/features/measurement/logic/measurement_service.dart`)
AI採寸が実行されるとき:
```
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
🤖 MeasurementService 実行開始
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📥 パラメータ:
   imageUrl: https://...
   sku: TEST001
   companyId: xxx
   category: トップス
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
```

成功時:
```
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
✅ AI採寸リクエスト送信成功！
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📡 prediction_id: abc123def456
💾 ローカルDB記録完了
⏳ Webhook経由でD1に以下が保存されます:
   - measurements (肩幅/袖丈/着丈/身幅)
   - ai_landmarks (ランドマーク座標)
   - reference_object (基準物体情報)
   - measurement_image_url (採寸画像)
   - mask_image_url (マスク画像)
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
```

---

## 🔍 ログの確認方法

### Android Studio / IntelliJ IDEA の場合
1. **Run** タブを開く
2. フィルターに `🔥` または `🚀` を入力
3. ログが表示されるはず

### VS Code の場合
1. **デバッグコンソール** を開く
2. フィルターに `🔥` または `🚀` を入力
3. ログが表示されるはず

### Android 実機の場合（`adb logcat`）
```bash
# ターミナルで実行
adb logcat | grep -E "🔥|🚀|MeasurementService"
```

### iOS シミュレーターの場合（Xcode Console）
1. Xcode を開く
2. **Window > Devices and Simulators** を開く
3. シミュレーターを選択し、**Open Console** をクリック
4. フィルターに `🔥` または `🚀` を入力

---

## ❌ ログが全く出ない場合

### 原因1: リリースビルドで実行している
- **対処法**: デバッグモードで実行してください
  ```bash
  flutter run --debug
  ```

### 原因2: ログ出力が抑制されている
- **対処法**: `flutter run` を実行し、ターミナルでログを直接確認

### 原因3: アプリがクラッシュしている
- **対処法**: 
  ```bash
  flutter clean
  flutter pub get
  flutter run --debug
  ```

### 原因4: IDE のログフィルターが強すぎる
- **対処法**: すべてのフィルターを解除し、ログレベルを「Verbose」に設定

---

## 🧪 テスト手順

1. **アプリ起動**
   - ✅ `🚀🚀🚀 アプリ起動しました！` が出るか確認

2. **AI自動採寸トグルをONにする**
   - AddItemScreen で AI採寸スイッチを ON

3. **画像を撮影（最低1枚）**
   - カメラアイコンをタップ → 撮影

4. **商品名、SKU を入力**
   - 商品名: 「テストシャツ」
   - SKU: 「TEST001」

5. **「次へ」ボタンを押す**
   - ✅ `📱 商品詳細画面への遷移` ログが出るか確認
   - ✅ `📏 AI自動採寸トグル: ✅ ON` が表示されるか確認

6. **「商品確定」ボタンを押す**
   - ✅ `✅ 商品確定ボタンが押されました` ログが出るか確認
   - ✅ `📏 AI自動採寸トグル: ✅ ON` が表示されるか確認
   - ✅ `🤖 MeasurementService 実行開始` ログが出るか確認
   - ✅ `✅ AI採寸リクエスト送信成功！` ログが出るか確認

---

## 📊 期待される正常ログの流れ

```
🚀🚀🚀 アプリ起動しました！ 🚀🚀🚀
⏰ 起動時刻: 2025-01-21 10:30:45.123
🔍 このログが見えない場合、ログ出力環境に問題があります

（中略）

🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📱 商品詳細画面への遷移
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📏 AI自動採寸トグル: ✅ ON
📸 画像数: 3枚
📦 商品名: テストシャツ
🏷️  SKU: TEST001
→ DetailScreen に aiMeasureEnabled=true を渡す
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥

🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
✅ 商品確定ボタンが押されました
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📏 AI自動採寸トグル: ✅ ON
📸 アップロード済み画像: ✅ あり
📸 画像数: 3枚
🎯 最初の画像URL: https://firebasestorage.googleapis.com/...
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥

🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
🤖 MeasurementService 実行開始
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📥 パラメータ:
   imageUrl: https://firebasestorage.googleapis.com/...
   sku: TEST001
   companyId: xxx
   category: トップス
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥

🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
✅ AI採寸リクエスト送信成功！
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
📡 prediction_id: abc123def456
💾 ローカルDB記録完了
⏳ Webhook経由でD1に以下が保存されます:
   - measurements (肩幅/袖丈/着丈/身幅)
   - ai_landmarks (ランドマーク座標)
   - reference_object (基準物体情報)
   - measurement_image_url (採寸画像)
   - mask_image_url (マスク画像)
🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥
```

---

## 🆘 それでもログが出ない場合

以下の情報を共有してください:

1. **実行環境**
   - IDE: Android Studio / VS Code / その他
   - OS: Windows / macOS / Linux
   - デバイス: 実機 / シミュレーター / エミュレーター

2. **実行コマンド**
   ```bash
   # 使用したコマンドを教えてください
   flutter run --debug
   # または
   flutter run --release
   ```

3. **エラーメッセージ**
   - アプリがクラッシュする場合は、エラーメッセージを共有

4. **ログの有無**
   - `🚀🚀🚀 アプリ起動しました！` すら出ない → ログ出力環境に問題
   - `🚀🚀🚀 アプリ起動しました！` は出るが、以降のログが出ない → AI採寸が実行されていない

---

## ✅ 正常に動作している場合

上記のログが **すべて** 出力されている場合:
- ✅ AI自動採寸機能は正常に動作しています
- ✅ Webhook経由で D1 に結果が保存されます
- ✅ `prediction_id` を使って D1 で結果を確認できます

### D1 での確認方法

Cloudflare ダッシュボードで以下の SQL を実行:
```sql
SELECT 
  sku,
  measurements,
  ai_landmarks,
  reference_object,
  measurement_image_url,
  mask_image_url,
  updated_at
FROM product_items
WHERE sku = 'TEST001'
ORDER BY updated_at DESC
LIMIT 1;
```

結果が空の場合、Webhook が正しく動作していない可能性があります。
