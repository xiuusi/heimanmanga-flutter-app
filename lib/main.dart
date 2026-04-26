import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'widgets/tablet_main_page.dart';
import 'widgets/page_transitions.dart';
import 'utils/image_cache_manager.dart';
import 'utils/memory_manager_simplified.dart';
import 'utils/theme_manager.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeManager().loadThemeMode();

  await MangaApiService.initUserAgent();

  runApp(const MangaReaderApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      ImageCacheManager.initializeCache();
      MemoryManager.instance.initialize();
    } catch (e) {
      // ignore
    }
  });
}

class MangaReaderApp extends StatefulWidget {
  const MangaReaderApp({Key? key}) : super(key: key);

  @override
  State<MangaReaderApp> createState() => _MangaReaderAppState();
}

class _MangaReaderAppState extends State<MangaReaderApp> {
  final ThemeManager _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(_onThemeChanged);
    _applyDynamicColor();
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _applyDynamicColor() {
    DynamicColorPlugin.getAccentColor().then((color) {
      if (color != null && _themeManager.useDynamicColor) {
        _themeManager.setAccentColor(color);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _themeManager.isDarkMode;
    final accentColor = _themeManager.accentColor;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: '嘿！——漫',
          theme: _buildLightTheme(accentColor, lightDynamic),
          darkTheme: _buildDarkTheme(accentColor, darkDynamic),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const ResponsiveMainPage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  ThemeData _buildLightTheme(Color accentColor, ColorScheme? dynamicScheme) {
    final colorScheme = _resolveColorScheme(accentColor, Brightness.light, dynamicScheme);

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: accentColor,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: accentColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF757575),
        ),
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
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

  ThemeData _buildDarkTheme(Color accentColor, ColorScheme? dynamicScheme) {
    final colorScheme = _resolveColorScheme(accentColor, Brightness.dark, dynamicScheme);

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: accentColor,
      scaffoldBackgroundColor: const Color(0xFF121212),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: accentColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: accentColor,
        unselectedItemColor: const Color(0xFF888888),
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF1E1E1E),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D2D2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        hintStyle: const TextStyle(color: Color(0xFF888888)),
      ),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFBBBBBB),
        ),
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
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

  ColorScheme _resolveColorScheme(Color accentColor, Brightness brightness, ColorScheme? dynamicScheme) {
    if (dynamicScheme != null && _themeManager.useDynamicColor) {
      return dynamicScheme.harmonized();
    }
    return ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    );
  }
}

class _CustomPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    Route<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == '/') {
      return child;
    }

    final routeName = route.settings.name;

    if (routeName?.contains('detail') == true) {
      return PageTransitions.mangaPageTransition(child, context, animation);
    } else if (routeName?.contains('search') == true) {
      return PageTransitions.slideTransition(
        SlideTransition(
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
        ),
        context,
        animation,
      );
    } else {
      return PageTransitions.scaleSlideTransition(child, context, animation);
    }
  }
}
