import 'package:flutter/material.dart';

/// 精简版加载动画组件
/// 只保留项目中实际使用的核心动画
class LoadingAnimations {
  // 基础加载指示器
  static Widget basicLoader({Color? color, double size = 24.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3.0,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? const Color(0xFFFF6B6B)),
      ),
    );
  }

  // 漫画书样式加载动画
  static Widget mangaLoader({
    Color? color,
    double size = 60.0,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: _MangaBookLoader(
        color: color ?? const Color(0xFFFF6B6B),
        duration: duration,
      ),
    );
  }

  // 脉冲加载动画
  static Widget pulseLoader({
    Color? color,
    double size = 50.0,
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    return _PulseLoader(
      color: color ?? const Color(0xFFFF6B6B),
      size: size,
      duration: duration,
    );
  }

  // 三个点加载动画
  static Widget dotLoader({
    Color? color,
    double dotSize = 8.0,
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    return _DotLoader(
      color: color ?? const Color(0xFFFF6B6B),
      dotSize: dotSize,
      duration: duration,
    );
  }

  // 漫画卡片骨架屏
  static Widget mangaCardSkeleton({double width = 200, double height = 300}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 漫画书样式加载器
class _MangaBookLoader extends StatefulWidget {
  final Color color;
  final Duration duration;

  const _MangaBookLoader({
    required this.color,
    required this.duration,
  });

  @override
  State<_MangaBookLoader> createState() => _MangaBookLoaderState();
}

class _MangaBookLoaderState extends State<_MangaBookLoader>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 3.14159,
            child: Icon(
              Icons.auto_stories,
              color: widget.color,
              size: 40,
            ),
          ),
        );
      },
    );
  }
}

// 脉冲加载器
class _PulseLoader extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const _PulseLoader({
    required this.color,
    required this.size,
    required this.duration,
  });

  @override
  State<_PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<_PulseLoader>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(_opacityAnimation.value),
                ),
              ),
            ),
            Container(
              width: widget.size * 0.5,
              height: widget.size * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 三个点加载器
class _DotLoader extends StatefulWidget {
  final Color color;
  final double dotSize;
  final Duration duration;

  const _DotLoader({
    required this.color,
    required this.dotSize,
    required this.duration,
  });

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: widget.duration,
        vsync: this,
      );
    });

    _animations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controllers[index],
          curve: Interval(
            0.2 * index,
            0.2 * index + 0.6,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(_animations[index].value),
              ),
            );
          },
        );
      }),
    );
  }
}