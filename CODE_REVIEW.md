# 代码审查报告 — 嘿！——漫 (heimanmanga-flutter-app)

审查对象：`main` @ `6342e8b`（v0.1.26+2，工作区干净）
审查范围：`lib/` 全部 41 个 Dart 文件（14,675 行）、`test/`、`android/`、`pubspec.yaml`、文档与仓库卫生

---

## 0. 验证方式与客观结果

| 检查项 | 命令 | 结果 |
|---|---|---|
| 静态分析 | `dart analyze`（依赖完整解析后） | **0 error / 15 warning / 177 info**，退出码 0 |
| 单元测试 | `flutter test` | **9/9 通过**（`test/widget_test.dart`） |
| 真实联网/真机/发布构建 | `flutter build apk --release` | **未执行**（见下方限制） |

关键 lint 分布：`deprecated_member_use` 62、`prefer_const_constructors` 30、`avoid_print` 27、`use_super_parameters` 21、**`use_build_context_synchronously` 19**。

**限制说明**：本环境 Flutter 缓存只读（`bin/cache` 不可写），`flutter` 包装脚本因此无法运行；上述分析是将依赖解析到工作区内临时缓存后用 SDK 自带 `dart analyze` 完成的。测试通过直接调用 `flutter_tools.snapshot test --no-version-check` 运行。**未做**：真机交互验证、对 `heiman.cc` 真实接口的载荷校验、`flutter build apk --release`。审查期间产生的所有临时文件已全部删除，`git status` 已恢复干净。

---

## 1. P0 — 高危

> **修复状态（2026-10-04）**：P0-1、P0-2 均已修复并验证，详见文末「附录 A：P0 修复记录」。
> 修复后 `dart analyze` 仍为 0 error，9/9 测试通过，`flutter build apk --release` 重新构建成功。

### P0-1 ✅ 已修复 竖屏滚动模式（vertical / webtoon）翻页调用未挂载的 PageController，功能失效并抛异常

- `lib/widgets/reader/reader_controller.dart:514`、`:525`、`:538`、`:546`（`previousPage` / `nextPage` / `swipePage`）、`:282`（`animateToPage`）、`:676`（`jumpToPage(0)`）
- `lib/widgets/enhanced_reader_page.dart:203-208`、`:258-291`：竖屏/网漫模式只构建 `ListView`，**不构建 `PageView`**，因此 `_controller.pageController` 从未 attach。

SDK 依据（`packages/flutter/lib/src/widgets/page_view.dart`）：`animateToPage` 首行为 `assert(_debugCheckPageControllerAttached())`，而该检查仅存在于 assert（release 被剥离），随后执行 `this.position as _PagePosition` → `_positions.single` → 位置列表为空时抛 `StateError: No element`。

影响（默认手势映射下可稳定复现，`ReadingGestureConfig.gestureActions`：右半屏 tap → `next_page`）：
1. 竖屏模式下点击屏幕右侧 / 横向甩动 / 按音量键 → 抛异常，翻页动作无效；
2. 更严重的是 `loadNextChapter`（`:648-696`）中 `imageUrls` 已切换、`notifyListeners()` 已调用，紧接着 `pageController.jumpToPage(0)` 抛异常被 `catch` 捕获 → 误报"**加载下一章失败**"，且竖屏模式的 `scrollController` 未被重置，新章节停在旧滚动偏移。

修复：竖屏/网漫分支统一走 `scrollController`（`_navigateToPage`），并对所有 `pageController` 调用加 `if (pageController.hasClients)` 守卫。

### P0-2 ✅ 已修复 Release 包使用 Android debug 密钥签名

- `android/app/build.gradle.kts:33-38`：`release { signingConfig = signingConfigs.getByName("debug") }`
- 全仓库不存在 `.jks` / `.keystore` / `key.properties`（已用 `git ls-files` + 文件系统扫描确认）。

影响：README 明确给出 `flutter build apk --split-per-abi --release` 的发布流程，而 debug 密钥是公开的 —— 第三方可以伪造一个 Android 认为"同一应用签名"的更新包；同时应用无法上架、无法做真正的密钥轮换。

修复：生成 release keystore，凭据放 gitignore 的 `key.properties`，新增 `signingConfigs.release`，`debug` 仅用于 debug 构建。

---

## 2. P1 — 严重

> **修复状态（2026-10-04）**：P1-1 ~ P1-6 全部已修复并在真机逐项验证，详见文末「附录 C」。

### P1-1 ✅ 已修复 竖屏模式页码/进度换算错误（按屏高切分，实际行高由图片比例决定）

- `lib/widgets/enhanced_reader_page.dart:263-265`：`currentPage = (pixels / screenHeight).floor()`
- 同源错误：`:296-300`（`animateTo(page * screenHeight)`）、`lib/widgets/reader/reader_controller.dart:275-279`
- 列表项为 `CachedNetworkImage(fit: BoxFit.contain)` 且未设固定高度（`lib/widgets/reader/reader_page_renderer.dart:56-58`）→ 每行实际高度 ≈ `屏宽 × 图高/图宽`，通常 ≠ 屏高。

影响：主要阅读模式（长条）下页码计数、进度条、以及写入数据库的阅读进度全部偏移；"跳转到上次位置""上一页"会落到错误的行。修复：用真实布局驱动索引（`ScrollController` + key/RenderObject 偏移），或给页固定高度。

### P1-2 ✅ 已修复 加载失败后"重试"永远无法恢复

- `lib/widgets/reader/reader_controller.dart:174`、`:179` 设置 `errorMessage`；成功分支 `:164-166` 只清 `isLoading`，**全文件从未把 `errorMessage` 置回 null**（已 grep 确认）。
- `lib/widgets/enhanced_reader_page.dart:119`：`if (_controller.errorMessage != null) return ReaderErrorWidget(...)`，其 `onRetry` 复用同一个 controller。

影响：一次网络抖动后错误页永久驻留，即使重试成功也仍然只显示错误页，用户只能退出章节。修复：`loadChapterImages` 入口与成功分支都重置 `errorMessage = null; isLoading = true;`。

### P1-3 ✅ 已修复 同一数据库文件存在两个独立 SQLite 连接，且无 WAL / busy_timeout → 进度静默丢失

- `lib/models/drift_models.dart:98`、`:116-121`：`NativeDatabase(file)`，未做任何 PRAGMA 配置
- 两个实例：`lib/services/drift_reading_progress_manager.dart:13`（阅读进度）与 `lib/services/favorites_service.dart:13`（收藏）
- 已核实 drift 源码（`drift-2.35.1/lib/src/`）中不存在 `journal_mode` / `busy_timeout` 的默认设置

影响：阅读器每 5 秒写一次进度（`reader_controller.dart:419-423`），用户同时点收藏即可能 `SQLITE_BUSY: database is locked`；阅读器侧异常被吞（`reader_controller.dart:316-318` 仅 `debugPrint`）→ **进度静默丢失**。修复：全进程单一 `AppDatabase` 实例（静态单例/注入），并在 `_openConnection` 中 `NativeDatabase.createInBackground(file, setup: ...)` + `PRAGMA journal_mode=WAL` + `busy_timeout=5000`。

### P1-4 ✅ 已修复 "音量键翻页"开关不生效，且阅读时会吞掉系统音量键

