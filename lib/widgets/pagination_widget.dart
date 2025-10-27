import 'package:flutter/material.dart';

/// 通用分页组件
class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final String itemName;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    this.itemName = '本',
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 页码信息
          Text(
            '第 $currentPage / $totalPages 页 (共 $totalItems $itemName)',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 12),

          // 分页按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一页按钮
              IconButton(
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
                color: currentPage > 1 ? const Color(0xFFFF6B6B) : Colors.grey,
              ),

              // 页码按钮
              _buildPageButtons(currentPage, totalPages, onPageChanged),

              // 下一页按钮
              IconButton(
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right),
                color: currentPage < totalPages ? const Color(0xFFFF6B6B) : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建页码按钮
  Widget _buildPageButtons(int currentPage, int totalPages, ValueChanged<int> onPageChanged) {
    List<Widget> buttons = [];

    // 计算显示的页码范围
    int startPage = (currentPage - 2).clamp(1, totalPages);
    int endPage = (currentPage + 2).clamp(1, totalPages);

    // 确保至少显示5个页码（如果总页数允许）
    if (endPage - startPage < 4) {
      if (startPage == 1) {
        endPage = (startPage + 4).clamp(1, totalPages);
      } else if (endPage == totalPages) {
        startPage = (endPage - 4).clamp(1, totalPages);
      }
    }

    // 添加第一页
    if (startPage > 1) {
      buttons.add(_buildPageButton(1, currentPage, onPageChanged));
      if (startPage > 2) {
        buttons.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      }
    }

    // 添加中间页码
    for (int i = startPage; i <= endPage; i++) {
      buttons.add(_buildPageButton(i, currentPage, onPageChanged));
    }

    // 添加最后一页
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        buttons.add(const Text(' ... ', style: TextStyle(color: Colors.grey)));
      }
      buttons.add(_buildPageButton(totalPages, currentPage, onPageChanged));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }

  /// 构建单个页码按钮
  Widget _buildPageButton(int pageNumber, int currentPage, ValueChanged<int> onPageChanged) {
    final isActive = pageNumber == currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onPageChanged(pageNumber),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF6B6B) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? const Color(0xFFFF6B6B) : Colors.grey[300]!,
            ),
          ),
          child: Text(
            '$pageNumber',
            style: TextStyle(
              color: isActive ? Colors.white : (pageNumber == currentPage ? const Color(0xFFFF6B6B) : Colors.black87),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}