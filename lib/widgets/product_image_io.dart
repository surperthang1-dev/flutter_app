import 'dart:io';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.path,
    required this.fit,
    required this.errorBuilder,
  });

  final String path;
  final BoxFit fit;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: fit, errorBuilder: errorBuilder);
    }

    return Image.asset(path, fit: fit, errorBuilder: errorBuilder);
  }
}
