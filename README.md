# 嘿！——漫 Flutter 漫画阅读器

一个功能完整的Flutter漫画阅读器应用，具有现代化的UI设计和优秀的用户体验。

## ✨ 主要功能

### 🎨 界面功能
- **底部导航系统** - 首页、搜索、标签三大核心页面
- **轮播图展示** - 自动播放的漫画推荐轮播
- **响应式布局** - 适配不同屏幕尺寸
- **主题切换** - 支持亮色/暗色主题
- **流畅动画** - 丰富的页面过渡和交互动画

### 🔍 搜索功能
- **多种搜索类型** - 标题、作者、标签搜索
- **实时搜索结果** - 输入时即时显示搜索结果
- **无限滚动加载** - 流畅的搜索结果浏览

### 🏷️ 标签分类
- **命名空间分类** - 按类型、作者、状态等分类
- **标签颜色编码** - 视觉化的标签展示
- **标签筛选** - 按标签快速筛选漫画

### 📖 阅读功能
- **漫画详情页** - 完整的漫画信息展示
- **章节列表** - 清晰的章节导航
- **阅读进度** - 自动保存阅读位置
- **手势控制** - 翻页、缩放等手势操作

## 🛠️ 技术特性

### 性能优化
- **智能图片缓存** - 多层缓存策略，优化加载性能
- **虚拟化列表** - 处理大量数据的流畅滚动
- **内存管理** - 自动清理和优化内存使用
- **组件复用** - 使用AutomaticKeepAliveClientMixin保持状态

### 动画效果
- **页面过渡动画** - 3D翻页、缩放滑动等丰富动画
- **加载动画** - 多种精美的加载状态展示
- **交互反馈** - 悬停、点击等交互动画

### 架构设计
- **模块化组件** - 可复用的UI组件库
- **状态管理** - 清晰的页面状态管理
- **错误处理** - 完善的错误处理和用户提示

## 📱 项目结构

```
lib/
├── main.dart                          # 应用入口和主题配置
├── models/
│   └── manga.dart                     # 数据模型定义
├── services/
│   ├── api_service.dart               # API服务
│   └── reading_progress_service.dart  # 阅读进度管理服务
├── utils/
│   ├── theme_manager.dart             # 主题管理器
│   ├── image_cache_manager.dart       # 图片缓存管理器
│   ├── memory_manager.dart            # 内存管理器
│   ├── parsers.dart                   # 数据解析器
│   └── reader_gestures.dart           # 阅读器手势控制
└── widgets/
    ├── main_navigation_page.dart      # 主导航页面
    ├── manga_list_page.dart           # 漫画列表页面
    ├── manga_detail_page.dart         # 漫画详情页面
    ├── search_page.dart               # 搜索页面
    ├── tags_page.dart                 # 标签页面
    ├── enhanced_reader_page.dart      # 增强版阅读器页面
    ├── carousel_widget.dart           # 轮播图组件
    ├── page_transitions.dart          # 页面过渡动画
    ├── loading_animations.dart        # 加载动画组件
    ├── advanced_animations.dart       # 高级动画组件
    └── performance_optimized_widgets.dart # 性能优化组件
```

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.0.0+
- Dart 3.0.0+

### 主要依赖包
- `http: ^1.1.0` - HTTP客户端
- `cached_network_image: ^3.3.0` - 图片缓存
- `url_launcher: ^6.2.2` - URL启动器
- `shared_preferences: ^2.2.2` - 本地存储

### 安装运行
```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建Web版本
flutter build web
```

### API配置
应用需要连接到漫画API服务，默认配置为：
- 基础URL: https://c.xiongouke.top
- 主要端点: /api/manga, /api/search, /api/tags

## 🎯 核心特性

### 主题系统
- Material 3 设计语言
- 统一的颜色方案 (#FF6B6B 主色调)
- 响应式视觉密度
- 自定义页面过渡动画

### 图片处理
- 智能缓存策略
- 渐进式图片加载
- 错误重试机制
- 低内存设备优化

### 用户体验
- 60fps流畅动画
- 手势驱动的交互
- 智能预加载
- 离线友好设计

## 📄 相关文档

- [SUMMARY.md](SUMMARY.md) - 项目详细总结
- [FIXES.md](FIXES.md) - 问题修复记录
- [READING_PROGRESS_FEATURE.md](READING_PROGRESS_FEATURE.md) - 阅读进度功能说明
- [flutter_manga_app_lib_documentation.md](flutter_manga_app_lib_documentation.md) - 完整文件说明

## 📊 版本信息

- **当前版本**: 0.1.10+1
- **Flutter SDK**: 3.35.0+
- **Dart SDK**: 3.9.0+
- **状态**: 功能完整，已修复所有编译错误

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

MIT License