import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager {
  CustomCacheManager._();

  static const String _key = 'cafe_image_cache';
  static const Duration _maxAge = Duration(days: 7);
  static const int _maxObjects = 150;

  static final CacheManager instance = CacheManager(
    Config(_key, stalePeriod: _maxAge, maxNrOfCacheObjects: _maxObjects),
  );
}
