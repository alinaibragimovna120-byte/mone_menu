// Фото позиции из хранилища (с ограничением размера декодирования).

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/menu_provider.dart';

class CardPhoto extends StatelessWidget {
  final String? path;
  final double? height;
  final BoxFit fit;

  const CardPhoto({super.key, this.path, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      color: const Color(0xFFEDE7E3),
      alignment: Alignment.center,
      child: const Icon(Icons.local_cafe_outlined, size: 40, color: Color(0xFFB0A49C)),
    );
    final image = path == null ? null : context.read<MenuProvider>().storage.photoImage(path!);
    if (image == null) return placeholder;
    return LayoutBuilder(builder: (context, c) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final w = c.maxWidth.isFinite ? (c.maxWidth * dpr).round() : 800;
      return Image(
        image: ResizeImage.resizeIfNeeded(w, null, image),
        height: height,
        width: double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    });
  }
}

/// Фото целиком (без обрезки) по центру, по бокам — его же размытая копия.
class WholePhoto extends StatelessWidget {
  final String? path;

  const WholePhoto({super.key, this.path});

  @override
  Widget build(BuildContext context) {
    if (path == null) return const CardPhoto();
    return Stack(fit: StackFit.expand, children: [
      ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Transform.scale(scale: 1.2, child: CardPhoto(path: path)),
        ),
      ),
      const ColoredBox(color: Color(0x26000000)),
      CardPhoto(path: path, fit: BoxFit.contain),
    ]);
  }
}
