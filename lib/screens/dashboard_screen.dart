import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/screens/add_item_screen.dart';
import 'package:measure_master/models/item.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);

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
                      SizedBox(width: 16),
                      CircleAvatar(
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=32'),
                        radius: 18,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              Text("こんにちは、山田さん", style: AppConstants.headerStyle),
              SizedBox(height: 8),
              Text(
                "今日の出品準備状況を確認しましょう。",
                style: AppConstants.bodyStyle.copyWith(color: AppConstants.textGrey),
              ),
              SizedBox(height: 24),

              // Stats Cards
              Row(
                children: [
                  Expanded(child: _buildStatCard("Ready", inventory.readyCount.toString(), "出品待ちアイテム", AppConstants.successGreen, Icons.check_circle)),
                  SizedBox(width: 16),
                  Expanded(child: _buildStatCard("Draft", inventory.draftCount.toString(), "下書き保存中", AppConstants.warningOrange, Icons.edit_document)),
                ],
              ),
              SizedBox(height: 24),

              // Big CTA
              Container(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => AddItemScreen())
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppConstants.primaryCyan.withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 32, color: Colors.white),
                      SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("新規アイテムを撮影", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("採寸・撮影を開始する", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

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
              SizedBox(height: 16),

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
              SizedBox(height: 24),

              // Recent Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("最近のアイテム", style: AppConstants.subHeaderStyle),
                  Text("すべて見る", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16),

              // List
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: inventory.items.length,
                itemBuilder: (context, index) {
                  return _buildItemCard(inventory.items[index]);
                },
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
           Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => AddItemScreen())
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
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0, 2)),
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
                      color: Color(0xFF1A2A3A).withOpacity(0.8),
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
                            ? AppConstants.successGreen.withOpacity(0.1) 
                            : (item.status == 'Draft' ? AppConstants.warningOrange.withOpacity(0.1) : Colors.grey[200]),
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
                SizedBox(height: 8),
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
