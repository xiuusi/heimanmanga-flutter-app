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

  // 缩放过渡动画
  static Widget scaleTransition(Widget page, BuildContext context, Animation<double> animation) {
    const begin = 0.0;
    const end = 1.0;
    const curve = Curves.easeOutCubic;

    var scaleTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return ScaleTransition(
      scale: animation.drive(scaleTween),
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

  // 旋转过渡动画
  static Widget rotationTransition(Widget page, BuildContext context, Animation<double> animation) {
    const begin = 0.1;
    const end = 1.0;
    const curve = Curves.easeOutBack;

    var scaleTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    var rotationTween = Tween(begin: 0.1, end: 0.0).chain(CurveTween(curve: curve));

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: animation.drive(rotationTween).value,
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: FadeTransition(
              opacity: animation,
              child: page,
            ),
          ),
        );
      },
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
            ..translate((1 - progress) * 50.0, 0.0),
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

  // 弹性缩放动画
  static Widget bounceScaleTransition(Widget page, BuildContext context, Animation<double> animation) {
    const curve = Curves.elasticOut;

    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: curve)),
      child: FadeTransition(
        opacity: animation,
        child: page,
      ),
    );
  }

  // 中心放大动画
  static Widget centerScaleTransition(Widget page, BuildContext context, Animation<double> animation) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      )),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
        )),
        child: page,
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

  // 漫画详情页专用路由
  static Route<T> mangaDetailRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.95,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  // 搜索页面专用路由（从底部滑入）
  static Route<T> searchPageRoute<T>({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.3),
    );
  }
}

// 自定义页面过渡主题
class CustomPageTransitionsTheme extends PageTransitionsTheme {
  @override
  Widget buildTransitions<T>(
    Route<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == '/') {
      // 主页面不使用过渡动画
      return child;
    }

    // 使用滑动过渡
    return PageTransitions.slideTransition(child, context, animation);
  }
}