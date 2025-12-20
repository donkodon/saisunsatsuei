import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/screens/add_item_screen.dart';
import 'package:measure_master/screens/api_products_screen.dart';
import 'package:measure_master/models/item.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🚀 listen: false で不要な再描画を防止（パフォーマンス最適化）
    // InventoryProviderは Consumer内でのみ使用

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("出品ダッシュボード", style: AppConstants.subHeaderStyle),
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined, color: AppConstants.textDark),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider('https://i.pravatar.cc/150?img=32'),
                        radius: 18,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text("こんにちは、山田さん", style: AppConstants.headerStyle),
              const SizedBox(height: 8),
              Text(
                "今日の出品準備状況を確認しましょう。",
                style: AppConstants.bodyStyle.copyWith(color: AppConstants.textGrey),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              // 🚀 Consumer で必要な部分だけ再描画
              Consumer<InventoryProvider>(
                builder: (context, inventory, _) => Row(
                  children: [
                    Expanded(child: _buildStatCard("Ready", inventory.readyCount.toString(), "出品待ちアイテム", AppConstants.successGreen, Icons.check_circle)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard("Draft", inventory.draftCount.toString(), "下書き保存中", AppConstants.warningOrange, Icons.edit_document)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Big CTA
              Container(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    // 🚀 高速遷移
                    Navigator.push(
                      context, 
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppConstants.primaryCyan.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 32, color: Colors.white),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("新規アイテムを撮影", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("採寸・撮影を開始する", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // API連携ボタン
              Container(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const ApiProductsScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppConstants.primaryCyan, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_download, size: 28, color: AppConstants.primaryCyan),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "API商品データを取り込む",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryCyan,
                            ),
                          ),
                          Text(
                            "外部システムと連携",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppConstants.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: "商品名、ブランド、サイズで検索...",
                  prefixIcon: Icon(Icons.search, color: AppConstants.textGrey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("すべて", true),
                    _buildFilterChip("採寸済み", false),
                    _buildFilterChip("下書き", false),
                    _buildFilterChip("出品完了", false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("最近のアイテム", style: AppConstants.subHeaderStyle),
                  Text("すべて見る", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              // 🚀 Consumer でリスト部分だけ再描画
              Consumer<InventoryProvider>(
                builder: (context, inventory, _) => ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: inventory.items.length,
                  itemBuilder: (context, index) {
                    return _buildItemCard(inventory.items[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppConstants.primaryCyan,
        unselectedItemColor: AppConstants.textGrey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "ホーム"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "撮影"), // Middle big button simulation
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "設定"),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           // 🚀 高速遷移
           Navigator.push(
              context, 
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 200),
              ),
            );
        },
        backgroundColor: Color(0xFF1A2A3A), // Dark color from screenshot
        child: Icon(Icons.camera_alt, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildStatCard(String badge, String count, String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(count, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppConstants.textDark)),
          Text(label, style: AppConstants.captionStyle),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? Color(0xFF1A2A3A) : Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppConstants.textDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isSelected ? BorderSide.none : BorderSide(color: AppConstants.borderGrey),
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderGrey),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.asset(
                  item.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(width: 80, height: 80, color: Colors.grey[300]),
                ),
                if (item.status == 'Ready')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: Color(0xFF1A2A3A).withValues(alpha: 0.8),
                      child: Text("済", style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.status == 'Ready' 
                            ? AppConstants.successGreen.withValues(alpha: 0.1) 
                            : (item.status == 'Draft' ? AppConstants.warningOrange.withValues(alpha: 0.1) : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.status == 'Ready' ? '出品待ち' : (item.status == 'Draft' ? '下書き' : '出品完了'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.status == 'Ready' 
                              ? AppConstants.successGreen 
                              : (item.status == 'Draft' ? AppConstants.warningOrange : Colors.grey),
                        ),
                      ),
                    ),
                    Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  item.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.category,
                  style: AppConstants.captionStyle,
                ),
                const SizedBox(height: 8),
                if (item.hasAlert)
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppConstants.warningOrange, size: 14),
                      SizedBox(width: 4),
                      Text("写真が不足しています", style: TextStyle(color: AppConstants.warningOrange, fontSize: 12)),
                    ],
                  )
                else if (item.length != null)
                   Row(
                    children: [
                      _buildDimensionTag("W: ${item.width}cm"),
                      SizedBox(width: 8),
                      _buildDimensionTag("L: ${item.length}cm"),
                    ],
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.borderGrey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
    );
  }
}