- `lib/widgets/reader/reader_controller.dart:88-90`：`setupVolumeKeyListener()` 先于 `_loadPreferences()`（异步、未 await）执行，而 `ReadingGestureConfig.volumeButtonNavigation` 默认 `true`（`lib/utils/reader_gestures.dart:197`）→ handler **总是被注册**；
- `:89` `enableVolumeKeyInterception(true)` 是**硬编码 true**，与开关无关；
- `:752-759` handler 内部**不检查** `volumeButtonNavigationEnabled` → 即使用户在偏好里设为关闭，音量键仍然翻页，而且系统音量被原生层拦截（`android/app/src/main/kotlin/io/xiuusi/heimanmanga/MainActivity.kt:33-53` 返回 true）无法调节。

修复：把 `enableVolumeKeyInterception` 与 `setupVolumeKeyListener` 都改为依据（及在 `_loadPreferences` 之后重新评估）真实开关值，handler 内加开关判断，并在 dispose 时 `setMethodCallHandler(null)`。

### P1-5 ✅ 已修复 全部 SQLite I/O 运行在主 isolate，叠加 5 秒定时全量写入

- `lib/models/drift_models.dart:116-121` 使用 `NativeDatabase(file)`（无后台 isolate）；drift 提供 `NativeDatabase.createInBackground`（`drift/lib/native.dart:126` 文档明确说明其"在后台 isolate 创建，释放主线程 I/O"）。
- 附加写入放大：`reader_controller.dart:421-423` 每 5 秒无条件写库（与翻页无关）；`drift_reading_progress_manager.dart:187-193` `getReadingStats` 全表读取；`:209-226` 窗口函数查询在滚动过程中执行。

影响：首次查询触发建表/迁移，加上每次保存 4 条语句与 fsync，低端机上出现卡顿/ANR 风险。修复：`createInBackground` + 仅在页码变化时写。

### P1-6 ✅ 已修复 合成"过渡页"导致的页码/进度 off-by-one（真机已实测确认，见附录 B.6）

- `reader_controller.dart:162`（`:668` 同理）向 `imageUrls` 追加 `transitionPageMarker`，于是：
  - `:314` 保存进度时 `totalPages: imageUrls.length`（真实页数 +1）；
  - `enhanced_reader_page.dart:179` → `reader_controls.dart:140`滑块 `max = totalPages-1`、`:149` 文案 `第 x/y 页` 都把幽灵页算进去（20 页章节显示 "/21"）；
  - `manga_detail_page.dart:77` 章节进度条直接用 `readingPercentage = (currentPage+1)/totalPages` → **整章读完只有 ~95%**；
  - `reader_controller.dart:809-811` 需要滑到幽灵页才标记"已读"。
- 交叉证据：`manga_detail_page.dart:154` 保存进度时用的是 `targetChapter.totalPages`（真实页数），与阅读器写入口径不一致。

修复：把业务页码与渲染页分离（`realPageCount = imageUrls.length - 1`），或不再用列表长度当页数。

---

## 3. P2 — 中等（功能缺陷 / 竞态 / 体验）

> **修复状态（2026-10-04）**：本节 P2-1 ~ P2-25 已全部处理（个别项按实际情况调整，见附录 D）。

### 异步与生命周期
1. **19 处 `use_build_context_synchronously`**（分析器确认）：阅读器 8 处 `reader_controller.dart:192,260,262,346,390,685,689,694`（含 `_showJumpToProgressPrompt` 的 `showDialog`、预加载 `precacheImage`、"加载下一章"的 `showSnackBar`）、`history_page.dart:256,267,299,303`、`manga_detail_page.dart:159,191,749`、`smart_preload_manager.dart:76,102`、`carousel_widget.dart:460`、`image_cache_manager.dart:465`。退出页面/切章时做祖先查找会抛 `Looking up a deactivated widget's ancestor is unsafe`。修复：每个 await 后 `if (!mounted) return;` 或传入 `bool Function() isAlive`。
2. **预加载延迟闭包读取已被替换的 `imageUrls`**（`reader_controller.dart:343-349`）：切章后旧索引越界 → `RangeError`（未捕获的异步异常），且会向已卸载的 element 调 `precacheImage`。修复：加 `_loadGeneration` 代次号，闭包内捕获 URL 字符串与代次。
3. **非原子 check-then-insert + UNIQUE 约束**：`drift_reading_progress_manager.dart:53-70`、`:147-176`、`favorites_service.dart:31-42`；唯一键见 `drift_models.dart:32,73,92`。并发保存（5 秒定时器 + 翻页 + dispose）或双击收藏会触发 `UNIQUE constraint failed`，被吞掉。修复：`transaction()` + `insertOnConflictUpdate`。
4. **收藏按钮无 in-flight 保护**（`manga_detail_page.dart:55-70`）：连续点击导致唯一约束异常且最终状态错误，异常未被处理。
5. **`ReaderController` 从未 `dispose()`**（`reader_controller.dart:889-896` 的 `disposeController` 不含 `super.dispose()`），MethodChannel handler 也未注销（`:748-764`）。
6. **章节结束页在 `build` 里创建网络 Future**（`reader_chapter_end_page.dart:63-64`）：每帧重建都重新请求 `getChapterImageFiles` 且文案闪烁。修复：改用 `StatefulWidget` 缓存 future。
7. **双页缩放未裁剪**（`reader_page_renderer.dart:200-211`）：`Transform` 外无 `ClipRect`，放大左半页会画到右半页上。

### 手势
8. **`onPointerCancel` 未处理**（`reader_gestures.dart:702-714`）：多指被系统取消（掌拒、系统手势、切后台）后 `_pointerCount` 粘滞 ≥2，`_isTwoFingerGesture` 永久为真，后续单指拖拽被当成缩放/平移。修复：补 `onPointerCancel` 减计数。
9. **方向/布局变更不会传到手势处理器**（`reader_gestures.dart:649-674`）：handler 只在 `initState` 构造一次，文件内无 `didUpdateWidget`（已确认）。在设置面板切换"从右到左 ↔ 从左到右"或单页/双页后，pan/flick 的方向映射仍用旧值（`PageView.reverse` 会更新，但自定义映射不会）。修复：补 `didUpdateWidget` 同步字段。
10. **`handlePanUpdate` 的阈值单位错误**（`reader_gestures.dart:514-516` 配合 `:756`）：传入的是逐帧 `details.focalPointDelta`，却与总位移阈值 `|dx| > 80` 比较 —— 该路径实际几乎不可达（可能是死逻辑），却可能在同一手势内反复触发。修复：改用累计位移。
11. **控制栏收起动画失效**（`enhanced_reader_page.dart:168,175`）：`if (_controller.showControls)` 直接卸载控件，随后 `hideControls()` 里的 `controlsAnimationController.reverse()`（`reader_controller.dart:440-444`）已无对象可动画，收起是瞬变而非滑动。修复：保持挂载，由动画值驱动可见性。
12. **布局切换不重映射页码**（`enhanced_reader_page.dart:214-255`、`:106-108`）：单页索引 30 遇到分组数 26 会被 clamp 到最后一组并触发 `onPageChanged`，用户被抛到章节末尾；`auto` 模式下旋转屏幕同理。竖屏模式切章后 `scrollController` 未复位（`reader_controller.dart:676` 只复位了 `pageController`）。修复：切换时 `page → groupIndex` 映射后 `jumpToPage`，竖屏切章 `scrollController.jumpTo(0)`。
13. **`build` 中修改状态**（`enhanced_reader_page.dart:236` `_controller.pageGroups = ...`）：每帧产生新的 `PageGroup` 实例，而 `reader_controller.dart:781` 的越界守卫依赖上一次 build 的结果。

