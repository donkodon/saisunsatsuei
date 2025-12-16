import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/detail_screen.dart';

class CameraScreen extends StatefulWidget {
  final String itemName;
  final String brand;
  final String category;
  final String condition;
  final String price;

  CameraScreen({
    required this.itemName,
    required this.brand,
    required this.category,
    required this.condition,
    required this.price,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  int _selectedMode = 0; // 0: Tops, 1: Pants, 2: Bags

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Simulated Camera Feed (Image)
          Image.asset(
            'assets/images/tshirt_hanger.jpg', // Using placeholder as camera feed
            fit: BoxFit.cover,
          ),
          
          // Overlay Grid
          CustomPaint(
            painter: GridPainter(),
            child: Container(),
          ),
          
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text("採寸・撮影", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {},
                      child: Text("保存", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category Selector (Top)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCategoryChip(0, Icons.checkroom, "トップス"),
                SizedBox(width: 12),
                _buildCategoryChip(1, Icons.shopping_bag, "パンツ"), // Using simplified icons
                SizedBox(width: 12),
                _buildCategoryChip(2, Icons.shopping_bag_outlined, "バッグ"),
              ],
            ),
          ),

          // Helper Text
          Positioned(
            bottom: 250,
            left: 0,
            right: 0,
            child: Text(
              "商品を枠に合わせて撮影してください",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                fontSize: 14,
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: EdgeInsets.only(bottom: 30, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: Icon(Icons.image, color: Colors.white),
                      ),
                      
                      // Shutter Button
                      GestureDetector(
                        onTap: () {
                          // Simulate capture delay then navigate
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(child: CircularProgressIndicator(color: AppConstants.primaryCyan)),
                          );
                          Future.delayed(Duration(seconds: 2), () {
                            Navigator.pop(context); // Close loader
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailScreen(
                                  itemName: widget.itemName,
                                  brand: widget.brand,
                                  category: widget.category,
                                  condition: widget.condition,
                                  price: widget.price,
                                ),
                              ),
                            );
                          });
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryCyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.grid_on, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // Manual Input Preview (Bottom Sheet simulated)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("寸法入力", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Row(
                              children: [
                                Icon(Icons.center_focus_weak, color: AppConstants.primaryCyan, size: 16),
                                SizedBox(width: 4),
                                Text("AR計測", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildDimInput("着丈 (Length)", "0")),
                            SizedBox(width: 16),
                            Expanded(child: _buildDimInput("身幅 (Width)", "0")),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int index, IconData icon, String label) {
    bool isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryCyan : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDimInput(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: AppConstants.textGrey)),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Text("cm", style: TextStyle(color: AppConstants.textGrey)),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppConstants.primaryCyan.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final dashWidth = 5.0;
    final dashSpace = 5.0;

    // Draw Dashed Box
    final rect = Rect.fromLTWH(20, 100, size.width - 40, size.height - 350);
    _drawDashedRect(canvas, paint, rect, dashWidth, dashSpace);

    // Draw Crosshair
    final centerX = size.width / 2;
    final centerY = rect.top + (rect.height / 2);
    
    // Vertical line
    _drawDashedLine(canvas, paint, Offset(centerX, rect.top), Offset(centerX, rect.bottom), dashWidth, dashSpace);
    // Horizontal line
    _drawDashedLine(canvas, paint, Offset(rect.left, centerY), Offset(rect.right, centerY), dashWidth, dashSpace);
  }
  
  void _drawDashedRect(Canvas canvas, Paint paint, Rect rect, double dashWidth, double dashSpace) {
    // Top
    _drawDashedLine(canvas, paint, rect.topLeft, rect.topRight, dashWidth, dashSpace);
    // Right
    _drawDashedLine(canvas, paint, rect.topRight, rect.bottomRight, dashWidth, dashSpace);
    // Bottom
    _drawDashedLine(canvas, paint, rect.bottomRight, rect.bottomLeft, dashWidth, dashSpace);
    // Left
    _drawDashedLine(canvas, paint, rect.bottomLeft, rect.topLeft, dashWidth, dashSpace);
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end, double dashWidth, double dashSpace) {
    double distance = (end - start).distance;
    double currentDistance = 0;
    Offset direction = (end - start) / distance;
    
    while (currentDistance < distance) {
      canvas.drawLine(
        start + direction * currentDistance,
        start + direction * (currentDistance + dashWidth > distance ? distance : currentDistance + dashWidth),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
