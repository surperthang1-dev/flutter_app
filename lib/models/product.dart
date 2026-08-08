import 'package:flutter/material.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.categoryId,
    required this.imageLabel,
    required this.accentColor,
    this.imageAsset,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final String category;
  final String categoryId;
  final String imageLabel;
  final Color accentColor;
  final String? imageAsset;
}
