# v0.1.25 更新计划

## 已完成 (v0.1.25)

### 技术债清理
- ✅ pubspec 依赖约束更新 (`drift`/`drift_dev` ^2.15.0 → ^2.29.0)
- ✅ 错误处理规范化 (7处静默 catch 替换为 debugPrint)
- ✅ namespace 映射硬编码抽取为 TagUtils 工具类
- ✅ 搜索页复用 MangaCardWidget (删除重复的 `_buildSearchResultCard`)
- ✅ 补测试 (模型解析 + parsers + TagUtils, 9个测试全部通过)

### 用户体验提升
- ✅ 阅读偏好持久化 (翻页方向/双页布局/音量键翻页通过 SharedPreferences 存取)
- ✅ 漫画列表+标签页骨架屏加载 (替换 spinner)
- ✅ 章节列表阅读进度条 (替换二元已读标签)

### 新功能
- ✅ 收藏功能 (Drift Favorites 表 + 详情页收藏按钮 + 收藏Tab)
- ✅ 阅读统计 (设置页内嵌，展示累计漫画数/已读页数/平均进度)

---

## 已完成 (v0.1.26)

### 阅读器页面进一步拆分
- ✅ **已随 v0.1.26 发布**：`lib/widgets/enhanced_reader_page.dart` 已由 674 行精简至约 371 行
- 拆分结果：`reader_page_renderer.dart`（单页/双页/过渡页渲染）、
  `reader_controls.dart`（顶部栏 + 底部进度条）、`reader_status_widgets.dart`（加载态/错误态）

---

## 已完成 (v0.1.27)

### 质量加固（P0–P3 全部修复，详见 `CODE_REVIEW.md`）
- ✅ P0：竖屏翻页崩溃（未挂载 `PageController`）、release 使用 debug 密钥签名
- ✅ P1：竖屏页码按真实布局计算、错误重试可恢复、单一 WAL 数据库连接、音量键开关生效、过渡页污染总页数
- ✅ P2/P3：25 项缺陷 + 约 700 行死代码清理；`dart analyze --fatal-infos` 192 → 0；`flutter test` 9/9
- ✅ 发布链路：独立 release keystore、R8 压缩与资源裁剪、GitHub Actions CI

### 可用性（先好用再好看）
- ✅ 阅读器章节目录（换章无需退出阅读器）
- ✅ 底部常驻 2px 进度条 + 滑杆加粗
- ✅ 阅读器设置面板宽度自适应（原固定 350dp 几乎盖满竖屏）
- ✅ 搜索提交后收起 Hero，首屏让给结果
- ✅ 弹层（章节目录 / 章节过渡对话框）改为主题色，浅色模式不再出现黑弹窗

### 仓库与文档
- ✅ `pubspec.lock` 纳入版本控制；停止追踪 `android/local.properties` 与构建产物
- ✅ README 截图改为仓库内置 `docs/screenshots/`

---

## 待办 (后续版本)

- 视觉打磨（"好看"阶段）：封面→详情页 Hero 共享元素转场、统一圆角/间距/字号尺度、空状态与 chip 渐隐
- 阅读器其他主题化取舍待定：设置面板/控制栏是否也跟随浅色主题（当前与恒为黑底的画布保持一致）
- 平板布局（`isTablet`，≥600dp）与双指缩放手势尚无真机覆盖
- 本地化（l10n）与 iOS/桌面平台目录尚未建立
