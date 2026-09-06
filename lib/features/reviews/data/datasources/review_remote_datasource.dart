import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_eligibility_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class ProductReviewsPayload {
  const ProductReviewsPayload({
    required this.reviews,
    required this.averageRating,
    required this.pagination,
  });

  final List<ReviewEntity> reviews;
  final double averageRating;
  final PaginationEntity pagination;
}

class MyReviewsPayload {
  const MyReviewsPayload({
    required this.reviews,
    required this.pagination,
  });

  final List<ReviewEntity> reviews;
  final PaginationEntity pagination;
}

class ReviewRemoteDataSource {
  const ReviewRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ProductReviewsPayload> getReviews({
    required String productId,
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.getProductReviews(productId, page, limit);
    final payload =
        _parsePayload(response.data, ApiConstants.reviewsForProduct(productId));
    final data = payload['data'];

    if (data is! Map) {
      throw _badResponse(ApiConstants.reviewsForProduct(productId), payload);
    }

    final map = Map<String, dynamic>.from(data);
    final reviewsRaw = map['reviews'];
    final reviews = reviewsRaw is List
        ? reviewsRaw
            .whereType<Map>()
            .map((item) => _parseReview(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <ReviewEntity>[];

    final averageRating =
        _toDouble(map['averageRating'] ?? map['average_rating']) ?? 0;
    final paginationRaw = map['pagination'] ?? payload['pagination'];
    final pagination = paginationRaw is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationRaw))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: reviews.length,
            totalPages: reviews.isEmpty ? 0 : 1,
          );

    return ProductReviewsPayload(
      reviews: reviews,
      averageRating: averageRating,
      pagination: pagination,
    );
  }

  Future<ReviewEligibilityEntity> checkEligibility(String productId) async {
    final response = await _apiClient.getReviewEligibility(productId);
    final payload =
        _parsePayload(response.data, ApiConstants.reviewEligibility(productId));
    final data = payload['data'];
    if (data is! Map) {
      throw _badResponse(ApiConstants.reviewEligibility(productId), payload);
    }

    final map = Map<String, dynamic>.from(data);
    final canReview = _toBool(map['canReview']) || _toBool(map['eligible']);
    final alreadyReviewed = _toBool(map['alreadyReviewed']);
    final reason = _readNullableString(
      map,
      <String>['reason', 'message'],
    );

    return ReviewEligibilityEntity(
      canReview: canReview,
      orderId: _readNullableString(map, <String>['orderId', 'order_id']),
      reason: reason ??
          (!canReview
              ? alreadyReviewed
                  ? 'You already reviewed this product.'
                  : 'You can review this product after delivery.'
              : null),
    );
  }

  /// Existing reviews the current user already submitted for this specific
  /// order, keyed by productId — powers the order-review screen's
  /// "already reviewed" read-only state so re-opening a partially (or
  /// fully) reviewed order doesn't show blank stars for products that
  /// already have one.
  Future<Map<String, ({int rating, String? comment})>> getOrderReviews(
    String orderId,
  ) async {
    final response = await _apiClient.getOrderReviews(orderId);
    final payload =
        _parsePayload(response.data, ApiConstants.orderReviews(orderId));
    final data = payload['data'];
    if (data is! List) {
      return const <String, ({int rating, String? comment})>{};
    }

    final result = <String, ({int rating, String? comment})>{};
    for (final item in data.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final productId = _readNullableString(
        map,
        <String>['productId', 'product_id'],
      );
      if (productId == null) {
        continue;
      }
      result[productId] = (
        rating: (_toInt(map['rating']) ?? 0).clamp(0, 5),
        comment: _readNullableString(map, <String>['comment']),
      );
    }
    return result;
  }

  Future<ReviewEntity> createReview(Map<String, dynamic> body) async {
    final response = await _apiClient.createReview(body);
    final payload = _parsePayload(response.data, ApiConstants.reviews);
    final data = payload['data'];
    if (data is! Map) {
      throw _badResponse(ApiConstants.reviews, payload);
    }
    return _parseReview(Map<String, dynamic>.from(data));
  }

  Future<ReviewEntity> updateReview(
    String reviewId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.updateReview(reviewId, body);
      final payload =
          _parsePayload(response.data, ApiConstants.reviewById(reviewId));
      final data = payload['data'];
      if (data is! Map) {
        throw _badResponse(ApiConstants.reviewById(reviewId), payload);
      }
      return _parseReview(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code != 404 && code != 405) {
        rethrow;
      }
      final fallback = await _apiClient.patchReview(reviewId, body);
      final payload =
          _parsePayload(fallback.data, ApiConstants.reviewById(reviewId));
      final data = payload['data'];
      if (data is! Map) {
        throw _badResponse(ApiConstants.reviewById(reviewId), payload);
      }
      return _parseReview(Map<String, dynamic>.from(data));
    }
  }

  Future<void> deleteReview(String reviewId) async {
    await _apiClient.deleteReview(reviewId);
  }

  Future<MyReviewsPayload> getMyReviews({
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.getMyReviews(page, limit);
    final payload = _parsePayload(response.data, ApiConstants.myReviews);
    final data = payload['data'];
    final reviewsRaw = data is Map ? data['reviews'] : data;

    final reviews = reviewsRaw is List
        ? reviewsRaw
            .whereType<Map>()
            .map((item) => _parseReview(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <ReviewEntity>[];

    final paginationRaw =
        data is Map ? data['pagination'] : payload['pagination'];
    final pagination = paginationRaw is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationRaw))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: reviews.length,
            totalPages: reviews.isEmpty ? 0 : 1,
          );

    return MyReviewsPayload(
      reviews: reviews,
      pagination: pagination,
    );
  }

  ReviewEntity _parseReview(Map<String, dynamic> json) {
    final createdAt = _readDateTime(
          json,
          <String>['createdAt', 'created_at'],
        ) ??
        DateTime.now();

    final image = _readNullableString(
      json,
      <String>['productImage', 'product_image', 'thumbnail_url'],
    );

    return ReviewEntity(
      id: _readString(json, <String>['id']),
      productId: _readNullableString(
        json,
        <String>['productId', 'product_id'],
      ),
      orderId: _readNullableString(
        json,
        <String>['orderId', 'order_id'],
      ),
      rating: (_toInt(json['rating']) ?? 0).clamp(0, 5),
      comment: _readNullableString(json, <String>['comment']),
      userName: _readNullableString(
        json,
        <String>['userName', 'user_name'],
      ),
      productName: _readNullableString(
        json,
        <String>['productName', 'product_name'],
      ),
      productImage: image ?? _readFirstImage(json['product_images']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> _parsePayload(dynamic raw, String path) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw _badResponse(path, raw);
  }

  DioException _badResponse(String path, dynamic raw) {
    return DioException.badResponse(
      statusCode: 500,
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        data: raw,
      ),
    );
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  bool _toBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  String? _readFirstImage(Object? value) {
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
    }
    return null;
  }
}
