import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/core/widgets/smart_image_viewer.dart';
import 'package:measure_master/core/utils/app_feedback.dart';

/// 🔄 画像並び替え画面（ドラッグ&ドロップ対応）
///
/// 責務:
/// - ドラッグ&ドロップで画像の順番を変更（Web/モバイル対応）
/// - リアルタイムでsequenceを更新
/// - 変更をFirebase/D1に保存
class ImageReorderScreen extends StatefulWidget {
  final List<ImageItem> images;
  final Function(List<ImageItem> reorderedImages) onReorder;

  const ImageReorderScreen({
    super.key,
    required this.images,
    required this.onReorder,
  });

  @override
  State<ImageReorderScreen> createState() => _ImageReorderScreenState();
}

class _ImageReorderScreenState extends State<ImageReorderScreen> {
  late List<ImageItem> _images;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
  }

  /// 🔄 ドラッグ&ドロップで順番変更時の処理
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListViewの仕様: newIndexがoldIndexより大きい場合は-1する
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      
      // リストの順番を変更
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);

      // 全画像のsequenceを再計算（1から始まる連番）
      _images = _images.asMap().entries.map((entry) {
        final index = entry.key;
        final imageItem = entry.value;
        return imageItem.copyWithSequence(
          index + 1,
          isMain: index == 0, // 最初の画像をメインに設定
        );
      }).toList();

      _hasChanges = true;
    });
  }

  /// 💾 変更を保存
  void _saveChanges() {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    // 変更を親画面に通知
    widget.onReorder(_images);
    
    AppFeedback.showSuccess(
      context, 
      '画像の順番を変更しました（${_images.length}枚）',
    );
    
    Navigator.pop(context);
  }

  /// ❌ 変更を破棄して戻る
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('変更を破棄しますか？'),
        content: const Text('並び替えた内容が保存されていません。\n本当に戻りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('破棄する'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            '画像の順番を変更',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppConstants.primaryCyan,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '未保存',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // ── 説明バナー ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppConstants.primaryCyan.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppConstants.primaryCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '画像を長押ししてドラッグすると順番を変更できます',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── ドラッグ&ドロップ可能な画像リスト ────────────
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _images.length,
                onReorder: _onReorder,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final double animValue = Curves.easeInOut.transform(animation.value);
                      final double scale = 1.0 + (animValue * 0.05);
                      return Transform.scale(
                        scale: scale,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final imageItem = _images[index];
                  final isMain = index == 0;
                  
                  return _ImageDraggableTile(
                    key: ValueKey(imageItem.id),
                    imageItem: imageItem,
                    index: index,
                    isMain: isMain,
                  );
                },
              ),
            ),

            // ── 保存ボタン ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasChanges 
                          ? AppConstants.primaryCyan 
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      elevation: _hasChanges ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _hasChanges ? '変更を保存' : '変更なし',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 📸 ドラッグ可能な画像タイル
class _ImageDraggableTile extends StatelessWidget {
  final ImageItem imageItem;
  final int index;
  final bool isMain;

  const _ImageDraggableTile({
    super.key,
    required this.imageItem,
    required this.index,
    required this.isMain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain 
              ? AppConstants.primaryCyan 
              : Colors.grey[300]!,
          width: isMain ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── ドラッグハンドル + 順番バッジ ──────────────
          Container(
            width: 60,
            height: 100,
            decoration: BoxDecoration(
              color: isMain 
                  ? AppConstants.primaryCyan 
                  : Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drag_indicator,
                  color: isMain ? Colors.white : Colors.grey[600],
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isMain ? Colors.white : Colors.grey[700],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ── 画像プレビュー ──────────────────
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 84,
                height: 84,
                child: SmartImageViewer.fromImageItem(
                  imageItem: imageItem,
                  fit: BoxFit.cover,
                  showWhiteBackground: false,
                  width: 84,
                  height: 84,
                  borderRadius: 8,
                ),
              ),
            ),
          ),

          // ── メイン画像ラベル + 説明 ────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMain)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'メイン画像',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (!isMain)
                    Text(
                      'サブ画像',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '長押しでドラッグ',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 右側の余白 ──────────────────────
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
