import 'package:flutter/material.dart';
import '../../utils/reader_gestures.dart';
import '../../utils/dual_page_utils.dart';
import 'reader_controller.dart';

class ReaderSettingsPanel extends StatelessWidget {
  final ReaderController controller;
  final AnimationController animationController;

  const ReaderSettingsPanel({
    Key? key,
    required this.controller,
    required this.animationController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Positioned(
          left: -400 * (1 - animationController.value),
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(242),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '阅读设置',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => animationController.reverse(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '阅读',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _buildReadingDirectionOption(context, '从左到右', ReadingDirection.leftToRight),
                        const SizedBox(height: 8),
                        _buildReadingDirectionOption(context, '从右到左', ReadingDirection.rightToLeft),
                        const SizedBox(height: 8),
                        _buildReadingDirectionOption(context, '垂直滚动', ReadingDirection.vertical),
                        const SizedBox(height: 8),
                        _buildReadingDirectionOption(context, '网漫模式', ReadingDirection.webtoon),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '双页阅读',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _buildPageLayoutOption(context, '单页模式', PageLayout.single),
                        const SizedBox(height: 8),
                        _buildPageLayoutOption(context, '双页模式', PageLayout.double),
                        const SizedBox(height: 8),
                        _buildPageLayoutOption(context, '自动模式', PageLayout.auto),
                        const SizedBox(height: 12),
                        _buildToggleOption(
                          '启用页面移位',
                          controller.dualPageConfig.shiftDoublePage,
                          (value) {
                            controller.dualPageConfig.shiftDoublePage = value;
                            controller.notifyExternal();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingDirectionOption(BuildContext context, String title, ReadingDirection direction) {
    final isSelected = controller.readingDirection == direction;

    return GestureDetector(
      onTap: () {
        controller.setReadingDirection(direction);
        HapticFeedbackManager.lightImpact();
        controller.showSnackBar(context, '已切换到$title');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B6B).withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[500],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageLayoutOption(BuildContext context, String title, PageLayout layout) {
    final isSelected = controller.dualPageConfig.pageLayout == layout;

    return GestureDetector(
      onTap: () {
        controller.dualPageConfig.pageLayout = layout;
        controller.notifyExternal();
        HapticFeedbackManager.lightImpact();
        controller.showSnackBar(context, '已切换到$title');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B6B).withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[500],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFFF6B6B).withAlpha(128),
            activeThumbColor: const Color(0xFFFF6B6B),
          ),
        ],
      ),
    );
  }
}
