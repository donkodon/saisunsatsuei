import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// 📋 詳細画面の商品情報セクション（StatelessWidget）
///
/// 責務:
/// - 商品名・カテゴリ・ブランド・バーコード・SKU・ランク・サイズ・カラー・価格カード
/// - 商品の状態・詳細リスト（素材/カラー picker 連携）
/// - 実寸カード（着丈・身幅・肩幅・袖丈）
/// - 商品の説明 TextField（文字数カウンター付き）
class DetailScreenInfoSection extends StatelessWidget {
  // ── 基本フィールド ──────────────────────────────────────────
  final String itemName;
  final String brand;
  final String category;
  final String condition;
  final String price;
  final String productRank;

  // ── コントローラ（親 State から渡す） ──────────────────────
  final TextEditingController barcodeController;
  final TextEditingController skuController;
  final TextEditingController sizeController;
  final TextEditingController descriptionController;
  final ValueNotifier<int> charCount;

  // ── 選択中の値 ──────────────────────────────────────────────
  final String selectedMaterial;
  final String selectedColor;
  final Color colorPreview;

  // ── picker コールバック ─────────────────────────────────────
  final VoidCallback onMaterialTap;
  final VoidCallback onColorTap;

  // ── 実寸データ ──────────────────────────────────────────────
  final String? length;
  final String? width;
  final String? shoulder;
  final String? sleeve;

  const DetailScreenInfoSection({
    super.key,
    required this.itemName,
    required this.brand,
    required this.category,
    required this.condition,
    required this.price,
    required this.productRank,
    required this.barcodeController,
    required this.skuController,
    required this.sizeController,
    required this.descriptionController,
    required this.charCount,
    required this.selectedMaterial,
    required this.selectedColor,
    required this.colorPreview,
    required this.onMaterialTap,
    required this.onColorTap,
    this.length,
    this.width,
    this.shoulder,
    this.sleeve,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicInfoCard(),
        const SizedBox(height: 24),
        _buildDetailsSection(),
        const SizedBox(height: 24),
        _buildMeasurementsSection(),
        const SizedBox(height: 24),
        _buildDescriptionSection(),
      ],
    );
  }

  // ── 基本情報カード ─────────────────────────────────────────
  Widget _buildBasicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('商品名', style: AppConstants.captionStyle),
          const SizedBox(height: 4),
          Text(itemName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            left: _labelValue('カテゴリー', category),
            right: _labelValue('ブランド', brand.isEmpty ? '未設定' : brand),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            left: _labelValue(
              'バーコード',
              barcodeController.text.isEmpty ? '未設定' : barcodeController.text,
              fontSize: 12,
            ),
            right: _labelValue(
              'SKU',
              skuController.text.isEmpty ? '未設定' : skuController.text,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            left: _buildRankCell(),
            right: _labelValue(
              'サイズ',
              sizeController.text.isEmpty ? '未設定' : sizeController.text,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            left: _labelValue('カラー', selectedColor),
            right: _buildPriceCell(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required Widget left, required Widget right}) {
    return Row(children: [Expanded(child: left), Expanded(child: right)]);
  }

  Widget _labelValue(String label, String value, {double fontSize = 14}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppConstants.captionStyle),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
      ],
    );
  }

  Widget _buildRankCell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('商品ランク', style: AppConstants.captionStyle),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppConstants.primaryCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            productRank == '選択してください' ? '-' : productRank,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryCyan,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('販売価格', style: AppConstants.captionStyle),
        const SizedBox(height: 4),
        Text(
          price.isEmpty ? '未設定' : '¥$price',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppConstants.primaryCyan,
          ),
        ),
      ],
    );
  }

  // ── 状態・詳細リスト ────────────────────────────────────────
  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('商品の状態・詳細',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ListTile(
                title: Text('商品の状態',
                    style: TextStyle(
                        fontSize: 12, color: AppConstants.primaryCyan)),
                subtitle: Text(condition,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDark)),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppConstants.primaryCyan,
                      shape: BoxShape.circle),
                  child: Text(
                    _conditionGrade(condition),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('素材',
                    style: TextStyle(
                        fontSize: 12, color: AppConstants.primaryCyan)),
                subtitle: Text(selectedMaterial,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDark)),
                trailing: const Icon(Icons.chevron_right),
                onTap: onMaterialTap,
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('カラー',
                    style: TextStyle(
                        fontSize: 12, color: AppConstants.primaryCyan)),
                subtitle: Text(selectedColor,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDark)),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorPreview,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                onTap: onColorTap,
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('サイズ',
                    style: TextStyle(
                        fontSize: 12, color: AppConstants.primaryCyan)),
                subtitle: Text(
                    sizeController.text.isEmpty
                        ? '未設定'
                        : sizeController.text,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDark)),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 実寸カード ──────────────────────────────────────────────
  Widget _buildMeasurementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('サイズ (cm)',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 12, color: AppConstants.primaryCyan),
                  const SizedBox(width: 4),
                  Text('AI自動採寸',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppConstants.primaryCyan,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _measureCard('着丈', length ?? '', _hasValue(length))),
            const SizedBox(width: 12),
            Expanded(
                child: _measureCard('身幅', width ?? '', _hasValue(width))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child:
                    _measureCard('肩幅', shoulder ?? '', _hasValue(shoulder))),
            const SizedBox(width: 12),
            Expanded(
                child: _measureCard('袖丈', sleeve ?? '', _hasValue(sleeve))),
          ],
        ),
      ],
    );
  }

  // ── 説明 TextField ──────────────────────────────────────────
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('商品の説明',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: TextField(
            controller: descriptionController,
            maxLines: 6,
            minLines: 6,
            maxLength: 1000,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  '傷や汚れ、特徴などを入力してください...\n\n例：\n・着用回数：3回程度\n・目立った傷や汚れなし\n・サイズ感：普通\n・素材感：柔らかめ',
              hintStyle:
                  TextStyle(color: AppConstants.textGrey, fontSize: 14),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterText: '',
            ),
            style: TextStyle(
                fontSize: 14, color: AppConstants.textDark, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<int>(
            valueListenable: charCount,
            builder: (_, count, __) => Text(
              '$count/1000',
              style:
                  TextStyle(fontSize: 12, color: AppConstants.textGrey),
            ),
          ),
        ),
      ],
    );
  }

  // ── ヘルパー ─────────────────────────────────────────────────
  bool _hasValue(String? v) => v != null && v.isNotEmpty;

  String _conditionGrade(String condition) {
    switch (condition) {
      case '新品・未使用':        return 'S';
      case '未使用に近い':        return 'A';
      case '目立った傷や汚れなし': return 'B';
      case 'やや傷や汚れあり':   return 'C';
      case '傷や汚れあり':       return 'D';
      case '全体的に状態が悪い':  return 'E';
      default:                   return 'N';
    }
  }

  Widget _measureCard(String label, String value, bool isVerified) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? AppConstants.primaryCyan : Colors.grey[300]!,
          width: isVerified ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isVerified
                      ? AppConstants.primaryCyan
                      : AppConstants.textDark)),
          if (isVerified) ...[
            const SizedBox(height: 4),
            Icon(Icons.check_circle,
                size: 16, color: AppConstants.primaryCyan),
          ],
        ],
      ),
    );
  }
}
