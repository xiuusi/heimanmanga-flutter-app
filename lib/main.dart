import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'widgets/tablet_main_page.dart';
import 'widgets/page_transitions.dart';
import 'utils/image_cache_manager.dart';
import 'utils/memory_manager_simplified.dart';
import 'utils/theme_manager.dart';

/// 应用程序入口点
///
/// 这是Flutter应用程序的主入口函数，负责初始化应用并运行主应用组件
void main() async {
  // 使用runZonedGuarded包装整个应用，捕获所有未处理的异常
  runZonedGuarded(() async {
    // 设置Flutter框架异常处理
    FlutterError.onError = (FlutterErrorDetails details) {
      print('🚨 Flutter异常: ${details.exception}');
      print('📋 堆栈跟踪: ${details.stack}');
      print('📝 异常库: ${details.library}');
      // 可以在这里添加崩溃上报逻辑
    };

    // 初始化Flutter框架绑定，确保在访问任何Flutter API之前完成
    WidgetsFlutterBinding.ensureInitialized();

    // 从本地存储加载之前保存的主题设置
    await ThemeManager().loadThemeMode();

    // 启动主应用程序
    runApp(const MangaReaderApp());

    // 在应用启动后延迟初始化缓存和内存管理器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // 初始化图片缓存管理器，优化图片加载性能
        ImageCacheManager.initializeCache();
        // 初始化内存管理器，定期检查和优化内存使用
        MemoryManager.instance.initialize();
      } catch (e) {
        print('⚠️ 初始化缓存管理器时出错: $e');
      }
    });
  }, (error, stackTrace) {
    // 捕获所有未处理的Dart异常
    print('🚨 全局Dart异常: $error');
    print('📋 全局堆栈跟踪: $stackTrace');
    // 可以在这里添加崩溃上报逻辑
  });
}

/// 漫画阅读器主应用状态组件
/// 
/// 这是一个有状态的组件，用于管理应用的主题状态，并根据主题设置切换
/// 亮色和暗色模式的主题
class MangaReaderApp extends StatefulWidget {
  const MangaReaderApp({Key? key}) : super(key: key);

  @override
  State<MangaReaderApp> createState() => _MangaReaderAppState();
}

/// 漫画阅读器主应用状态实现
/// 
/// 管理应用的主题模式，并提供亮色和暗色主题配置
class _MangaReaderAppState extends State<MangaReaderApp> {
  // 主题管理器实例，用于监听主题变化
  final ThemeManager _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();
    // 添加主题变化监听器，当主题改变时重新构建UI
    _themeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    // 在组件销毁时移除主题变化监听器，避免内存泄漏
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// 主题变化回调函数
  /// 
  /// 当应用主题模式改变时（亮色/暗色），重新构建UI以应用新的主题
  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前的主题模式设置
    final isDarkMode = _themeManager.isDarkMode;