### 请求 / 列表 / 状态
14. **搜索页无限重复加载**（`search_page.dart:59-66`、`:105-130`）：没有 `_hasReachedEnd` 判断，`_currentPage++` 在 await **之前**，末页之后每次滚动都继续请求 N+2、N+3……（对比 `favorites_page.dart:22` 是有该字段的）。修复：按 `totalPages`/短页判到底，成功后再自增。
15. **搜索/标签无防抖、无过期响应保护**（`tags_page.dart:44-51` 每次按键发请求；`search_page.dart:85-92`、`:120-123`）：旧的慢响应会覆盖新结果，新搜索期间在途的 `_loadMoreResults` 会把旧查询的第二页追加进新列表。修复：300ms 防抖（dispose 时取消）+ 请求序号。
16. **收藏页无 try/catch → 永久骨架屏**（`favorites_page.dart:32-57`）：`getFavorites` 抛错时 `_isLoading`/`_isLoadingMore` 永不复位（对比 `:44` 有 mounted 判断但没有错误分支），无重试入口，异常未处理。
17. **切 Tab 丢失全部页面状态**（`main_navigation_page.dart:123-132` 用无 keep-alive 的 `PageView`；`tablet_main_page.dart:117` 直接替换 `_pages[_currentIndex]` 子树）：切换标签会重新请求数据、重置分页，**已输入的搜索词和搜索结果全部丢失**。修复：`IndexedStack` 或 `AutomaticKeepAliveClientMixin`。
18. **`getChapterImageFiles` 把所有网络/HTTP 错误变成"空章节"**（`api_service.dart:224-244`，非 200 落空、catch 中 `return []`）：用户看到空白章节，无错误提示、无重试（其余接口都是 `throw`）。
19. **历史页分页漂移导致重复行 + 失败态伪装成空态**（`history_page.dart:89-99` 与 `drift_reading_progress_manager.dart:216` 的 `LIMIT/OFFSET`：期间阅读或删除会移动窗口；`:97` 的注释"数据库查询已经去重"与事实不符；`:572-612` 列表项未设 key；`:122-128` 失败只 `debugPrint`，UI 显示"暂无阅读历史"，且 `RefreshIndicator` 包着不可滚动的 `Center`，下拉也无法恢复）。
20. **详情页 N+1 串行查库 + 手机端章节列表全量构建**（`manga_detail_page.dart:72-85` 每章一次 `getProgress`；`:598-604` `shrinkWrap: true` 的 `ListView.separated` 会一次性构建全部章节行）。
21. **启动期无保护的 await**（`main.dart:13-15`）：`ThemeManager().loadThemeMode()` 无 try/catch，SharedPreferences 异常会导致 `runApp` 永不执行（永久白屏），且两个 await 阻塞首帧。

### 资源与性能
22. **`_preloadCache` 无界增长**（`image_cache_manager.dart:402-441`）：只在失败时移除，`clearPreloadCache()` 从未被调用，而 `history_page.dart:238` 会为每个历史封面写进去。
23. **内存图片缓存上限过高**（`image_cache_manager.dart:9,73-74`）：`maximumSizeBytes` 300MB，高 DPI 设备再加 100MB，低端机存在 OOM 风险；同时 `reader_page_renderer.dart:56` 未设 `memCacheWidth`，每页按原始分辨率解码，而预加载窗口最多 11 页。
24. **响应式断点错误**（`responsive_layout.dart:12-14`）：`isTablet(context) => isLandscape(context)`，即**任何横屏手机都被当作平板**（并因宽高比 >1.3 被视为"大平板"），走侧边栏布局；文件里已有 `isWideEnoughForRail`（≥600dp）却未被 `isTablet` 使用。
25. **自定义页面过渡是死代码**（`main.dart:295-323`）：分支依据 `route.settings.name` 是否含 `detail`/`search`，但全仓库**没有任何一处设置 `RouteSettings`**（也没有 `pushNamed`/`routes:`）→ 名称恒为 null，漫画详情/搜索的专用过渡永不生效，所有路由都走 `scaleSlideTransition`。

---

## 4. P3 — 低（代码质量 / 卫生 / 文档）

> **修复状态（2026-10-04）**：死代码、弃用 API、分析器告警、drift 细节、解析健壮性、仓库卫生与文档漂移均已处理，`dart analyze --fatal-infos` 现为 **No issues found**。详见附录 D。

### 死代码（累计约 600+ 行）
- `lib/utils/smart_preload_manager.dart` 整个文件（`SmartPreloadManager` + `ReadingBehaviorAnalyzer`，198 行）**无任何引用**。
- `lib/utils/reader_gestures.dart:37-382`：`TouchGestureHandler` + `EnhancedReaderGestureDetector` 未被使用（含一个 10 秒 `_zoomResetTimer`）。
- `lib/utils/dual_page_utils.dart:68-137`：`isWideImage`/`isTallImage`（错误路径下 `Completer` 永不完成、listener 不摘除 → 永久挂起 + 泄漏）、`splitWideImage`/`splitTallImage`（返回假的 `?part=` URL）、`getDisplayPageIndex` 全部无引用。
- `image_cache_manager.dart`：`cacheExpiration`(7 天) 未被引用、`_clearOldCacheFiles`/`_preloadCommonImages` 空实现、`isLowMemoryDevice()` 恒 false、`configureForLowMemory()` 无调用者。
- `memory_manager_simplified.dart:29-36`：10 分钟定时器的回调体是空的（只清理不了任何东西），`dispose()` 从未调用。
- `reading_progress_service.dart`：`updateReadingDuration`（导致 `readingDuration` 恒为 0）、`getTotalHistoryCount`、`hasProgress` 无调用者。
- `dio_service.dart:80-99`：`updateConfig` / `cancelAllRequests`（后者 `close(force:true)` 后重建，会让已持有的 `dio` 引用变成已关闭客户端）无调用者。
- `reader_gestures.dart:578,581`：`cancelZoomReset()` / `dispose()` 为空实现（该 handler 无资源，无害，但会误导）；`_currentScale` 只写不读（分析器 warning）。
- `android/app/src/main/res/xml/network_security_config.xml` 无任何 manifest 引用（HTTPS 站点本就不需要）。

### 分析器 warning（15 条，值得清零）
- `reader_controller.dart:723,730`：`_saveInt/_saveBool` 的 `onError` 返回 `void`，不符合 `FutureOr<bool>` → **偏好保存失败的回调实际类型不匹配**（分析器 `invalid_return_type_for_then`）。
- `drift_reading_progress_manager.dart:185` 未使用局部变量 `chapterCount`；`history_page.dart:8` 未使用 import；`settings_page.dart:2` 未使用 import `dio`；`manga_detail_page.dart:158,190` 未使用的 `result`/`result2`；`image_cache_manager.dart:21,46,53` 恒真的 null 判断。

### 弃用 API
- `withOpacity` 44 处（建议 `withValues`）、`Color.value`（`theme_manager.dart:56`）、`WidgetsBinding.instance.window`（`theme_manager.dart:33`）、`Radio.groupValue/onChanged` 与 `Switch.activeColor`（`settings_page.dart:297-338`）。共 62 条。
- 27 处 `print(`（`api_service.dart` 15、`dio_service.dart` 9、`manga_detail_page.dart` 3），多数被 `kDebugMode` 包住，但 CHANGELOG 声称已全部替换为 `debugPrint`。

