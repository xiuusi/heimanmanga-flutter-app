import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'manga_detail_page.dart';

class CarouselWidgetKey extends GlobalKey<CarouselWidgetState> {
  const CarouselWidgetKey() : super.constructor();
}

class CarouselWidget extends StatefulWidget {
  const CarouselWidget({Key? key}) : super(key: key);

  @override
  State<CarouselWidget> createState() => CarouselWidgetState();
}

class CarouselWidgetState extends State<CarouselWidget> {
  PageController? _pageController;
  int _currentIndex = 0;
  List<CarouselImage> _carouselImages = [];
  bool _isLoading = true;
  Timer? _timer;
  
  double _currentViewportFraction = 0.85;

  @override
  void initState() {
    super.initState();
    _loadCarouselData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initOrUpdateController();
  }

  void _initOrUpdateController() {
    final width = MediaQuery.of(context).size.width;
    
    double newFraction;
    if (width >= 1200) {
      newFraction = 0.6; 
    } else if (width >= 800) {
      newFraction = 0.7;
    } else {
      newFraction = 0.9;
    }

    if (_pageController == null || _currentViewportFraction != newFraction) {
      _currentViewportFraction = newFraction;
      
      int initialPage = _currentIndex;
      if (_pageController != null) {
        _pageController!.dispose();
      }

      _pageController = PageController(
        viewportFraction: _currentViewportFraction, 
        initialPage: initialPage
      );
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _stopAutoPlay();
    super.dispose();
  }

  Future<void> _loadCarouselData() async {
    try {
      final response = await MangaApiService.getCarouselImages(page: 1, limit: 5);
      if (mounted) {
        setState(() {
          _carouselImages = response.data.take(5).toList();
          _isLoading = false;
        });
        _startAutoPlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> reloadCarouselData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentIndex = 0;
    });
    _stopAutoPlay();
    
    if (_pageController != null) {
       _pageController!.jumpToPage(0);
    }
    
    await _loadCarouselData();
  }

  void _startAutoPlay() {
    if (_carouselImages.length <= 1) return;
    _stopAutoPlay();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _goToNextPage();
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
  }

  void _goToNextPage() {
    if (_pageController != null && _pageController!.hasClients) {
      int nextPage = _currentIndex + 1;
      if (nextPage >= _carouselImages.length) {
        _pageController!.animateToPage(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      } else {
        _pageController!.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    }
  }

  void _goToPrevPage() {
    if (_pageController != null && _pageController!.hasClients) {
      int prevPage = _currentIndex - 1;
      if (prevPage < 0) {
        _pageController!.animateToPage(
          _carouselImages.length - 1,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      } else {
        _pageController!.previousPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 800;
    
    // --- 调整点 1: 高度大幅减小，且基于屏幕高度百分比 ---
    double carouselHeight;
    if (isDesktop) {
      // 桌面端：取屏幕高度的 30%，但限制在 [200, 320] 之间
      // 这样既符合 "30%" 的直觉，又不会在超大屏上过高，也不会在笔记本上过矮
      carouselHeight = (screenHeight * 0.3).clamp(230.0, 350.0);
    } else {
      // 手机端：固定更小的高度
      carouselHeight = 230.0;
    }

    if (_isLoading) return _buildLoadingState(carouselHeight);
    if (_carouselImages.isEmpty) return _buildEmptyState(carouselHeight);

    return Column(
      children: [
        SizedBox(
          height: carouselHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 主体
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _carouselImages.length,
                    clipBehavior: Clip.none,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      _stopAutoPlay();
                      _startAutoPlay();
                    },
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController!,
                        builder: (context, child) {
                          double page = 0;
                          try {
                            page = _pageController!.page ?? index.toDouble();
                          } catch (_) {
                            page = index.toDouble();
                          }
                          
                          double value = page - index;
                          double scaleBase = isDesktop ? 0.9 : 0.9; 
                          double scale = (1 - (value.abs() * (1 - scaleBase))).clamp(scaleBase, 1.0);
                          double parallaxOffset = value * (isDesktop ? 60 : 40);
                          double opacity = isDesktop 
                              ? (1 - (value.abs() * 0.3)).clamp(0.5, 1.0) 
                              : 1.0;

                          return Center(
                            child: SizedBox(
                              height: scale * carouselHeight, 
                              width: double.infinity,
                              child: Opacity(
                                opacity: opacity,
                                child: _buildParallaxCard(
                                  _carouselImages[index], 
                                  parallaxOffset,
                                  isDesktop,
                                  carouselHeight // 传入高度用于调整字体大小
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // 按钮 (稍微调小一点)
              if (isDesktop)
                Positioned(
                  left: 24,
                  child: _buildNavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      _stopAutoPlay();
                      _goToPrevPage();
                      _startAutoPlay();
                    },
                  ),
                ),

              if (isDesktop)
                Positioned(
                  right: 24,
                  child: _buildNavButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    onTap: () {
                      _stopAutoPlay();
                      _goToNextPage();
                      _startAutoPlay();
                    },
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 12), // 间距减小
        _buildModernIndicators(),
      ],
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.3),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFFF6B6B).withOpacity(0.8),
        child: Container(
          width: 40, // 按钮从 48 改为 40
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20), // 图标缩小
        ),
      ),
    );
  }

  Widget _buildParallaxCard(CarouselImage image, double offsetX, bool isDesktop, double currentHeight) {
    // --- 调整点 2: 根据卡片高度动态调整字体大小 ---
    // 如果卡片高度只有 200，字体太大就挡住画面了
    final titleFontSize = isDesktop 
        ? (currentHeight * 0.08).clamp(16.0, 24.0) // 动态字体
        : 16.0;

    return GestureDetector(
      onTap: () => _handleCarouselTap(context, image.linkUrl),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12), // 圆角稍微减小
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: isDesktop ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(offsetX, 0),
                  child: Transform.scale(
                    scale: 1.1,
                    child: CachedNetworkImage(
                      imageUrl: MangaApiService.getCarouselImageUrl(image.id),
                      fit: BoxFit.cover,
                      // --- 调整点 3: 减小缓存图片尺寸，节省内存 ---
                      memCacheHeight: isDesktop ? 500 : 300,
                      placeholder: (context, url) => Container(color: Colors.grey[800]),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                      httpHeaders: MangaApiService.userAgent.isNotEmpty
                          ? {'User-Agent': MangaApiService.userAgent}
                          : null,
                    ),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.5, 0.75, 1.0],
                    ),
                  ),
                ),

                Positioned(
                  bottom: isDesktop ? 20 : 12,
                  left: isDesktop ? 20 : 12,
                  right: isDesktop ? 20 : 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize, // 使用调整后的字体大小
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black.withOpacity(0.8), offset: const Offset(0, 1))
                          ]
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernIndicators() {
    if (_carouselImages.length <= 1) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_carouselImages.length, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 6, // 指示器稍微变小
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF6B6B) : Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState(double height) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B))),
      ),
    );
  }

  Widget _buildEmptyState(double height) {
    return Container(
      height: height,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[700]),
            const Text('暂无推荐内容', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _handleCarouselTap(BuildContext context, String linkUrl) async {
    if (!mounted) return;
    try {
      final uri = Uri.parse(linkUrl);
      if (_isMangaDetailLink(uri)) {
        final mangaId = uri.queryParameters['id'];
        if (mangaId == null) {
          _showErrorSnackBar(context, '无效的漫画链接格式');
          return;
        }
        _navigateToMangaDetail(mangaId); 
      } else {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(context, '处理链接失败: $e');
    }
  }

  Future<void> _navigateToMangaDetail(String mangaId) async {
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B))),
      ),
    );

    try {
      final manga = await MangaApiService.getMangaById(mangaId);
      if(!mounted) return;
      Navigator.of(context).pop();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MangaDetailPage(manga: manga)),
      );
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) _showErrorSnackBar(context, '加载漫画详情失败: $e');
    }
  }

  bool _isMangaDetailLink(Uri uri) {
     final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final supportedHosts = ['www.heiman.cc', 'localhost', '127.0.0.1'];
    final supportedPaths = ['/manga-detail.html', '/manga/detail'];
    final hasMangaId = uri.queryParameters.containsKey('id');
    return supportedHosts.contains(host) && 
           supportedPaths.any((pattern) => path.contains(pattern)) && 
           hasMangaId;
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}