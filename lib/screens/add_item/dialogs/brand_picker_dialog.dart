import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// ブランド選択ダイアログ
/// 
/// 使い方:
/// ```dart
/// final selectedBrand = await showBrandPickerDialog(
///   context: context,
///   currentValue: _brandController.text,
/// );
/// if (selectedBrand != null) {
///   setState(() {
///     _brandController.text = selectedBrand;
///   });
/// }
/// ```
Future<String?> showBrandPickerDialog({
  required BuildContext context,
  String? currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => BrandPickerDialog(currentValue: currentValue),
  );
}

class BrandPickerDialog extends StatefulWidget {
  final String? currentValue;

  const BrandPickerDialog({
    super.key,
    this.currentValue,
  });

  @override
  State<BrandPickerDialog> createState() => _BrandPickerDialogState();
}

class _BrandPickerDialogState extends State<BrandPickerDialog> {
  String _searchQuery = '';

  // ブランドリスト（定数化）
  static const List<String> _allBrands = [
    'Uniqlo',
    'GU',
    'ZARA',
    'H&M',
    'Nike',
    'Adidas',
    'Levi\'s',
    'Gap',
    'Muji',
    'Beams',
    'United Arrows',
    'Gucci',
    'Louis Vuitton',
    'Prada',
    'Chanel',
    'Hermès',
    'Burberry',
    'Ralph Lauren',
    'Tommy Hilfiger',
    'Calvin Klein',
    'The North Face',
    'Patagonia',
    'Columbia',
    'Champion',
    'New Balance',
    'Converse',
    'Vans',
    'Supreme',
    'Stussy',
    'Carhartt',
  ];

  @override
  Widget build(BuildContext context) {
    // 検索フィルタリング
    final filteredBrands = _searchQuery.isEmpty
        ? _allBrands
        : _allBrands
            .where((brand) => brand.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ハンドルバー
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // タイトル
          const Text(
            "ブランドを選択",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 検索フィールド
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'ブランド名で検索...',
              prefixIcon: const Icon(Icons.search, color: AppConstants.primaryCyan),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppConstants.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppConstants.primaryCyan, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // ブランドリスト
          Expanded(
            child: ListView.builder(
              itemCount: filteredBrands.length,
              itemBuilder: (context, index) {
                final brand = filteredBrands[index];
                final isSelected = widget.currentValue == brand;

                return ListTile(
                  title: Text(brand),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppConstants.primaryCyan)
                      : null,
                  onTap: () {
                    // 選択したブランドを返す
                    Navigator.pop(context, brand);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
