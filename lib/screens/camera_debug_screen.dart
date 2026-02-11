import 'dart:io';
import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/widgets/image_input.dart';

class CameraDebugScreen extends StatefulWidget {
  const CameraDebugScreen({Key? key}) : super(key: key);

  @override
  _CameraDebugScreenState createState() => _CameraDebugScreenState();
}

class _CameraDebugScreenState extends State<CameraDebugScreen> {
  File? _pickedImage;

  void _selectImage(File pickedImage) {
    setState(() {
      _pickedImage = pickedImage;
    });
    // ここで実際にDB保存処理などを呼び出します
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('画像パスを保存しました: ${pickedImage.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラ機能テスト'),
        backgroundColor: AppConstants.primaryCyan,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '商品画像の登録テスト',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // 作成した撮影部品を配置
            ImageInput(_selectImage),
            const SizedBox(height: 20),
            if (_pickedImage != null)
              Text('保存場所:\n${_pickedImage!.path}'),
          ],
        ),
      ),
    );
  }
}