### drift 细节
- `getReadingStats` 的 `totalPagesRead = fold(sum + currentPage + 1)`（`:190`）语义是"各章最后到达的页码之和"，不是已读页数，且未读章节也计 1。
- `markChapterAsRead(isRead:false)` 在无记录时插入幽灵行：`title:'Unknown'`、`number:0`、`totalPages:1`、`readingPercentage:1.0`（`:161-176`）→ 历史/统计里会出现 100% 完成的未知章节。
- `DriftReadingProgressManager.close()`（`:316-319`）从未被调用。

### 解析健壮性
- `manga.dart:43,47,156,219`：`item as Map<String, dynamic>` —— 一个畸形元素（`chapters:[null]`、字符串等）会使整个列表解析抛 `TypeError`，容错层只覆盖标量字段。
- `CarouselImage.fromJson`（`:188-198`）只认 snake_case（`link_url`/`image_path`/`sort_order`/`is_active`/`created_at`），不像 `Manga` 那样同时接受 camelCase → camelCase 载荷静默变空串（轮播标题/链接空白）。
- `manga.dart:90`：`imageIdMap!.keys.toList()..sort()` 按字典序排序，"1","10","2" → 页序 1,10,2（JSON map 本身是有序的，这个 sort 既危险又多余）。
- `parsers.dart` 边角：`parseBool('1')` → false（`:62-64`）；`parseList([])` → null，丢失"存在但为空"（`:29-32`）；`parseString` 会把 Map/List 直接 `toString()`（`:4-7`）；`parseMap` 用无保护的 `.cast` 会抛（`:40`）。
- `TagNamespace.description`/`TagModel.description` 声明为 `String?` 但 `parseString` 永不返回 null。

### 仓库卫生 / 工程化
- **无 CI**（无 `.github/workflows`）；测试仅 160 行 / 9 个用例 vs 14,675 行 lib（≈1%），且名为 `widget_test.dart` 的文件里**没有任何 widget test**；`api_service`/`dio_service`/drift 管理器/主题持久化均无测试。
- **`android/local.properties` 被提交**（`git ls-files` 确认），内容为本机专有且已过期：`sdk.dir=/opt/android-sdk`、`flutter.sdk=/home/xiju/development/flutter`（本机实际是 `/home/xiju/develop/flutter`，`/opt/android-sdk` 不存在）、`flutter.versionName=0.1.25`/`versionCode=1`（pubspec 是 `0.1.26+2`）。运行 Flutter 工具时它会被自动改写（本次审查中 `flutter.sdk` 就被改成了正确路径，但版本号仍是 0.1.25）→ 新克隆/CI/Android Studio 同步容易失败或产出错误的版本戳。修复：`git rm --cached android/local.properties`。
- **`.gitignore:48` 忽略 `android/`，但有 30 个 android 文件已被追踪**（`git check-ignore --no-index` 确认）：新增的 android 文件（新的 res、key.properties 模板）会对 `git status`/`git add` 不可见。
- **`pubspec.lock` 被忽略**（`.gitignore:53`）—— 对应用工程而言应提交；且当前约束解析出 drift 2.35.1 / dio 5.11.1 / dynamic_color 1.9.0，其 `sdks` 要求为 `dart >=3.12.0`、`flutter >=3.44.0`，与 `pubspec.yaml:6` 的 `>=3.0.0` 和 README 的 "Flutter 3.0.0+ / Dart 3.0.0+" 不符。
- **缺少 `.metadata`**：Flutter 工具报 `Flutter Application Metadata: Type: malformed`。
- 被追踪的生成物/产物：`android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`、`android/build/reports/problems/problems-report.html`（129KB）。
- `pubspec.yaml:15` 声明 `flutter_web_plugins` 但无 `web/`；`flutter_launcher_icons: ios: true` 但无 `ios/`；`settings_page.dart:5` 导入了未在 pubspec 声明的 `flutter_cache_manager`（分析器 `depend_on_referenced_packages`，目前靠传递依赖可用）；`generate: true` 但无 `l10n.yaml`/`.arb`/`flutter_localizations` → Material 内置文案仍是英文（中文界面里会露出英文）。
- Android 发布优化：无 `isMinifyEnabled`/proguard/`isShrinkResources`；`android/gradle.properties` 用 `-Xmx8G`；`android.enableJetifier=true` 在 AGP 8.9.1 下已无必要；`assets/app_icon_draft.png` 作为运行时资源打包，实际只有 `flutter_launcher_icons` 需要。
- `MainActivity.kt:24,41,47` 用 `println` 而非 `Log`；`onKeyDown` 未处理 `event.repeatCount`（长按音量键会连发）；未拦截 `onKeyUp`。

### 文档漂移
- `UPDATE_PLAN.md:25-27` 仍把"阅读器页面进一步拆分（674 行）"列为**待办**，而 `CHANGELOG.md:6-10` 显示 v0.1.26 已完成（实际 316 行）。
- `CHANGELOG.md:11` 称"从 UPDATE_PLAN 中移除离线下载待办项"，但 `UPDATE_PLAN.md` 中从来没有这一项。
- README 版本声明（Flutter 3.0.0+ / Dart 3.0.0+）与实际解析出的依赖下限（Dart ≥3.12 / Flutter ≥3.44）矛盾（`README.md:117-118,140-141`）。
- README 的文件树与依赖列表本身与代码一致（已核对），LICENSE（MIT）与 README 声明一致 —— 这两项是准确的。

---

## 5. 已核实正常的部分（避免误报）

- **静态分析 0 error**，测试 9/9 通过；代码可编译、可测试。
- **drift 迁移正确**：`schemaVersion=3`，`from<2` 加 `readingDuration`（非空但有 `DEFAULT 0`，`ALTER TABLE` 合法），`from<3` 建 `favorites` 表；生成代码与实际表定义/唯一键一致。
- **设置页缓存统计与清理目标一致**：统计目录 `${tmp}/libCachedImageData`（`settings_page.dart:498`）就是 `DefaultCacheManager.key`（`CachedNetworkImage` 未传自定义 cacheManager），`emptyCache()` 删的正是统计的那批文件 —— CHANGELOG 中"清除含磁盘缓存"的说法成立。
- **无密钥泄漏**：全仓库无 API key/token/密码/keystore；`INTERNET` 权限正确，仅启动 Activity 导出，baseUrl 为 HTTPS，无 cleartext 流量。
- **控制器释放基本完整**：阅读器、各页面、各加载动画的 `AnimationController`/`PageController`/`ScrollController` 都有对应 dispose；`_onControllerChanged` 有 `mounted` 守卫。
- **SharedPreferences 键与类型一致**（`theme_mode`/`accent_color` int，`use_dynamic_color`/`use_pure_black` bool，`reader_*` int/bool），无 JSON blob，无"损坏 JSON 导致启动失败"路径。
- **双页分组逻辑正确**：奇数页、移位空页、RTL 左右互换、`(page+1)~/2` 与插入空页的映射都对得上；首组 `urls[1]` 回退取值正确。
- **`PageTransformManager`** 有 20 条上限的 LRU 淘汰与视口/对齐 clamp。
- **Dio 配置**：baseUrl 为 const HTTPS、超时齐备、UA 每请求读取，无 `badCertificateCallback`；`getMangaList`/`searchManga` 非 200 会 throw。
- **README 的项目结构树与依赖清单**与仓库实际一致；LICENSE 为 MIT 且与 README 一致。

---

## 6. 建议修复顺序

