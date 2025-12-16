# Measure Master (採寸撮影アプリ)

EC出品用AI自動採寸・撮影アプリ。服を平置きして撮影するだけでサイズを自動計測し、出品作業を効率化するFlutterアプリケーション。

## 📱 アプリ概要

### 主な機能
- **AI自動採寸**: 服を撮影するだけで自動的にサイズを計測
- **商品情報管理**: 商品名、ブランド、カテゴリ、状態、価格を入力・管理
- **ダッシュボード**: 出品待ち・下書き商品を一覧表示
- **撮影ガイド**: カメラ画面でガイドライン表示
- **商品詳細**: 素材・カラー選択、寸法確認

### スクリーン構成
1. **ランディング画面**: アプリ紹介とスタート
2. **ダッシュボード**: 商品一覧と管理
3. **新規商品追加**: 商品情報入力
4. **撮影画面**: カメラガイドと撮影
5. **商品詳細**: 詳細情報と出品準備

## 🛠 技術スタック

- **Framework**: Flutter 3.35.4
- **Language**: Dart 3.9.2
- **State Management**: Provider
- **UI**: Material Design 3
- **Fonts**: Google Fonts (Noto Sans JP)

## 📦 主要パッケージ

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: 6.3.3
  provider: 6.1.5+1
  intl: 0.20.2
  image_picker: 1.2.1
  camera: 0.11.3
  path_provider: 2.1.5
  path: 1.9.1
```

## 🚀 セットアップ

### 前提条件
- Flutter SDK 3.35.4
- Dart SDK 3.9.2
- Android Studio (Android開発用)
- Visual Studio Code (推奨)

### インストール手順

1. リポジトリをクローン
```bash
git clone https://github.com/donkodon/saisunsatsuei.git
cd saisunsatsuei
```

2. 依存パッケージをインストール
```bash
flutter pub get
```

3. Webで起動
```bash
flutter run -d chrome
```

4. Androidで起動
```bash
flutter run -d android
```

## 🌐 Web版プレビュー

```bash
# リリースビルド
flutter build web --release

# サーバー起動
cd build/web
python3 -m http.server 5060 --bind 0.0.0.0
```

ブラウザで http://localhost:5060 にアクセス

## 📂 プロジェクト構造

```
lib/
├── main.dart                 # アプリエントリーポイント
├── constants.dart            # カラー・スタイル定数
├── models/
│   └── item.dart            # 商品データモデル
├── providers/
│   └── inventory_provider.dart  # 在庫管理Provider
├── screens/
│   ├── landing_screen.dart   # ランディング画面
│   ├── dashboard_screen.dart # ダッシュボード
│   ├── add_item_screen.dart  # 商品追加画面
│   ├── camera_screen.dart    # 撮影画面
│   └── detail_screen.dart    # 商品詳細画面
└── widgets/
    └── custom_button.dart    # カスタムボタンウィジェット

assets/
└── images/                   # 画像アセット
```

## 🎨 デザイン

- **プライマリカラー**: #00C2E0 (シアンブルー)
- **背景カラー**: #F5F7FA (ライトグレー)
- **フォント**: Noto Sans JP
- **デザインシステム**: Material Design 3

## 📝 開発メモ

### ブランド選択機能
- 30種類の人気ブランドプリセット
- リアルタイム検索機能
- カスタムブランド入力対応

### カラー選択機能
- 16種類のカラープリセット（カラープレビュー付き）
- リアルタイムフィルタリング
- フリー入力対応

### 素材選択機能
- 10種類の素材プリセット
- プルダウン形式

## 🐛 トラブルシューティング

### Web版で入力フィールドが動作しない場合
- ハードリロード (Ctrl+Shift+R / Cmd+Shift+R)
- ブラウザキャッシュをクリア
- シークレットモードで確認

### ビルドエラーが発生する場合
```bash
# キャッシュクリア
flutter clean
rm -rf .dart_tool
flutter pub get

# 再ビルド
flutter build web --release
```

## 📄 ライセンス

このプロジェクトは個人開発用です。

## 👤 開発者

開発者: ケンジさん
組織: STAYGOLD サプライチェーンマネジメント企画部

---

**アプリ名**: Measure Master  
**パッケージ名**: com.measuremaster.measure  
**バージョン**: 1.0.0
