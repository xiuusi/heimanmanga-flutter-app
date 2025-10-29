# 这是一个完全使用AI编写的应用
这个应用是基于我之前用ai写的一个[漫画网站](https://c.xiongouke.top)做配套使用

本应用主要由Claudecode+deepseekV3.2和qwen-coder-cil完成
## 📸 应用截图

<div align="center">

### 主界面与搜索
<img src="https://github.com/user-attachments/assets/cffa91fe-7195-4a06-b92e-e038cb5b75dd" width="280" alt="主界面">
<img src="https://github.com/user-attachments/assets/d1a71907-5407-4f24-85b2-2d4daeb29adc" width="280" alt="搜索页面">

### 标签页与详情页
<img src="https://github.com/user-attachments/assets/ee529c8b-e740-4a89-872f-06cb40e218ff" width="280" alt="标签分类">
<img src="https://github.com/user-attachments/assets/143674d3-73ba-421d-85e3-4bd000723a06" width="280" alt="漫画详情">

</div>
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
    ├── enhanced_reader_page.dart      # 阅读器页面
    ├── carousel_widget.dart           # 轮播图组件
    ├── page_transitions.dart          # 页面过渡动画
    ├── loading_animations.dart        # 加载动画组件
    ├── advanced_animations.dart       # 高级动画组件
    ~└── performance_optimized_widgets.dart # 性能优化组件~
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

## 📊 版本信息

- **当前版本**: 0.1.10
- **Flutter SDK**: 3.35.0+
- **Dart SDK**: 3.9.0+

## 📄 许可证

MIT License