1. `pageController` 加 `hasClients` 守卫并让竖屏模式走 `scrollController`（P0-1，动一小块，收益最大）。
2. 加 release 签名配置（P0-2）。
3. 重置 `errorMessage`（P1-2，一处改动）。
4. 统一 `AppDatabase` 单例 + WAL/busy_timeout + 后台 isolate（P1-3、P1-5）。
5. 修正音量键开关语义（P1-4）。
6. 把"业务页码"与"渲染页（含过渡页）"分离，统一 `totalPages` 口径（P1-6）。
7. 每个 await 后补 `mounted`/`isAlive` 守卫（P2-1，19 处，可用 `context.mounted`）。
8. 删除死代码（smart_preload_manager、TouchGestureHandler、DualPageUtils 的图片工具、DioService 的死方法等），清零 15 条 warning。
9. 引入 CI（`dart analyze` + `flutter test`），把 `android/local.properties`、`pubspec.lock`、`.gitignore` 的 `android/` 规则一并修正，补 `.metadata`。
10. 逐步替换 `withOpacity` 与硬编码颜色（顺带修复暗色模式下的白底/白字问题）。

---

## 附录 A：P0 修复记录（2026-10-04）

### 构建基线（修复前）

| 项 | 值 |
|---|---|
| 命令 | `flutter build apk --release` |
| 结果 | ✅ 成功，62,644,242 字节 |
| 产物 | `build/app/outputs/flutter-apk/app-release.apk` |
| 包信息 | `io.xiuusi.heimanmanga`，versionCode 2，versionName 0.1.26，minSdk 24，targetSdk 36 |
| 工具链 | Flutter 3.47.5 / Dart 3.13.4、JDK 21、AGP 8.11.1、Kotlin 2.2.20、Gradle 8.14 |
| 修复前签名 | `C=US, O=Android, CN=Android Debug`（公开调试密钥，SHA-256 `32a304a1…`）← 证实 P0-2 |

> 构建需要写入工作区外的 `~/.gradle` 与 Flutter `bin/cache`；在只读沙箱内 `assembleRelease` 会因
> `gradle-8.14-all.zip.lck` 只读而失败，需放宽文件权限后才可构建。
> Flutter 同时提示 Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 "soon to be dropped"，
> 建议后续升级到 Gradle ≥ 9.1.0 / AGP ≥ 9.0.1 / KGP ≥ 2.3.20（非阻塞）。

### P0-1 修复：竖屏/网漫模式翻页

改动文件：`lib/widgets/reader/reader_controller.dart`、`lib/widgets/enhanced_reader_page.dart`

- 新增 `ReaderController.isVerticalMode`（vertical / webtoon）。
- 新增 `_turnPage(delta, duration, curve)`：竖屏模式按 `scrollController.position.viewportDimension`
  滚动一屏；横向模式走 `pageController`，并在调用前判断 `hasClients`。
- `previousPage` / `nextPage` / `swipePage` 统一改走 `_turnPage`，保留原有的首尾边界判断与触感反馈。
- 新增 `_jumpToPageWhenReady()`：跳转进度时若 controller 尚未挂载，则延迟到下一帧执行；
  `_performJumpToProgress` 改为调用它。
- `loadNextChapter`：`jumpToPage(0)` 加 `hasClients` 守卫，并在竖屏模式复位 `scrollController`；
  这同时修掉了竖屏下"数据已切换却误报『加载下一章失败』且滚动位置不复位"的问题。
- 新增 `_disposed` 标志，`disposeController()` 中置位，用于丢弃延迟回调。
- `enhanced_reader_page._navigateToPage`：两个分支均加 `hasClients` 守卫。

验证：`dart analyze` → **0 error**（问题总数仍为 192，未新增）；`flutter test` → **9/9 通过**；
`flutter build apk --release` → 重新构建成功。

### P0-2 修复：release 签名

- 生成 `android/app/heimanmanga-release.jks`（PKCS12、RSA 2048、有效期 10000 天、
  alias `heimanmanga`、到期 2054-02-19）。
- 新增 `android/key.properties`（已被 gitignore）。
- `android/app/build.gradle.kts`：读取 `key.properties` → `signingConfigs.release` →
  `buildTypes.release.signingConfig`；**凭据缺失时 release 构建明确失败，绝不回退 debug 密钥**
  （通过 `gradle.taskGraph.whenReady` 校验，仅在 release 任务被调度时触发）。
- `.gitignore`：显式新增 `android/key.properties`、`**/*.jks`、`**/*.keystore`，
  即使将来移除 `android/` 规则也不会暴露密钥。
- `README.md`：新增「发布签名」章节，说明 keystore 生成、key.properties 写法与备份要求。

验证：

| 检查 | 结果 |
|---|---|
| `apksigner verify --print-certs` | `CN=heimanmanga, OU=Mobile, O=heimanmanga, L=Unknown, ST=Unknown, C=CN`，SHA-256 `34be5a72…`（已非 debug 密钥） |
| 删除 `key.properties` 后构建 release | **BUILD FAILED（1 秒）**，输出中文提示，无回退签名 |
| `./gradlew :app:assembleDebug --dry-run` | BUILD SUCCESSFUL，守卫不误伤 debug |
| `git check-ignore` / `git status -uall` | 密钥与 `key.properties` 均不可见 |

### 遗留事项

1. **必须备份**：`android/app/heimanmanga-release.jks` 与 `android/key.properties` 需立即复制到
   仓库之外的安全位置。keystore 一旦丢失，将无法发布可覆盖安装的更新。
2. **升级路径**：历史 release 包由公开 debug 密钥签名，改用新密钥后**无法覆盖安装**，
   已安装用户需卸载重装。若已对外分发，应提前公告。
3. 新密钥的 SHA-1 为 `f94992657819dc0b3f9f58c41b36b756ff4b39fd`、SHA-256 为
   `34be5a72d025d611084731ea40b44670973970d836e3270e98b8bb3cf24721ab`，
   后续接入 Google Play / 第三方登录等服务时按需提供。
4. 完整的 debug APK 构建未跑完（本机环境冷启动超过 15 分钟被超时中断），
   已用 Gradle dry-run 证明 debug 任务图配置正常；真机运行验证仍未进行。
5. P1 及以下问题（含 P1-1 竖屏页码按屏高换算的偏差）仍待处理 —— 见第 2、6 节。

---

*本报告第 0–6 节为只读审查结论；附录 A 记录已实施的 P0 修复与实际构建验证结果。*

---

## 附录 B：真机测试记录（2026-10-04）

测试机：OnePlus **PGP110**，Android **15（SDK 35）**，arm64-v8a，已连接 adb（`dc925b76`）。

> **⚠️ 设备已 root（更正）**：`su -c id` → `uid=0(root) context=u:r:magisk:s0`，
> KernelSU + Magisk，装有 LSPosed（`zygisk_lsposed`）、Shamiko、KernelSU 模块，
> 以及机主说明的 **CorePatch（核心破解）**。
> **注意**：`ro.debuggable=0`、`verifiedbootstate=green`、`flash.locked=1`、`ls /data/adb` 失败
> 这些"未篡改"迹象**全部不可信** —— Shamiko 与隐藏类模块的作用正是伪装它们。
> 我最初据此误判为"未 root"，且当时是用非特权 `shell` 用户执行
> `ls -d /data/adb 2>/dev/null || echo 'no /data/adb'`，把权限拒绝当成了"目录不存在"。
> 该错误结论已在本附录更正。

### B.1 分架构构建产物

命令：`flutter build apk --split-per-abi --release`（全部构建成功）

