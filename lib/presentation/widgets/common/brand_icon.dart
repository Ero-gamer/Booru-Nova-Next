import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 品牌图标：正方形（256 逻辑坐标），圆角方紫渐变底 + 白色照片卡
/// （双峰山 + 太阳）+ 青色闪光星。
///
/// 图标资源的权威绘制源：`test/icon_golden_test.dart` 用它生成各密度
/// Android PNG；应用内（启动过渡等）直接内嵌同一 Widget，保证一致。
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, this.withBackground = true});

  /// 自适应图标前景置 false：不画圆角方底，只画图形（背景由系统提供）。
  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 256,
      child: CustomPaint(
        painter: _BrandPainter(withBackground: withBackground),
      ),
    );
  }
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter({this.withBackground = true});

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // 正方形
    final rect = Offset.zero & size;

    // ---- 圆角方形渐变底 ----
    if (withBackground) {
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC026D3), Color(0xFF6D28D9)],
        ).createShader(rect);
      final bgRadius = s * 0.22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(bgRadius)),
        bgPaint,
      );
    }

    // ---- 白色照片卡 ----
    final cardW = s * 0.58;
    final cardH = s * 0.44;
    final cardRect = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.54),
      width: cardW,
      height: cardH,
    );
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      Radius.circular(s * 0.075),
    );
    canvas.drawRRect(
      cardRRect.shift(Offset(0, s * 0.012)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(cardRRect, Paint()..color = const Color(0xFFFFFFFF));

    // ---- 卡片内的天空/太阳/双山（裁剪进卡片圆角内）----
    canvas.save();
    canvas.clipRRect(cardRRect);
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEDE9FE), Color(0xFFFDF4FF)],
      ).createShader(cardRect);
    canvas.drawRRect(cardRRect, sky);

    canvas.drawCircle(
      Offset(cardRect.right - cardW * 0.22, cardRect.top + cardH * 0.26),
      s * 0.045,
      Paint()..color = const Color(0xFFFDE047),
    );

    final farMountain = Path()
      ..moveTo(cardRect.left, cardRect.bottom)
      ..lineTo(cardRect.left + cardW * 0.32, cardRect.top + cardH * 0.30)
      ..lineTo(cardRect.left + cardW * 0.62, cardRect.bottom)
      ..close();
    canvas.drawPath(farMountain, Paint()..color = const Color(0xFFC4B5FD));

    final nearMountain = Path()
      ..moveTo(cardRect.left + cardW * 0.30, cardRect.bottom)
      ..lineTo(cardRect.left + cardW * 0.68, cardRect.top + cardH * 0.16)
      ..lineTo(cardRect.right, cardRect.bottom)
      ..close();
    canvas.drawPath(nearMountain, Paint()..color = const Color(0xFF7C3AED));

    canvas.restore();

    // ---- 青色闪光星 ----
    void spark(Offset c, double r) {
      final star = Path();
      const inner = 0.36;
      final pts = <Offset>[];
      for (var i = 0; i < 8; i++) {
        final angle = -math.pi / 2 + i * math.pi / 4;
        final radius = i.isEven ? r : r * inner;
        pts.add(Offset(
          c.dx + radius * math.cos(angle),
          c.dy + radius * math.sin(angle),
        ));
      }
      star.addPolygon(pts, true);
      canvas.drawPath(star, Paint()..color = const Color(0xFF67E8F9));
    }

    spark(Offset(s * 0.76, s * 0.22), s * 0.065);
    spark(Offset(s * 0.86, s * 0.14), s * 0.034);
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground;
}
