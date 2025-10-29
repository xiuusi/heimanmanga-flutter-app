import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'manga_detail_page.dart';

class CarouselWidget extends StatefulWidget {
  const CarouselWidget({super.key});

  @override
  State<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentIndex = 0;
  List<CarouselImage> _carouselImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _loadCarouselData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCarouselData() async {
    try {
      // 获取轮播图数据，默认获取前5张
      final response = await MangaApiService.getCarouselImages(page: 1, limit: 5);
      setState(() {
        _carouselImages = response.data.take(5).toList();
        _isLoading = false;
      });
      _startAutoPlay();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startAutoPlay() {
    if (_carouselImages.length <= 1) return;

    _animationController.repeat().then((_) {
      if (mounted) {
        _nextPage();
      }
    });
  }

  void _stopAutoPlay() {
    _animationController.stop();
  }

  void _nextPage() {
    if (_currentIndex < _carouselImages.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _carouselImages.length - 1;
    }
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 200,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
            ),
          ),
        ),
      );
    }

    if (_carouselImages.isEmpty) {
      return SizedBox(
        height: 200,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Center(
            child: Text(
              '暂无轮播图内容',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // 轮播图主体
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _stopAutoPlay();
              _startAutoPlay();
            },
            itemCount: _carouselImages.length,
            itemBuilder: (context, index) {
              return _buildCarouselItem(_carouselImages[index], index);
            },
          ),

          // 左右切换按钮
          if (_carouselImages.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousPage,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextPage,
                  ),
                ),
              ),
            ),
          ],

          // 指示器
          if (_carouselImages.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _carouselImages.length,
                  (index) => _buildIndicator(index),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(CarouselImage carouselImage, int index) {
    final isActive = index == _currentIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isActive ? 0 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.3 : 0.1),
            blurRadius: isActive ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () {
            // 处理轮播图点击事件 - 改为内部跳转
            if (carouselImage.linkUrl.isNotEmpty) {
              _handleCarouselTap(context, carouselImage.linkUrl);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景图片
              CachedNetworkImage(
                imageUrl: MangaApiService.getCarouselImageUrl(carouselImage.id),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),

              // 渐变遮罩
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // 内容
              if (carouselImage.title.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        carouselImage.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

              // 如果有链接，显示链接指示器
              if (carouselImage.linkUrl.isNotEmpty)
                Positioned(
                  right: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.link,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final isActive = index == _currentIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // 处理轮播图点击事件
  void _handleCarouselTap(BuildContext context, String linkUrl) async {
    try {
      // 解析URL
      final uri = Uri.parse(linkUrl);
      
      // 检查是否是漫画详情链接格式
      if (_isMangaDetailLink(uri)) {
        // 漫画详情链接 - 内部跳转
        final mangaId = uri.queryParameters['id'];
        if (mangaId == null) {
          _showErrorSnackBar(context, '无效的漫画链接格式');
          return;
        }

        // 显示加载对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
            ),
          ),
        );

        try {
          // 获取漫画详情
          final manga = await MangaApiService.getMangaById(mangaId);
          
          // 关闭加载对话框
          Navigator.of(context).pop();

          // 跳转到漫画详情页
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MangaDetailPage(manga: manga),
            ),
          );
        } catch (e) {
          // 关闭加载对话框（如果存在）
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          _showErrorSnackBar(context, '加载漫画详情失败: $e');
        }
      } else {
        // 其他链接 - 外部浏览器打开
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar(context, '无法打开链接');
        }
      }

    } catch (e) {
      _showErrorSnackBar(context, '处理链接失败: $e');
    }
  }

  // 判断是否为漫画详情链接
  bool _isMangaDetailLink(Uri uri) {
    // 检查主机名和路径
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    
    // 支持的主机名（可以扩展）
    final supportedHosts = ['c.xiongouke.top', 'localhost', '127.0.0.1'];
    
    // 支持的路径模式（可以扩展）
    final supportedPaths = ['/manga-detail.html', '/manga/detail'];
    
    // 检查是否有漫画ID参数
    final hasMangaId = uri.queryParameters.containsKey('id');
    
    return supportedHosts.contains(host) && 
           supportedPaths.any((pattern) => path.contains(pattern)) && 
           hasMangaId;
  }

  // 显示错误提示
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
