import 'package:flutter/material.dart';

class ReaderTopControls extends StatelessWidget {
  final AnimationController animationController;
  final String mangaTitle;
  final String chapterInfo;
  final VoidCallback onBack;

  /// 控制栏隐藏时是否屏蔽命中测试（P2-11：控制栏改为常驻挂载后，
  /// 必须显式关闭命中，否则滑出屏幕的部分仍会拦截点击）。
  final bool interactive;

  const ReaderTopControls({
    super.key,
    required this.animationController,
    required this.mangaTitle,
    required this.chapterInfo,
    required this.onBack,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        // 注意：Positioned 必须是 Stack 的直接子节点，因此 IgnorePointer 只能
        // 包在 Positioned 的 child 里，不能包在 Positioned 外层。
        return Positioned(
          // 控制栏现在始终挂载（P2-11），位移量必须足以完全移出屏幕，
          // 否则动画值为 0 时顶部会残留一条可见边。
          top: -160 * (1 - animationController.value),
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !interactive,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(204), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mangaTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          chapterInfo,
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReaderBottomControls extends StatelessWidget {
  final AnimationController animationController;
  final int currentPage;
  final int totalPages;
  final ValueChanged<double> onPageSliderChanged;
  final VoidCallback onSettingsTap;

  /// 同 ReaderTopControls：隐藏时屏蔽命中测试（P2-11）。
  final bool interactive;

  const ReaderBottomControls({
    super.key,
    required this.animationController,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSliderChanged,
    required this.onSettingsTap,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // totalPages 是真实页数；停在章节结尾过渡页时 currentPage 可能等于它，
    // 因此滑杆取值与页码文案都要夹紧，避免越界（P1-6）。
    final safeTotal = totalPages < 1 ? 1 : totalPages;
    final sliderValue = currentPage.clamp(0, safeTotal - 1).toDouble();
    final displayPage = (currentPage + 1).clamp(1, safeTotal);
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        // Positioned 必须是 Stack 的直接子节点，IgnorePointer 只能放在其 child 内。
        return Positioned(
          // 同上（P2-11）：底部控制栏也必须能完全滑出屏幕。
          bottom: -220 * (1 - animationController.value),
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !interactive,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(204), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: primary,
                      inactiveTrackColor: Colors.grey[600],
                      thumbColor: primary,
                      overlayColor: primary.withAlpha(51),
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: sliderValue,
                      min: 0,
                      max: (safeTotal - 1).toDouble(),
                      onChanged: onPageSliderChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '第 $displayPage/$safeTotal 页',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                            ),
                            onPressed: onSettingsTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
