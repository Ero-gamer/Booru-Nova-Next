import 'package:boorunova/presentation/widgets/common/brand_icon.dart';
import 'package:flutter/material.dart';

/// 启动过渡：原生 splash（Android 启动画面）之后、首页首帧之前的品牌层。
///
/// 依次播放：logo 轻微放大进入（250ms）→ 停留（450ms）→ 整层淡出（300ms）
/// 后自行移除，把界面交还给正常内容。纯视觉层，IgnorePointer 不拦截交互，
/// 也不阻塞任何初始化（Hive 等已在 main 完成）。
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key, this.onFinished, this.dark = false});

  /// 过渡完全结束后回调（用于从树上移除本层）。
  final VoidCallback? onFinished;

  /// 是否深色背景。由调用方（BooruNova）依据主题决定，不能在此处读
  /// Theme.of(context)：BrandSplash 位于 MaterialApp 之外，拿不到真实主题，
  /// 否则会恒以浅色渲染（深色模式启动闪白）。
  final bool dark;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final Animation<double> _fade = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeIn)), weight: 30),
  ]).animate(_controller);
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1.0)
      .chain(CurveTween(curve: Curves.easeOutCubic))
      .animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_fade.value <= 0.01) return const SizedBox.shrink();
          return Opacity(
            opacity: _fade.value,
            // SizedBox.expand 让背景铺满整个 Stack（全屏），否则 Stack
            // 的 loose fit 会让 ColoredBox 收缩到 logo 大小、露出底下内容。
            child: SizedBox.expand(
              child: ColoredBox(
                color: dark
                    ? const Color(0xFF141019)
                    : const Color(0xFFF6EBF9),
                child: Center(
                  child: Transform.scale(
                    scale: _scale.value,
                    child: const SizedBox(
                      width: 120,
                      height: 120,
                      child: FittedBox(child: BrandIcon(withBackground: false)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
