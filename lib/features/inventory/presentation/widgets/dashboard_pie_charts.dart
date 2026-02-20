import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:measure_master/constants.dart';

/// 📊 ダッシュボード用円グラフウィジェット（リファクタリング版）
class DashboardPieCharts extends StatelessWidget {
  final Map<String, int> userCategoryData;
  final int userTotal;
  final Map<String, int> teamCategoryData;
  final int teamTotal;

  const DashboardPieCharts({
    super.key,
    required this.userCategoryData,
    required this.userTotal,
    required this.teamCategoryData,
    required this.teamTotal,
  });

  // 🎨 カラーパレット（定数化）
  static const _chartColors = [
    AppConstants.primaryCyan,
    AppConstants.successGreen,
    AppConstants.warningOrange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
  ];

  // 📐 共通定数
  static const _chartHeight = 150.0;
  static const _chartRadius = 55.0;
  static const _centerSpaceRadius = 40.0;
  static const _sectionSpacing = 2.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PieChartCard(
            icon: Icons.person,
            iconColor: AppConstants.primaryCyan,
            title: '本人の登録商品',
            count: userTotal,
            countColor: AppConstants.primaryCyan,
            chart: _buildChart(
              hasData: userTotal > 0,
              sections: _buildSections(userCategoryData, userTotal),
            ),
            footer: userTotal > 0 ? _buildLegend(userCategoryData) : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _PieChartCard(
            icon: Icons.groups,
            iconColor: AppConstants.successGreen,
            title: 'チーム全体',
            count: teamTotal,
            countColor: AppConstants.successGreen,
            chart: _buildChart(
              hasData: teamTotal > 0,
              sections: _buildSections(teamCategoryData, teamTotal),
            ),
            footer: teamTotal > 0 ? _buildLegend(teamCategoryData) : null,
          ),
        ),
      ],
    );
  }

  /// 📊 円グラフウィジェット（共通化）
  Widget _buildChart({
    required bool hasData,
    required List<PieChartSectionData> sections,
    double sectionsSpace = _sectionSpacing,
  }) {
    if (!hasData) {
      return const _EmptyChart();
    }

    return SizedBox(
      height: _chartHeight,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: sectionsSpace,
          centerSpaceRadius: _centerSpaceRadius,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  /// 📊 円グラフセクション生成（共通化）
  List<PieChartSectionData> _buildSections(Map<String, int> categoryData, int total) {
    return categoryData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final color = _chartColors[index % _chartColors.length];
      final percentage = (category.value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        value: category.value.toDouble(),
        color: color,
        radius: _chartRadius,
        title: '$percentage%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  /// 🏷️ 凡例生成（共通化）
  Widget _buildLegend(Map<String, int> categoryData) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: categoryData.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final color = _chartColors[index % _chartColors.length];

        return _LegendItem(
          color: color,
          label: category.key,
          count: category.value,
        );
      }).toList(),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 📦 内部ウィジェット（プライベート）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 📊 円グラフカード（共通化）
class _PieChartCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final Color countColor;
  final Widget chart;
  final Widget? footer;

  const _PieChartCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.countColor,
    required this.chart,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _CardHeader(icon: icon, iconColor: iconColor, title: title),
            const SizedBox(height: 8),
            _CountDisplay(count: count, color: countColor),
            const SizedBox(height: 16),
            chart,
            const SizedBox(height: 8),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

/// 📌 カードヘッダー（アイコン + タイトル）
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppConstants.headerStyle.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}

/// 🔢 件数表示
class _CountDisplay extends StatelessWidget {
  final int count;
  final Color color;

  const _CountDisplay({
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count 件',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

/// ⚪ 空データ表示
class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: const Text(
        'データなし',
        style: TextStyle(color: AppConstants.textGrey),
      ),
    );
  }
}

/// 🏷️ 凡例アイテム
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
