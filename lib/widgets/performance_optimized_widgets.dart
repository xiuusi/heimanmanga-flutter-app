import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cache_manager.dart';

// 性能优化的图片组件
class OptimizedCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableFadeIn;
  final Duration fadeInDuration;
  final bool enableProgressIndicator;

  const OptimizedCachedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.enableFadeIn = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableProgressIndicator = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : null,
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : null,
      fadeInDuration: enableFadeIn ? fadeInDuration : Duration.zero,
      progressIndicatorBuilder: enableProgressIndicator
          ? (context, url, progress) => Center(
                child: CircularProgressIndicator(
                  value: progress.progress,
                ),
              )
          : null,
    );
  }
}