    return MaterialApp(
      // 应用标题，显示在任务管理器和标题栏中
      title: '嘿！——漫',
      // 配置亮色主题
      theme: _buildLightTheme(),
      // 配置暗色主题
      darkTheme: _buildDarkTheme(),
      // 根据当前设置决定使用亮色还是暗色主题
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // 应用的主页面，使用响应式布局
      home: const ResponsiveMainPage(),
      // 隐藏调试横幅（在发布版中）
      debugShowCheckedModeBanner: false,
    );
  }

  /// 构建亮色主题
  /// 
  /// 定义应用在亮色模式下的视觉设计，包括颜色、字体、按钮样式等
  ThemeData _buildLightTheme() {
    return ThemeData(
      // 主要颜色，用于强调元素，如按钮、标签等，使用品牌色 #FF6B6B
      primaryColor: const Color(0xFFFF6B6B),
      // 页面背景色，使用浅灰色
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      // 从种子颜色生成的整体色彩方案
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6B6B),
        brightness: Brightness.light,
      ),

      // AppBar主题配置，定义顶部导航栏的外观
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,              // 背景色为白色
        foregroundColor: Colors.black87,            // 前景色为深灰色
        elevation: 1,                               // 阴影高度
        centerTitle: false,                         // 标题不居中
        titleTextStyle: TextStyle(
          color: Color(0xFFFF6B6B),                // 标题颜色为品牌色
          fontSize: 24,                            // 标题字体大小
          fontWeight: FontWeight.bold,              // 标题字体加粗
        ),
      ),

      // 卡片主题配置，定义卡片组件的外观
      cardTheme: CardThemeData(
        elevation: 2,                               // 卡片阴影高度
        shadowColor: Colors.black.withOpacity(0.1), // 阴影颜色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),  // 圆角边框
        ),
        clipBehavior: Clip.antiAlias,               // 抗锯齿裁剪
      ),

      // 提升按钮主题配置，定义ElevatedButton的外观
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B), // 按钮背景色为品牌色
          foregroundColor: Colors.white,             // 按钮文字颜色为白色
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),  // 按钮圆角
          ),
          elevation: 2,                              // 按钮阴影高度
        ),
      ),

      // 输入框主题配置，定义TextField等输入组件的外观
      inputDecorationTheme: InputDecorationTheme(
        filled: true,                                // 启用背景填充
        fillColor: const Color(0xFFF5F5F5),          // 填充颜色
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),   // 圆角边框
          borderSide: BorderSide.none,               // 无边框线
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),   // 启用状态边框
          borderSide: BorderSide.none,               // 无边框线
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),   // 焦点状态边框
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2), // 品牌色边框
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), // 内边距
      ),

      // 文本主题配置，定义各种文本样式的默认设置
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,                             // 标题字体大小
          fontWeight: FontWeight.bold,               // 标题字体加粗
          color: Color(0xFF333333),                 // 标题颜色
        ),
        titleMedium: TextStyle(
          fontSize: 16,                             // 中等标题字体大小
          fontWeight: FontWeight.w600,               // 中等标题字体粗细
          color: Color(0xFF333333),                 // 中等标题颜色
        ),
        bodyMedium: TextStyle(
          fontSize: 14,                             // 正文字体大小
          color: Color(0xFF757575),                 // 正文颜色
        ),
      ),

      // 视觉密度，根据平台自适应
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // 使用Material Design 3
      useMaterial3: true,
      // 页面过渡动画主题配置
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CustomPageTransitionsBuilder(),
          TargetPlatform.iOS: _CustomPageTransitionsBuilder(),
          TargetPlatform.linux: _CustomPageTransitionsBuilder(),
          TargetPlatform.macOS: _CustomPageTransitionsBuilder(),
          TargetPlatform.windows: _CustomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _CustomPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// 构建暗色主题
  /// 
  /// 定义应用在暗色模式下的视觉设计，包括颜色、字体、按钮样式等
  /// 暗色主题使用更深的背景色和更亮的文本颜色以提高可读性
  ThemeData _buildDarkTheme() {
    return ThemeData(
      // 主要颜色，与亮色主题保持一致以维持品牌一致性
      primaryColor: const Color(0xFFFF6B6B),
      // 暗色模式下的页面背景色，使用深灰色
      scaffoldBackgroundColor: const Color(0xFF121212),
      // 从种子颜色生成的整体色彩方案（暗色版本）
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6B6B),
        brightness: Brightness.dark,
      ),

      // 暗色模式下的AppBar主题配置
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),         // 背景色为深灰色
        foregroundColor: Colors.white,               // 前景色为白色
        elevation: 1,                                // 阴影高度
        centerTitle: false,                          // 标题不居中
        titleTextStyle: TextStyle(
          color: Color(0xFFFF6B6B),                 // 标题颜色为品牌色
          fontSize: 24,                             // 标题字体大小
          fontWeight: FontWeight.bold,               // 标题字体加粗
        ),
      ),

      // 暗色模式下的底部导航栏主题配置
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),         // 背景色为深灰色
        selectedItemColor: Color(0xFFFF6B6B),       // 选中项颜色为品牌色
        unselectedItemColor: Color(0xFF888888),     // 未选中项颜色为浅灰色
      ),

      // 暗色模式下的卡片主题配置
      cardTheme: CardThemeData(
        elevation: 2,                                // 卡片阴影高度
        shadowColor: Colors.black.withOpacity(0.3), // 更深的阴影颜色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),   // 圆角边框
        ),
        clipBehavior: Clip.antiAlias,                // 抗锯齿裁剪
        color: const Color(0xFF1E1E1E),              // 卡片背景色
      ),

      // 暗色模式下的提升按钮主题配置
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),  // 按钮背景色为品牌色
          foregroundColor: Colors.white,              // 按钮文字颜色为白色
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),   // 按钮圆角
          ),
          elevation: 2,                               // 按钮阴影高度
        ),
      ),

      // 暗色模式下的输入框主题配置
      inputDecorationTheme: InputDecorationTheme(
        filled: true,                                 // 启用背景填充
        fillColor: const Color(0xFF2D2D2D),           // 深灰色填充色
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),    // 圆角边框
          borderSide: BorderSide.none,                // 无边框线
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),    // 启用状态边框
          borderSide: BorderSide.none,                // 无边框线
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),    // 焦点状态边框
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2), // 品牌色边框
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), // 内边距
        hintStyle: const TextStyle(color: Color(0xFF888888)), // 提示文本颜色
      ),

      // 暗色模式下的文本主题配置
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,                              // 标题字体大小
          fontWeight: FontWeight.bold,                // 标题字体加粗
          color: Colors.white,                       // 白色标题
        ),
        titleMedium: TextStyle(
          fontSize: 16,                              // 中等标题字体大小
          fontWeight: FontWeight.w600,                // 中等标题字体粗细
          color: Colors.white,                       // 白色中等标题
        ),
        bodyMedium: TextStyle(
          fontSize: 14,                              // 正文字体大小
          color: Color(0xFFBBBBBB),                  // 浅灰色正文
        ),
      ),

      // 视觉密度，根据平台自适应
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // 使用Material Design 3
      useMaterial3: true,
      // 页面过渡动画主题配置
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CustomPageTransitionsBuilder(),
          TargetPlatform.iOS: _CustomPageTransitionsBuilder(),
          TargetPlatform.linux: _CustomPageTransitionsBuilder(),
          TargetPlatform.macOS: _CustomPageTransitionsBuilder(),
          TargetPlatform.windows: _CustomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _CustomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 自定义页面过渡动画构建器
/// 
/// 为不同类型的页面提供不同的过渡动画效果，增强用户体验
class _CustomPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    Route<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 主页不使用过渡动画，直接显示
    if (route.settings.name == '/') {
      return child;
    }

    // 获取路由名称以确定使用哪种过渡动画
    final routeName = route.settings.name;

    // 如果路由名称包含'detail'，则使用漫画风格翻页动画
    if (routeName?.contains('detail') == true) {
      return PageTransitions.mangaPageTransition(child, context, animation);
    } 
    // 如果路由名称包含'search'，则使用从底部滑入动画
    else if (routeName?.contains('search') == true) {
      return PageTransitions.slideTransition(
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),            // 从底部开始
            end: Offset.zero,                         // 移动到正常位置
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,               // 使用缓出立方曲线
          )),
          child: FadeTransition(                      // 同时进行淡入动画
            opacity: animation,
            child: child,
          ),
        ),
        context,
        animation,
      );
    } 
    // 对于其他页面，使用缩放滑动组合动画
    else {
      return PageTransitions.scaleSlideTransition(child, context, animation);
    }
  }
}
