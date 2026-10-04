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

## 待办 (后续版本)

- 暂无新增功能项；后续质量改进可参考 `CODE_REVIEW.md` 的 P2/P3 列表（死代码清理、测试覆盖、仓库卫生等）
