import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:measure_master/constants.dart';

/// add_item_screen から切り出したピッカー系 mixin
///
/// 含まれるもの:
/// - showBrandPickerSheet  (ブランド選択)
/// - showCategoryPickerSheet (カテゴリ選択)
/// - showRankPickerSheet   (商品ランク選択)
/// - showConditionPickerSheet (商品状態選択)
/// - showMaterialPickerSheet (素材選択)
/// - showColorPickerSheet  (カラー選択)
mixin AddItemPickerMixin<T extends StatefulWidget> on State<T> {

  // ────────────────────────────────────────────────────────
  // ブランド選択
  // ────────────────────────────────────────────────────────

  void showBrandPickerSheet({
    required List<String> allBrands,
    required String currentBrand,
    required void Function(String) onSelected,
  }) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredBrands = searchQuery.isEmpty
                ? allBrands
                : allBrands
                    .where((b) =>
                        b.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _bottomSheetHandle(),
                    const SizedBox(height: 16),
                    const Text('ブランドを選択',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _searchField(
                      hint: 'ブランド名で検索...',
                      onChanged: (v) =>
                          setModalState(() => searchQuery = v),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredBrands.length,
                        itemBuilder: (context, index) {
                          final brand = filteredBrands[index];
                          return ListTile(
                            title: Text(brand),
                            trailing: currentBrand == brand
                                ? Icon(Icons.check,
                                    color: AppConstants.primaryCyan)
                                : null,
                            onTap: () {
                              onSelected(brand);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────
  // カテゴリ選択
  // ────────────────────────────────────────────────────────

  void showCategoryPickerSheet({
    required List<String> categories,
    required String currentCategory,
    required void Function(String) onSelected,
  }) {
    _showSimpleListSheet(
      title: 'カテゴリを選択',
      items: categories,
      currentItem: currentCategory,
      onSelected: onSelected,
    );
  }

  // ────────────────────────────────────────────────────────
  // 商品ランク選択
  // ────────────────────────────────────────────────────────

  void showRankPickerSheet({
    required List<String> ranks,
    required String currentRank,
    required void Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bottomSheetHandle(),
              const SizedBox(height: 16),
              const Text('商品ランクを選択',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('L列のデータに対応',
                  style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ranks.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(ranks[index]),
                      trailing: currentRank == ranks[index]
                          ? Icon(Icons.check, color: AppConstants.primaryCyan)
                          : null,
                      onTap: () {
                        onSelected(ranks[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────
  // 商品状態選択
  // ────────────────────────────────────────────────────────

  void showConditionPickerSheet({
    required List<String> conditions,
    required String currentCondition,
    required void Function(String) onSelected,
  }) {
    _showSimpleListSheet(
      title: '商品の状態を選択',
      items: conditions,
      currentItem: currentCondition,
      onSelected: onSelected,
    );
  }

  // ────────────────────────────────────────────────────────
  // 素材選択
  // ────────────────────────────────────────────────────────

  void showMaterialPickerSheet({
    required List<String> materials,
    required String currentMaterial,
    required void Function(String) onSelected,
  }) {
    _showSimpleListSheet(
      title: '素材を選択',
      items: materials,
      currentItem: currentMaterial,
      onSelected: onSelected,
    );
  }

  // ────────────────────────────────────────────────────────
  // カラー選択
  // ────────────────────────────────────────────────────────

  void showColorPickerSheet({
    required Map<String, Color> colorOptions,
    required String currentColor,
    required void Function(String colorName, Color color) onSelected,
  }) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredColors = searchQuery.isEmpty
                ? colorOptions.entries.toList()
                : colorOptions.entries
                    .where((e) =>
                        e.key.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _bottomSheetHandle(),
                    const SizedBox(height: 16),
                    const Text('カラーを選択',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _searchField(
                      hint: 'カラー名で検索 or 自由入力...',
                      onChanged: (v) =>
                          setModalState(() => searchQuery = v),
                      onSubmitted: (v) {
                        if (v.isNotEmpty && !colorOptions.containsKey(v)) {
                          onSelected(v, Colors.grey[400]!);
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (searchQuery.isNotEmpty && filteredColors.isEmpty)
                      _freeInputHint(searchQuery),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredColors.length,
                        itemBuilder: (context, index) {
                          final entry = filteredColors[index];
                          return ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: entry.value,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.grey[300]!, width: 2),
                              ),
                            ),
                            title: Text(entry.key),
                            trailing: currentColor == entry.key
                                ? Icon(Icons.check,
                                    color: AppConstants.primaryCyan)
                                : null,
                            onTap: () {
                              onSelected(entry.key, entry.value);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────
  // 共通ヘルパー（プライベート）
  // ────────────────────────────────────────────────────────

  void _showSimpleListSheet({
    required String title,
    required List<String> items,
    required String currentItem,
    required void Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bottomSheetHandle(),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(items[index]),
                      trailing: currentItem == items[index]
                          ? Icon(Icons.check, color: AppConstants.primaryCyan)
                          : null,
                      onTap: () {
                        onSelected(items[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomSheetHandle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _searchField({
    required String hint,
    required void Function(String) onChanged,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      autofocus: true,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, color: AppConstants.primaryCyan),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppConstants.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppConstants.primaryCyan, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }

  Widget _freeInputHint(String query) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, color: AppConstants.primaryCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$query" として追加',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryCyan),
                ),
                Text(
                  'タップまたはEnterで確定',
                  style: TextStyle(
                      fontSize: 12, color: AppConstants.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 価格入力ダイアログ（独立 StatefulWidget）
// ────────────────────────────────────────────────────────────

class PricePickerDialog extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController tempController;
  final VoidCallback onConfirm;

  const PricePickerDialog({
    super.key,
    required this.controller,
    required this.tempController,
    required this.onConfirm,
  });

  @override
  State<PricePickerDialog> createState() => _PricePickerDialogState();
}

class _PricePickerDialogState extends State<PricePickerDialog> {
  late FocusNode _focusNode;
  bool _hasFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (kDebugMode) {
        debugPrint('🔍 Price TextField focus: ${_focusNode.hasFocus}');
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFocused) {
      _hasFocused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
          if (widget.tempController.text.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                widget.tempController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: widget.tempController.text.length,
                );
              }
            });
          }
        }
      });
    }

    return AlertDialog(
      title: const Text('販売価格を入力'),
      content: SizedBox(
        width: 280,
        child: TextFormField(
          controller: widget.tempController,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          enableInteractiveSelection: true,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          onChanged: (value) {
            if (kDebugMode) {
              debugPrint('💰 Price input changed: $value');
            }
          },
          onTap: () {
            if (widget.tempController.text.isNotEmpty) {
              widget.tempController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: widget.tempController.text.length,
              );
            }
          },
          decoration: InputDecoration(
            prefixText: '¥ ',
            prefixStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppConstants.textDark),
            hintText: '0',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppConstants.primaryCyan, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppConstants.primaryCyan, width: 2),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryCyan,
          ),
          child:
              const Text('確定', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