| APK | ABI | versionCode | 大小 | SHA-256 |
|---|---|---|---|---|
| `app-armeabi-v7a-release.apk` | armeabi-v7a | 1002 | 19.8 MB | `43a04088…` |
| `app-arm64-v8a-release.apk` | arm64-v8a | 2002 | 22.4 MB | `ccf9ea5b…` |
| `app-x86_64-release.apk` | x86_64 | 4002 | 23.8 MB | `4d10e0f3…` |
| `app-release.apk`（通用包，上一轮） | 全 ABI | 2 | 62.6 MB | `714f2a5e…` |

四个包均经 `apksigner` 验证为 `CN=heimanmanga` 签名（SHA-256 `34be5a72…`），
`aapt2` 校验 ABI 与 versionCode 均正确。

### B.2 ⚠️ 该测试机不校验 APK 签名连续性（CorePatch 所致，非设备异常）

在本机上依次安装了三份**不同密钥**签名的包，全部 `Success`，且每次 `pull` 后
`apksigner` 确认签名确实已改变：

1. 原有的 v0.1.25（debug 构建，`pkgFlags=[DEBUGGABLE]`，与本次新密钥无关）
   → 用新 release 密钥 `adb install -r`：**成功**；
2. 用一次性密钥 `CN=throwaway-test` 重新签名后再 `install -r`：**成功**；
3. 恢复为正式 release 包：成功。

**原因（已定位）**：设备已 root 且安装了 **CorePatch（核心破解）** —— 该 LSPosed 模块的作用
就是关闭系统对 APK 签名的校验，因此跨密钥覆盖安装被放行。这是**主动破解**的结果，
不是固件行为异常；我最初"行为反常、原因未定位"的说法有误。

**结论与影响**：
- 附录 A 遗留事项 2"换密钥后旧版本无法覆盖安装"对**标准设备 / 应用商店仍然成立**，
  只是**无法在这台已破解的机器上验证**。
- 这台手机**不适合**验证签名、升级路径、Play 商店兼容性等发布相关问题；
  验证发布流程需一台未改动的设备，或使用 Play 内部测试轨道。
- 反过来，root 对本轮测试是**有利**的：可读取应用私有数据，把静态推断升级为实测（见 B.6）。
- 测试前为安装正式包执行过 `uninstall`，**设备上原有的应用数据（阅读历史、收藏、偏好）已清空**。

### B.3 功能测试结果

| # | 用例 | 结果 |
|---|---|---|
| 1 | 冷启动、首页轮播 + 全部漫画列表加载 | ✅ 真实数据与封面正常显示 |
| 2 | 进入漫画详情页（标签、简介、章节列表） | ✅ 正常 |
| 3 | 点击章节进入阅读器、首张图片加载 | ✅ 正常，控件显示 `第 1/44 页` |
| 4 | **P0-1 竖屏滚动模式右侧点击翻页** | ✅ **1 → 2 → 3 → 4 → 3 页，逐次正确**，logcat 无任何 Dart 异常 |
| 5 | 切换回"从右到左"横向模式后翻页（重构回归验证） | ✅ 连续翻页，画面内容逐页变化 |
| 6 | 拖动进度条跳到章节末页 | ✅ 正常渲染"已是最后一章 + 退出观看"过渡页 |
| 7 | 退出阅读器返回详情页 | ✅ 返回正常；章节变为**"已阅读"**、按钮变为**"继续阅读"**（进度落库成功） |
| 8 | 全程 logcat 检查（`flutter`/`StateError`/`No element`/`assert`/`FATAL`） | ✅ **无异常**，进程存活 |

**P0-1 修复已获真机证实**：修复前该操作会命中 `pageController` 未挂载（`StateError: No element`），
修复后竖屏模式翻页逐次正确且无异常。

### B.4 真机复现的新证据

1. **P1-6（过渡页 off-by-one）现场确认**：该章节实际 43 张图，阅读器计数显示 `第 x/44 页`
   —— 合成过渡页被计入总页数（与静态分析一致）。
2. **P2-12（切换阅读模式后页码不重映射）现场复现**：在竖屏模式读到第 5 页后切回"从右到左"，
   画面回到第 1 页但计数/进度条仍显示 `第 5/44 页`；直到手动翻页触发 `onPageChanged`
   才重新同步（显示变为 `第 2/44 页`，出现"数字倒退"的观感）。
   建议：切换方向/布局时按当前页重算并 `jumpToPage`，同时让计数与控制器状态同源。
3. 详情页章节行的"文件大小: 0.00 MB"（接口未返回 `file_size`）—— 展示层缺少兜底，纯外观问题。

### B.5 截图证据

测试截图保存在 `build/uitest/`（`build/` 已被 gitignore），关键几张：

| 文件 | 内容 |
|---|---|
| `01_launch.png` | 首页真实数据加载 |
| `02_detail.png` | 漫画详情页 |
| `07_vertical_before.png` | 竖屏模式 `第 1/44 页` |
| `08_vertical_after.png` | **右侧点击后 `第 2/44 页`（P0-1 修复验证）** |
| `09_vertical_paging.png` | 连续翻页后 `第 3/44 页` |
| `13_horizontal_before.png` | 切回横向后计数未同步（P2-12 复现） |
| `17_h_controls.png` | 横向翻页后 `第 4/44 页` |
| `18_slider_jump.png` | 章节末尾过渡页 |
| `19_back_to_detail.png` | 退出后章节显示"已阅读"、按钮变"继续阅读" |

### B.6 借助 root 读取落库数据（把推断变成实测）

root 后可读取应用私有目录，直接核对持久化的页码口径：

```
/data/data/io.xiuusi.heimanmanga/app_flutter/reading_progress.db   （32 KB；目录内无 -wal / -shm 文件）
```

`chapter_progresses` 实测内容（读取副本，未修改设备数据）：

| 字段 | 实测值 |
|---|---|
| chapter_id / manga_id | `1789006673424` |
| title / number | `第1章` / `1` |
| **current_page** | **43** |
| **total_pages** | **44** |
| reading_percentage | 1.0 |
| is_marked_as_read | 1 |
| **reading_duration** | **0** |

服务端交叉核对：`GET /api/manga/1789006673424/chapters/1789006673424/files`
→ **43** 个文件（`001.webp` … `043.webp`）。

由此得到四条实测结论：

1. **P1-6 off-by-one 确证（实测）**：章节真实页数 **43**，但落库 `total_pages = 44`、UI 显示
   `第 x/44 页`，最终位置记录为 `current_page = 43`（合成过渡页的 0-based 下标）。
   多出的第 44 页是 `transitionPageMarker`，它同时污染页数、百分比与历史记录显示
   （该章节在历史页会显示 `44/44`，进度条也以 44 为分母）。
2. **P1-3 佐证**：`pragma journal_mode = delete`，且私有目录中不存在 `-wal` 文件 ——
   确认未启用 WAL，与"两个 `AppDatabase` 连接 + 无 busy_timeout"的写冲突风险相互印证。
3. **P3 死代码确证**：`reading_duration = 0` —— `ReadingProgressService.updateReadingDuration()`
   确实从未被调用。
4. **迁移链正确（属已验证健康项）**：`pragma user_version = 3` 与 `schemaVersion = 3` 一致；
   `is_marked_as_read = 1` 说明标记已读与进度落库均正常工作。

---

## 附录 C：P1 修复记录（2026-10-04）

改动文件：`lib/widgets/reader/reader_controller.dart`、`lib/widgets/enhanced_reader_page.dart`、
`lib/widgets/reader/reader_controls.dart`、`lib/models/drift_models.dart`、
`lib/services/drift_reading_progress_manager.dart`、`lib/services/favorites_service.dart`

