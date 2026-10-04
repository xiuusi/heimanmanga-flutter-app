import 'package:flutter/material.dart';

class PageTransitions {
  // 滑动过渡动画（从右往左滑入）
  static Widget slideTransition(Widget page, BuildContext context, Animation<double> animation) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.ease;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(
        opacity: animation,
        child: page,
      ),
    );
  }

  // 渐变过渡动画
  static Widget fadeTransition(Widget page, BuildContext context, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: page,
    );
  }

  // 漫画风格的翻页动画
  static Widget mangaPageTransition(Widget page, BuildContext context, Animation<double> animation) {
    const curve = Curves.easeOutCubic;

    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final progress = curvedAnimation.value;

        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY((1 - progress) * 0.5)
            ..translateByDouble((1 - progress) * 50.0, 0.0, 0.0, 1.0),
          child: Opacity(
            opacity: progress,
            child: page,
          ),
        );
      },
    );
  }

  // 缩放滑动组合动画
  static Widget scaleSlideTransition(Widget page, BuildContext context, Animation<double> animation) {
    const curve = Curves.easeOutQuart;

    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.2, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(curvedAnimation),
        child: FadeTransition(
          opacity: animation,
          child: page,
        ),
      ),
    );
  }

  // 自定义PageRoute
  static Route<T> customPageRoute<T>({
    required Widget child,
    Widget Function(Widget, BuildContext, Animation<double>) transitionBuilder = PageTransitions.slideTransition,
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration ?? const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return transitionBuilder(child, context, animation);
      },
      maintainState: true,
      fullscreenDialog: false,
    );
  }

}
