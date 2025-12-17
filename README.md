<div align="center">
  <img src="https://github.com/user-attachments/assets/a13e97b8-2112-4a0c-9d61-640c6e9c10db" width="280" alt="icon">

  # 🎯 嘿！——漫

  [![Flutter](https://img.shields.io/badge/Flutter-3.0.0+-blue.svg)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0.0+-blue.svg)](https://dart.dev)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## 📖 项目简介

这是一个完全使用AI辅助AI来开发的Flutter漫画阅读应用，作为配套应用与[漫画网站](https://www.heiman.cc)

**开发工具**:   主要使用的是vscode+Claude code/deepseek v3.2

**曾经使用过的开发工具**:  ~~Claude code/DeepSeek V3.2 + Qwen-Coder-CIi + vscode + Claude code/deepseek3.2~~  

**辅助AI的AI**: ChatGPT5、Gemini2.5pro-search、Claude-haiku-4-5、gemini3-pro 等。


## 📸 应用截图

<div align="center">

### 主界面与搜索
<img src="https://github.com/user-attachments/assets/cffa91fe-7195-4a06-b92e-e038cb5b75dd" width="280" alt="主界面">
<img src="https://github.com/user-attachments/assets/d1a71907-5407-4f24-85b2-2d4daeb29adc" width="280" alt="搜索页面">

### 标签页与详情页
<img src="https://github.com/user-attachments/assets/ee529c8b-e740-4a89-872f-06cb40e218ff" width="280" alt="标签分类">
<img src="https://github.com/user-attachments/assets/143674d3-73ba-421d-85e3-4bd000723a06" width="280" alt="漫画详情">

</div>

## 🏗️ 项目架构

### 📱 项目结构

```
lib/
├── main.dart                          # 应用入口文件
├── components/                        # 组件目录
│   └── tablet_navigation_drawer.dart  # 平板导航抽屉组件
├── models/                            # 数据模型目录
│   ├── drift_models.dart              # Drift数据库模型定义
│   ├── drift_models.g.dart            # Drift生成的代码
│   └── manga.dart                     # 漫画数据模型
├── services/                          # 服务层目录
│   ├── api_service.dart               # API服务
│   ├── drift_reading_progress_manager.dart  # Drift阅读进度管理器
│   └── reading_progress_service.dart  # 阅读进度服务
├── utils/                             # 工具类目录
│   ├── dual_page_utils.dart           # 双页模式工具类
│   ├── image_cache_manager.dart       # 图片缓存管理器
│   ├── memory_manager_simplified.dart # 内存管理器
│   ├── page_animation_manager.dart    # 页面动画管理器
│   ├── parsers.dart                   # 数据解析器
│   ├── reader_gestures.dart           # 阅读器手势处理
│   ├── responsive_layout.dart         # 响应式布局工具
│   ├── smart_preload_manager.dart     # 智能预加载管理器
│   └── theme_manager.dart             # 主题管理器
└── widgets/                           # 界面组件目录
    ├── about_page.dart                # 关于页面
    ├── carousel_widget.dart           # 轮播组件
    ├── enhanced_reader_page.dart      # 增强版阅读器页面
    ├── history_page.dart              # 历史记录页面
    ├── loading_animations_simplified.dart  # 加载动画
    ├── main_navigation_page.dart      # 主导航页面
    ├── manga_detail_page.dart         # 漫画详情页面
    ├── manga_list_page.dart           # 漫画列表页面
    ├── page_transitions.dart          # 页面过渡动画
    ├── pagination_widget.dart         # 分页组件
    ├── search_page.dart               # 搜索页面
    ├── settings_page.dart             # 设置页面
    ├── tablet_main_page.dart          # 平板主页面
    └── tags_page.dart                # 标签页面
```

### 🔧 技术栈

**核心框架**
- **Flutter SDK**: >=3.0.0
- **Dart SDK**: >=3.0.0

**主要依赖包**
- `http: ^1.1.0` - HTTP客户端，用于API通信
- `cached_network_image: ^3.4.1` - 网络图片缓存
- `url_launcher: ^6.3.2` - URL启动器
- `shared_preferences: ^2.2.2` - 本地存储
- `drift: ^2.15.0` - 数据库ORM
- `sqlite3_flutter_libs: ^0.5.3` - SQLite支持
- `path_provider: ^2.1.1` - 路径提供器
- `package_info_plus: ^5.0.1` - 包信息获取

**开发依赖**
- `flutter_lints: ^3.0.0` - 代码质量检查
- `build_runner: ^2.10.3` - 代码生成
- `drift_dev: ^2.15.0` - Drift代码生成

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.0.0+
- Dart SDK 3.0.0+
- 支持平台：Android、iOS、Web、Windows、macOS、Linux ~~（支持但没适配）~~

### 安装与运行

```bash
# 克隆项目
git clone <项目地址>
cd heimanmanga-flutter-app

# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建发布版本
flutter build apk --split-per-abi --release
```

## 📊 版本信息

- **当前版本**: 0.1.20+1
- **Flutter SDK**: 3.35.0+
- **Dart SDK**: 3.9.0+

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。