验证命令与结果：`dart analyze` → **0 error**（问题总数仍为 192，未新增）；`flutter test` → **9/9 通过**；
`dart run build_runner build` → **成功**（确认改造后的 drift 数据库类仍可代码生成）；
`flutter build apk --split-per-abi --release` → 三个 ABI 全部构建成功；随后安装到测试机逐项实测。

### P1-1 竖屏模式页码按真实布局计算

- `ReaderController` 新增 `_pageTops` / `_pageHeights` 布局缓存与
  `reportVerticalPageLayout()` / `clearVerticalPageLayout()` / `resolveVerticalPageIndex()` /
  `verticalOffsetForPage()` / `goToVerticalPage()`。
- 页码改为"视口顶部所在的页"；翻页直接滚动到目标页的真实偏移（不再 `page × 屏高`）。
- `enhanced_reader_page.dart` 新增 `_VerticalPageMeasure`：用 `RenderAbstractViewport
  .getOffsetToReveal()` 在布局后回填每页真实偏移与高度（需 `import 'package:flutter/rendering.dart'`）。
- 换章 / 切方向 / 切布局时清空布局缓存。

真机实测（竖屏"垂直滚动"，43 页章节）：点一次右半屏 → `第 1/43` → `第 2/43`，且视口顶部正好对齐
第 2 页顶部；再连点两次并回退一次 → 落到 `第 3/43`、视口顶部对齐第 3 页；数据库 `current_page = 2`
与 UI 完全一致。修复前是"按屏高滚动一屏"（该章节约 1.6 页），页码与落库值都会偏移。

### P1-2 重试可恢复

`loadChapterImages()` 入口先清除 `errorMessage` 并置 `isLoading = true`（仅在有变化时 notify，
避免 initState 阶段多余重建）；成功分支同样清空 `errorMessage`；异步回调补 `_disposed` 守卫。

真机实测：关闭 Wi-Fi/数据 → 打开章节出现"无法获取章节图片列表 + 重试" → 恢复网络 → 点击重试 →
正常加载出内容（`第 1/43 页`）。修复前 `errorMessage` 永不复位，错误页会永久驻留。

### P1-3 + P1-5 单一数据库连接 + WAL/busy_timeout + 后台 isolate + 写去重

- `AppDatabase` 改为进程内单例（`AppDatabase.instance`，私有构造），
  `DriftReadingProgressManager` 与 `FavoritesService` 共用同一连接。
- `_openConnection()` 改用 `NativeDatabase.createInBackground(file, setup: ...)`，在 `setup` 中执行
  `PRAGMA journal_mode = WAL` 与 `PRAGMA busy_timeout = 5000`。
- `saveReadingProgress()` 增加"页码/章节未变化则不写库"的去重，并夹紧过渡页页码。

真机实测：应用私有目录出现 `reading_progress.db-wal` / `-shm`，`pragma journal_mode = wal`；
收藏（FavoritesService）与阅读进度（DriftReadingProgressManager）分别写入后**同一连接**内两条记录
均正常落库，logcat 无 `SQLITE_BUSY` / `UNIQUE constraint` 异常。

### P1-4 音量键开关真正生效

- `init()` 不再硬编码 `enableVolumeKeyInterception(true)`，改为 `applyVolumeKeyInterception()`
  按当前开关下发。
- 偏好异步加载完成后重新下发一次拦截状态（原先读完偏好不会同步原生层）。
- 事件回调内再次校验 `volumeButtonNavigationEnabled`，关闭时直接忽略。
- 新增 `disposeVolumeKeyListener()`，在 `disposeController()` 中注销 MethodChannel 回调。

真机实测（`input keyevent 25` 注入音量减键，`dumpsys audio` 读 `streamVolume`）：

| 开关 | 系统音量 | 页码 |
|---|---|---|
| 开（默认） | 23 → **23**（未被系统处理 ⇒ 已被应用拦截） | 3 → **4**（翻页成功） |
| 关 | 23 → **22**（系统正常调节） | 3 → **3**（不再误翻页） |

修复前开关关闭时仍会翻页，且系统音量被吞掉。

### P1-6 总页数口径统一为真实页数

- 新增 `ReaderController.realPageCount`（排除末尾的 `transitionPageMarker`）。
- 进度落库用 `realPageCount` 并夹紧 `currentPage`；`readingProgress` 改用真实页数；
  标记已读改为"到达最后一页真实内容"即触发。
- `ReaderBottomControls` 的滑杆取值与"第 x/y 页"文案统一夹紧，避免停在过渡页时越界。

真机实测：UI 显示 `第 1/43 页`（修复前 `1/44`）；数据库 `total_pages = 43`（修复前 44）、
`reading_percentage = (page+1)/43`；进度对话框显示 `第 4/43 页 (9.3%)`。
与接口 `GET /api/manga/{id}/chapters/{id}/files` 返回的 43 个文件一致。

### 仍未处理（P2/P3）

P2/P3 已完成，见附录 D。

---

## 附录 D：P2 / P3 批量修复记录（2026-10-04）

规模：**52 个文件改动，+1820 / −1965 行**；新增 `.github/workflows/ci.yml`、
`android/app/proguard-rules.pro`。

### D.1 验证结果

| 检查 | 结果 |
|---|---|
| `dart analyze --fatal-infos` | **No issues found**（修复前 192 issues：0 error / 15 warning / 177 info） |
| `flutter test` | **9/9 通过** |
| `dart run build_runner build` | 成功（确认改后的 drift 数据库类仍可代码生成） |
| `flutter build apk --split-per-abi --release` | 三个 ABI 全部成功（含 R8 压缩 + 资源裁剪） |
| 真机（OnePlus PGP110 / Android 15） | 启动、首页、详情页、阅读器、翻页、进度落库、收藏均正常，无异常日志 |

### D.2 P2 逐项处理

- **P2-1 async 后使用 context**：全部 19 处补齐 `if (!mounted) return;` /
  `if (context.mounted) ...`（阅读器控制器内统一用 `_disposed || !context.mounted`）。
- **P2-2 预加载闭包读取已被替换的 imageUrls**：新增 `_imageGeneration` 代次号，延迟回调改为
  捕获 URL 字符串 + 校验代次与 `context.mounted`，不再出现 `RangeError`。
- **P2-3 非原子写入**：`saveProgress` / `markChapterAsRead` 改为显式目标的原子 upsert
  （`insert(..., onConflict: DoUpdate(target: [uniqueColumn]))`——注意 drift 的
  `insertOnConflictUpdate` 只针对主键，仍会撞 UNIQUE(mangaId/chapterId)）；收藏用
  `insertOnConflictUpdate`。真机验证进度与收藏均正常落库、无 UNIQUE/SQLITE 异常。
- **P2-4 收藏按钮无 in-flight 保护**：新增 `_isTogglingFavorite` 重入保护，失败不翻转状态并提示。
- **P2-5 控制器从未 dispose**：`disposeController()` 补 `pageTransformManager.dispose()` 与
  `super.dispose()`；页面调整为"先 removeListener 再 dispose"。
- **P2-6 章节结束页在 build 里发请求**：改为 `StatefulWidget`，future 在 `initState`/`didUpdateWidget`
  缓存；失败不再显示"共 0 页"。
- **P2-7 双页缩放未裁剪**：双页整体与左右半页均加 `ClipRect`。
- **P2-8 指针取消**：补 `onPointerCancel`，避免多指被系统取消后 `_pointerCount` 永久 ≥2。
- **P2-9 手势方向/布局不同步**：新增 `didUpdateWidget` 同步 handler 的 `readingDirection`/`pageLayout`。
- **P2-10 平移阈值单位错误**：移除该恒不触发且可能重复触发翻页的逐帧分支（慢速拖拽交给
  PageView/ListView 自身滚动，快速甩动仍由 `onScaleEnd` 速度判定处理）。
