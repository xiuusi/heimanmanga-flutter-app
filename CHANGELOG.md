# Changelog

## v0.1.27

本轮为质量加固版本：修复 P0–P3 全部问题（详见 `CODE_REVIEW.md`），并补齐发布链路与若干可用性缺口。

- **修复 (P0)**
  - 竖屏/网漫模式下翻页会调用未挂载的 `PageController`，抛 `StateError` 且误报"加载下一章失败"
  - release 包需手动签名，此前使用公开的 Android debug 密钥；现改为独立 release keystore（`android/key.properties` + `.jks`，均已 gitignore）
- **修复 (P1)**
  - 竖屏模式页码与跳转改为按列表真实布局计算（原先按屏高换算，页码与进度都不准）
  - 加载失败后"重试"永不复原（`errorMessage` 未清空）
  - 阅读进度/收藏各自建立 SQLite 连接且无 WAL/busy_timeout → 单例连接 + WAL + 移出 UI isolate
  - "音量键翻页"开关不生效，且关闭后仍吞掉系统音量键
  - 合成过渡页污染总页数（43 页章节显示 1/44，读完仅 95%）
- **修复 (P2/P3)**: 共 25 项 + 死代码清理
  - async 后使用 `context`（19 处）、预加载闭包代次号、非原子写入改原子 upsert、控制器补 dispose
  - 切 Tab 状态保留（`IndexedStack`）、搜索无限加载/防抖/过期响应、收藏失败态、详情页 N+1 改批量查询
  - 控制栏动画失效、切换阅读方向后页码不重映射、响应式断点（横屏手机不再误用平板布局）
  - 删除约 700 行死代码；`dart analyze --fatal-infos` 192 项 → **0**；`flutter test` 9/9 通过
- **新增**
  - **阅读器章节目录**：底部弹层直接切章，无需退出阅读器
  - **常驻极细进度条**（2px）：不呼出控制栏也能看到阅读进度；滑杆轨道加粗至 6px
  - 阅读器设置面板宽度自适应（原固定 350dp，在 360dp 宽手机上盖住 97%）
  - 搜索提交后收起 Hero 区，把首屏让给搜索结果
  - 章节过渡对话框与章节目录改为主题色，浅色/深色/纯黑自动跟随
  - GitHub Actions CI（`flutter analyze` + `flutter test`，锁定 Flutter 3.47.5）
  - release 开启 R8 压缩与资源裁剪（新增 `android/app/proguard-rules.pro`）
- **其他**
  - 仓库卫生：`pubspec.lock` 纳入版本控制；停止追踪 `android/local.properties` 与构建产物
  - README 截图改为仓库内置 `docs/screenshots/`，不再依赖 GitHub 外链

## v0.1.26

- **修复**: 阅读器休眠恢复后预加载失效，翻页黑屏问题。新增生命周期监听，应用回到前台时清空预加载记录并重新触发预加载
- **重构**: 阅读器页面进一步拆分，`enhanced_reader_page.dart` 从 681 行精简至 316 行（-54%）
  - 新增 `reader_page_renderer.dart` — 单页/双页/过渡页/图片渲染组件
  - 新增 `reader_controls.dart` — 顶部栏 + 底部进度条控件
  - 新增 `reader_status_widgets.dart` — 加载态/错误态/章节加载遮罩
  - `reader_controller.dart` 公开 `getPageGroups()`，消除页面端重复逻辑

## v0.1.25

- **收藏功能**: 本地 Drift 数据库收藏表，漫画详情页收藏按钮，主导航新增"收藏"Tab
- **阅读偏好持久化**: 翻页方向、双页布局、页面移位、音量键翻页通过 SharedPreferences 保存，下次阅读自动恢复
- **阅读统计**: 设置页新增阅读统计分区，展示累计阅读漫画数/已读页数/平均进度
- **章节进度可视化**: 漫画详情页章节列表显示阅读百分比进度条
- **骨架屏加载**: 漫画列表和标签页用骨架屏网格替换转圈加载指示器
- **体验提升**: 搜索页复用 MangaCardWidget，namespace 映射硬编码抽取为 TagUtils
- **代码质量**: 静默 catch 块替换为 debugPrint 日志，pubspec 依赖约束更新至最新版本
- **测试**: 新增模型解析、工具函数和 TagUtils 单元测试

## v0.1.24

- **主题系统**: 支持 Android 12+ 动态取色 (Monet)，自定义主题色（12色预设 + 色相选择器）
- **阅读器重构**: 提取 `ReaderController` + 独立 UI 组件，主文件从 2053 行缩减至 670 行
- **设置页面**: 新增显示模式切换（浅色/深色/自动）、清除阅读历史、缓存管理
- **阅读器**: 音量键翻页开关
- **修复**: 历史记录支持单条删除，`print()` 替换为 `debugPrint`
- **平板**: 侧边栏换用 Material 3 NavigationRail，布局优化

## v0.1.23

- 阅读器手势与缩放优化
- Drift 数据库持久化阅读进度
- 生产环境修复：debugMode 跟随构建模式
