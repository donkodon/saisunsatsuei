import 'package:flutter/material.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InventoryProvider with ChangeNotifier {
  static const String _boxName = 'inventory_items';

  // ─── Hive ────────────────────────────────────────────────
  Box<InventoryItem>? _box;

  // ─── 全件データ（フィルタ済み・ソート済み） ──────────────
  List<InventoryItem> _items = [];

  // ─── 企業ID ─────────────────────────────────────────────
  String? _currentCompanyId;

  // ─── カウントキャッシュ（O(1) アクセス） ─────────────────
  int _cachedReadyCount = 0;
  int _cachedDraftCount = 0;

  // ─── ページネーション ─────────────────────────────────────
  static const int _pageSize = 20; // 1ページあたりの件数
  int _displayedCount = _pageSize;  // 現在表示中の件数

  // ─── 初期化 ───────────────────────────────────────────────
  Future<void> initialize({String? companyId}) async {
    _box = await Hive.openBox<InventoryItem>(_boxName);
    _currentCompanyId = companyId;
    _displayedCount = _pageSize; // ページをリセット
    _loadItemsFromBox();
  }

  // ─── 企業ID セッター ──────────────────────────────────────
  void setCompanyId(String companyId) {
    _currentCompanyId = companyId;
    _displayedCount = _pageSize;
    _loadItemsFromBox();
  }

  // ─── ProxyProvider 用: 同じIDなら何もしない ──────────────
  void setCompanyIdIfChanged(String companyId) {
    if (_currentCompanyId == companyId) return;
    _currentCompanyId = companyId;
    _displayedCount = _pageSize;
    _loadItemsFromBox();
  }

  // ─── Hive から全件読み込み + カウントキャッシュ更新 ───────
  void _loadItemsFromBox() {
    if (_box != null && _box!.isNotEmpty) {
      // 重複排除
      final uniqueItems = <String, InventoryItem>{};
      for (final item in _box!.values) {
        uniqueItems[item.id] = item;
      }

      var filtered = uniqueItems.values.toList();

      // 企業IDフィルタ
      if (_currentCompanyId != null && _currentCompanyId!.isNotEmpty) {
        filtered = filtered
            .where((item) => item.companyId == _currentCompanyId)
            .toList();
      }

      // 日付降順ソート
      filtered.sort((a, b) => b.date.compareTo(a.date));
      _items = filtered;
    } else {
      _items = [];
    }

    // ─── カウントをO(n)で一度だけ計算してキャッシュ ─────────
    _updateCountCache();

    notifyListeners();
  }

  /// キャッシュを _items から一括計算（呼び出し元はO(1)でアクセス可能）
  void _updateCountCache() {
    int ready = 0;
    int draft = 0;
    for (final item in _items) {
      if (item.status == 'Ready') {
        ready++;
      } else if (item.status == 'Draft') {
        draft++;
      }
    }
    _cachedReadyCount = ready;
    _cachedDraftCount = draft;
  }

  // ─── 公開ゲッター ─────────────────────────────────────────

  /// 全件リスト（フィルタ・ソート済み）
  List<InventoryItem> get items => _items;

  /// 現在表示中のページ分のみ返す（Dashboard の一覧表示用）
  List<InventoryItem> get pagedItems =>
      _items.length <= _displayedCount ? _items : _items.sublist(0, _displayedCount);

  /// 次のページを読み込む
  bool get hasMore => _displayedCount < _items.length;

  void loadNextPage() {
    if (!hasMore) return;
    _displayedCount += _pageSize;
    notifyListeners();
  }

  /// ページをリセット（画面再表示時などに呼ぶ）
  void resetPage() {
    if (_displayedCount == _pageSize) return; // 変化なし
    _displayedCount = _pageSize;
    notifyListeners();
  }

  /// Ready 件数（O(1) — 毎回スキャン不要）
  int get readyCount => _cachedReadyCount;

  /// Draft 件数（O(1) — 毎回スキャン不要）
  int get draftCount => _cachedDraftCount;

  // ─── 商品追加 (Upsert by SKU) ────────────────────────────
  Future<void> addItem(InventoryItem item) async {
    final itemToSave = (item.companyId == null || item.companyId!.isEmpty)
        ? item.copyWith(companyId: _currentCompanyId)
        : item;

    // SKU重複チェック
    final existingItem = _items.cast<InventoryItem?>().firstWhere(
      (e) =>
          e != null &&
          e.sku != null &&
          e.sku!.isNotEmpty &&
          e.sku == itemToSave.sku,
      orElse: () => null,
    );

    if (existingItem != null) {
      // Hive から旧エントリを全削除
      if (_box != null) {
        final keysToDelete = <dynamic>[];
        for (final key in _box!.keys) {
          final boxItem = _box!.get(key);
          if (boxItem != null && boxItem.sku == itemToSave.sku) {
            keysToDelete.add(key);
          }
        }
        for (final key in keysToDelete) {
          await _box!.delete(key);
        }
      }
      _items.removeWhere((i) => i.sku == itemToSave.sku);
    }

    _items.insert(0, itemToSave);

    if (_box != null) {
      await _box!.put(itemToSave.id, itemToSave);
    }

    // カウントキャッシュを更新
    _updateCountCache();
    notifyListeners();
  }

  // ─── SKU / バーコードで検索 ───────────────────────────────
  InventoryItem? findBySku(String sku) {
    try {
      return _items.firstWhere(
        (item) => item.sku == sku || item.barcode == sku,
      );
    } catch (e) {
      return null;
    }
  }

  // ─── 画像URL更新 ──────────────────────────────────────────
  Future<void> updateItemImages(String sku, List<String> newImageUrls) async {
    if (sku.isEmpty) return;

    final index = _items.indexWhere((item) => item.sku == sku);
    if (index == -1) return;

    final existingItem = _items[index];
    final updatedItem = existingItem.copyWith(
      imageUrl: newImageUrls.isNotEmpty ? newImageUrls.first : existingItem.imageUrl,
      imageUrls: newImageUrls,
    );

    _items[index] = updatedItem;

    if (_box != null) {
      await _box!.put(existingItem.id, updatedItem);
    }

    notifyListeners();
  }

  // ─── 特定画像を削除 ──────────────────────────────────────
  Future<void> removeImageFromItem(String sku, String imageUrl) async {
    if (sku.isEmpty) return;

    final existingItem = findBySku(sku);
    if (existingItem == null) return;

    final currentImages = List<String>.from(existingItem.imageUrls ?? []);
    currentImages.remove(imageUrl);

    await updateItemImages(sku, currentImages);
  }
}