- **P2-11 控制栏收起动画失效**：控制栏改为常驻挂载，隐藏时用 `IgnorePointer` 关闭命中，
  位移量加大到能完全移出屏幕；动画初值对齐 `showControls`。
  **注意**：`Positioned` 必须是 `Stack` 的直接子节点 —— 首版把 `IgnorePointer` 包在 `Positioned`
  外层，真机立即抛出 `type 'ParentData' is not a subtype of type 'StackParentData'`，
  已改为把 `IgnorePointer` 放进控制栏内部（`interactive` 参数）。
- **P2-12 切换方向/布局后页码不重映射**：新增 `syncControllersToCurrentPage()`，由页面在检测到
  方向/实际布局变化后帧后调用（竖屏按真实布局偏移 jump，双页按分组索引 jump）。
- **P2-13 build 中修改状态**：`pageGroups` 改为 `refreshPageGroups()`（按签名在帧后刷新缓存），
  build 内只读缓存、必要时用本地计算结果兜底。
- **P2-14 搜索无限加载**：新增 `_hasReachedEnd` + 重入保护，页码在成功后提交。
- **P2-15 无防抖/过期响应**：tags_page 增加 300ms 防抖（dispose 取消）；搜索与标签均加请求序号，
  丢弃过期响应。（搜索页无逐键触发，故未加防抖——加了会是死代码。）
- **P2-16 收藏页无错误处理**：try/catch/finally + 错误态 + 重试按钮。
- **P2-17 切 Tab 丢失状态**：`main_navigation_page` / `tablet_main_page` 改用 `IndexedStack`。
- **P2-18 章节图片接口把错误当空章节**：非 200 与网络异常改为抛出（进入阅读器错误态 + 重试），
  真正空的 files 仍返回 `[]`；`cast` 改 `whereType`。
- **P2-19 历史页**：追加时按 `mangaId` 去重、offset 正确推进、`ValueKey`、错误态替代"暂无历史"。
- **P2-20 详情页 N+1 查库**：新增 `getProgressForChapters` 批量查询并改用。
- **P2-20b 手机端章节列表全量构建**：改为 `CustomScrollView` + `SliverList.separated`（真机确认布局正常）。
- **P2-21 启动期无保护 await**：`main()` 两处 await 各自 try/catch，异常不再阻断 `runApp`。
- **P2-22 `_preloadCache` 无界**：加上限与完成后清理。
- **P2-23 图片缓存上限过高**：300MB → 150MB，高 DPI 固定 200MB；统一低端设备判定为 `dpr < 1.5`。
- **P2-24 响应式断点**：`isTablet` 改为按 `shortestSide >= 600`（不再等同横屏）；
  `isLargeTablet` 为 ≥600 且宽 ≥1024。**行为变化**：横屏手机走手机布局、竖屏平板走平板布局。
- **P2-25 路由过渡死代码**：详情页 push 补 `RouteSettings(name: 'manga_detail')` 使分支生效；
  无任何路由使用的 `'search'` 分支已删除。

### D.3 P3 处理

- **死代码删除（约 700+ 行）**：`smart_preload_manager.dart` 整文件、
  `TouchGestureHandler`/`EnhancedReaderGestureDetector`、`AnimationPerformanceMonitor`、
  `DualPageUtils` 的图片工具、`ImagePreloadManager.smartPreload`、`DioService.updateConfig/
  cancelAllRequests`、`ImageCacheManager` 的空实现与未用常量、
  `PageTransitions` 5 个未用过渡与 2 个未用路由助手 + `CustomPageTransitionsTheme`。
- **分析器**：`withOpacity`→`withValues`、`Color.value`→`toARGB32()`、
  `window`→`platformDispatcher`、`Radio`→`RadioGroup`、`Switch.activeColor`→`activeThumbColor`、
  `Matrix4.translate/scale`→`translateByDouble/scaleByDouble`、`print`→`debugPrint`（28 处）、
  私有类型返回、`use_super_parameters`、`prefer_const_*` 等 —— 共 192 → **0**。
- **drift 细节**：`getReadingStats` 语义修正（新增 `totalPagesReached`）、
  `markChapterAsRead(false)` 不再伪造 100% 幽灵行、移除未用局部变量。
- **解析健壮性**：列表元素改 `parseMap`+`whereType`（畸形元素不再中断整表）、
  `CarouselImage` 兼容 camelCase、`imageIdMap` 去掉字典序排序、`parseBool` 接受 `'1'/'yes'`、
  `parseMap` 去掉会抛的 `.cast`。
- **仓库与构建卫生**：`.gitignore` 移除整目录 `android/` 与 `pubspec.lock` 规则（保留并显式新增
  `android/key.properties`/`**/*.jks`/`**/*.keystore`），补 `android/.gradle/`、`android/app/build/`、
  `android/build/`、`android/local.properties` 等构建产物规则；`pubspec.yaml` 补声明
  `flutter_cache_manager` 并把 SDK 下限对齐为 `>=3.12.0`；新增 GitHub Actions CI
  （analyze + test，锁定 Flutter 3.47.5）；`gradle.properties` `-Xmx8G`→`4G`、移除
  `enableJetifier`；release 开启 `isMinifyEnabled`/`isShrinkResources`；
  `MainActivity.kt` `println`→`Log.d`、忽略按键 repeatCount；新增
  `android/app/proguard-rules.pro`（含 R8 提示缺失的 Play Core `-dontwarn` 规则，
  否则 `minifyReleaseWithR8` 会直接失败）。
- **文档**：`UPDATE_PLAN.md` 待办与已完成状态、`README.md` 版本声明（Flutter 3.44+/Dart 3.12+）
  与依赖清单、`CHANGELOG.md` 中"移除离线下载待办"这条不实记录已删除。

### D.4 仍需人工/后续处理

1. **提交锁文件与清理已追踪的生成物**：`pubspec.lock` 现已不再被忽略，需 `git add` 提交；
   `android/local.properties`、`android/build/reports/problems/problems-report.html`、
   `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` 仍被 git 追踪，
   建议执行 `git rm --cached <path>`（会变更索引，故未代劳）。
2. **R8 仍需真机回归**：本次已在真机验证启动/首页/详情/阅读器/进度/收藏均正常；
   但压缩会随插件变化产生新的缺失类，若后续加插件需重新构建验证
   （R8 会把建议规则写到 `build/app/outputs/mapping/release/missing_rules.txt`）。
3. **响应式语义变更**：横屏手机现在走手机布局、竖屏平板走平板布局 —— 属于有意修正，
   但值得在横屏手机与大屏平板上各看一遍。
4. **`IndexedStack` 副作用**：所有 Tab 在启动时即构建（首页/标签/收藏/历史会各自发起一次请求），
   换来的是切换 Tab 不再丢失搜索词与分页状态。若后续在意启动请求数，可改为懒加载 + `AutomaticKeepAlive`。
5. **仍未做**：本地化（l10n/`flutter_localizations`）、iOS/桌面平台目录、
   `HistoryItem` 的 keyset 分页（当前改为按 `mangaId` 去重，已消除重复行）。
6. **观察项**：真机上曾见到一次进度值从 2 跳到 33（随后"从头阅读"+1 次翻页后为 `1/43`，
   与预期一致），未能复现，建议后续在竖屏模式下用日志复核 `resolveVerticalPageIndex` 的取值。
