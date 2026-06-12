import 'package:nook/features/crawl/data/models/crawl_detail_model.dart';
import 'package:nook/features/crawl/data/models/crawl_model.dart';
import 'package:nook/features/crawl/data/models/crawl_share_card_model.dart';
import 'package:nook/features/crawl/data/models/stamp_claim_result_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ICrawlRemoteDataSource {
  Future<List<CrawlModel>> getActiveCrawls();

  Future<CrawlDetailModel> getCrawlBySlug(String slug, String? userId);

  Future<void> registerForCrawl(String crawlId);

  Future<StampClaimResultModel> claimStamp({
    required String crawlId,
    required String stopId,
    required double lat,
    required double lng,
  });

  Future<CrawlShareCardModel> getShareCardData(String crawlId, String? userId);
}

class CrawlRemoteDataSourceImpl implements ICrawlRemoteDataSource {
  final SupabaseClient supabase;

  CrawlRemoteDataSourceImpl(this.supabase);

  @override
  Future<List<CrawlModel>> getActiveCrawls() async {
    try {
      final response = await supabase
          .from('crawls')
          .select()
          .eq('status', 'active')
          .order('starts_at', ascending: true);

      return (response as List)
          .whereType<Map>()
          .map((item) => CrawlModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on PostgrestException catch (e, st) {
      throw CrawlDataSourceException(
        'Failed to fetch active crawls.',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CrawlDataSourceException) rethrow;
      throw CrawlDataSourceException(
        'Failed to fetch active crawls.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<CrawlDetailModel> getCrawlBySlug(String slug, String? userId) async {
    try {
      final response = await supabase.rpc(
        'get_crawl_detail',
        params: {
          'p_slug': slug,
          'p_user_id': userId,
        },
      );

      if (response == null) {
        throw const CrawlNotFoundException('Crawl not found');
      }

      final json = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      return CrawlDetailModel.fromJson(json);
    } on CrawlNotFoundException {
      rethrow;
    } on PostgrestException catch (e, st) {
      throw CrawlDataSourceException(
        'Failed to fetch crawl detail for slug "$slug".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CrawlDataSourceException) rethrow;
      throw CrawlDataSourceException(
        'Failed to fetch crawl detail for slug "$slug".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> registerForCrawl(String crawlId) async {
    try {
      final userId = _resolveUserId();
      await supabase.from('crawl_registrations').insert({
        'crawl_id': crawlId,
        'user_id': userId,
      });
    } on PostgrestException catch (e, st) {
      if (e.code == '23505') {
        throw const AlreadyRegisteredException();
      }
      throw CrawlDataSourceException(
        'Failed to register for crawl "$crawlId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CrawlDataSourceException || e is AlreadyRegisteredException) {
        rethrow;
      }
      throw CrawlDataSourceException(
        'Failed to register for crawl "$crawlId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<StampClaimResultModel> claimStamp({
    required String crawlId,
    required String stopId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await supabase.rpc(
        'claim_crawl_stamp',
        params: {
          'p_crawl_id': crawlId,
          'p_stop_id': stopId,
          'p_lat': lat,
          'p_lng': lng,
        },
      );

      final json = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      final error = json['error'] as String?;
      if (error != null) {
        switch (error) {
          case 'location_too_far':
            throw LocationTooFarException(
              _asInt(json['distance_meters']),
            );
          case 'already_claimed':
            throw AlreadyClaimedException(
              _asDateTime(json['claimed_at']),
            );
          case 'crawl_ended':
            throw const CrawlEndedException();
          case 'stop_inactive':
            throw const StopInactiveException();
          case 'stop_not_found':
            throw const StopNotFoundException();
          case 'not_registered':
            throw const NotRegisteredException();
          case 'not_authenticated':
            throw const NotAuthenticatedException();
          case 'crawl_not_found':
            throw CrawlNotFoundException('Crawl not found');
        }
        throw CrawlDataSourceException(
          'Unknown claim error: $error',
        );
      }

      return StampClaimResultModel.fromJson(json);
    } on LocationTooFarException {
      rethrow;
    } on AlreadyClaimedException {
      rethrow;
    } on CrawlEndedException {
      rethrow;
    } on StopInactiveException {
      rethrow;
    } on NotRegisteredException {
      rethrow;
    } on PostgrestException catch (e, st) {
      if (e.code == '23505') {
        throw const AlreadyClaimedException(null);
      }
      throw CrawlDataSourceException(
        'Failed to claim stamp for stop "$stopId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CrawlDataSourceException) rethrow;
      throw CrawlDataSourceException(
        'Failed to claim stamp for stop "$stopId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<CrawlShareCardModel> getShareCardData(
    String crawlId,
    String? userId,
  ) async {
    try {
      final response = await supabase.rpc(
        'get_crawl_share_card',
        params: {
          'p_crawl_id': crawlId,
          'p_user_id': userId,
        },
      );

      if (response == null) {
        throw const CrawlNotFoundException('Share card data not found');
      }

      final json = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      return CrawlShareCardModel.fromJson(json);
    } on CrawlNotFoundException {
      rethrow;
    } on PostgrestException catch (e, st) {
      throw CrawlDataSourceException(
        'Failed to fetch share card for crawl "$crawlId".',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is CrawlDataSourceException) rethrow;
      throw CrawlDataSourceException(
        'Failed to fetch share card for crawl "$crawlId".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  String _resolveUserId() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const CrawlDataSourceException('No authenticated user.');
    }
    return userId;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class CrawlDataSourceException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const CrawlDataSourceException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() =>
      'CrawlDataSourceException(message: $message, cause: $cause)';
}

class CrawlNotFoundException implements Exception {
  final String message;

  const CrawlNotFoundException(this.message);
}

class AlreadyRegisteredException implements Exception {
  const AlreadyRegisteredException();
}

class LocationTooFarException implements Exception {
  final int distanceMeters;

  const LocationTooFarException(this.distanceMeters);
}

class AlreadyClaimedException implements Exception {
  final DateTime? claimedAt;

  const AlreadyClaimedException(this.claimedAt);
}

class CrawlEndedException implements Exception {
  const CrawlEndedException();
}

class StopInactiveException implements Exception {
  const StopInactiveException();
}

class StopNotFoundException implements Exception {
  const StopNotFoundException();
}

class NotRegisteredException implements Exception {
  const NotRegisteredException();
}

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();
}
