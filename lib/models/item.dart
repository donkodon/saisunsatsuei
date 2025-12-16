import 'package:flutter/material.dart';

class InventoryItem {
  final String id;
  final String name;
  final String brand;
  final String imageUrl;
  final String category;
  final String status; // 'Ready', 'Draft', 'Sold'
  final DateTime date;
  final double? length; // cm
  final double? width; // cm
  final String? size; // e.g. M, L
  final bool hasAlert; // e.g. "Photo missing"

  InventoryItem({
    required this.id,
    required this.name,
    this.brand = '',
    required this.imageUrl,
    this.category = 'Tops',
    this.status = 'Draft',
    required this.date,
    this.length,
    this.width,
    this.size,
    this.hasAlert = false,
  });
}
