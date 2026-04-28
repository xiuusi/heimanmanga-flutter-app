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

## 待办 (后续版本)

### 6. 离线下载
- **说明**: 读者目前全部在线拉图，无离线模式
- **工作量**: 大，需评估优先级

### 9. 阅读器页面进一步拆分
- **位置**: `lib/widgets/enhanced_reader_page.dart` (674 行)
- **说明**: 可拆分为手势处理 / 页面渲染 / 工具栏等独立组件

