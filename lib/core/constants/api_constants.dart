import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum CustomerImageProfile {
  banner,
  customBanner,
  categoryTile,
  homeProduct,
  seasonalHeroArtwork,
  listProduct,
  detailGallery,
  cartThumb,
}

class OptimizedMediaAsset {
  const OptimizedMediaAsset({
    required this.url,
    required this.memCacheWidth,
    required this.memCacheHeight,
  });

  final String? url;
  final int memCacheWidth;
  final int memCacheHeight;
}

class _ImageProfileConfig {
  const _ImageProfileConfig({
    required this.width,
    required this.height,
    required this.crop,
  });

  final int width;
  final int height;
  final String crop;
}

class ApiConstants {
  ApiConstants._();

  static const int _optimizedMediaCacheLimit = 256;
  static final Map<String, String?> _resolvedMediaUrlCache =
      <String, String?>{};
  static final Map<String, OptimizedMediaAsset> _optimizedMediaCache =
      <String, OptimizedMediaAsset>{};

  static String get baseUrl => _normalizeLocalhost(
        dotenv.env['BASE_URL'] ?? '',
      );
  static String get socketUrl => _normalizeLocalhost(
        dotenv.env['SOCKET_URL'] ?? '',
      );

  /// Public-facing marketing/web domain used for user-shareable links
  /// (product share, "share the app", etc). Deliberately separate from
  /// [baseUrl], which points at the API host (api.bakaloo.in) — that host
  /// should never appear in a link shown to another person.
  static String get webBaseUrl {
    final configured = dotenv.env['WEB_BASE_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return 'https://bakaloo.in';
  }

  static const sendOtp = '/auth/send-otp';
  static const verifyOtp = '/auth/verify-otp';
  static const refreshToken = '/auth/refresh-token';
  static const logout = '/auth/logout';
  static const deleteAccount = '/auth/account';

  static const me = '/users/me';
  static const meStats = '/users/me/stats';
  static const meAvatar = '/users/me/avatar';

  static const products = '/products';
  static const productsSearch = '/products/search';
  static const productsFeatured = '/products/featured';
  static const productsNewArrivals = '/products/new-arrivals';
  static const productsDeals = '/products/deals';
  static String productById(String id) => '/products/$id';
  static String productRelated(String id) => '/products/$id/related';
  static String productPairWith(String id) => '/products/$id/pair-with';

  static const categories = '/categories';
  static String categoryById(String id) => '/categories/$id';
  static String categoryProducts(String id) => '/categories/$id/products';

  static const cart = '/cart';
  static const cartItems = '/cart/items';
  static const cartValidate = '/cart/validate';
  static const cartSummary = '/cart/summary';
  static const cartQuickAdd = '/cart/quick-add';
  static const cartTip = '/cart/tip';
  static const cartDeliveryInstructions = '/cart/delivery-instructions';
  static String cartItem(String productId) => '/cart/items/$productId';

  static const purchaseLimitsMyStatus = '/purchase-limits/my-status';

  static const addresses = '/addresses';
  static const validatePincode = '/addresses/validate-pincode';
  static String addressById(String id) => '/addresses/$id';
  static String addressDefault(String id) => '/addresses/$id/default';

  // Ola Maps (Beta/test module) — proxied through the backend so the
  // provider API key never ships inside the app build.
  // See lib/core/maps/ola/ola_maps_service.dart.
  static const olaMapsStyleUrl = '/maps/ola/style-url';
  static const olaMapsGeocode = '/maps/ola/geocode';
  static const olaMapsReverseGeocode = '/maps/ola/reverse-geocode';
  static const olaMapsDirections = '/maps/ola/directions';

  static const couponsAvailable = '/coupons/available';
  static const couponsValidate = '/coupons/validate';

  static const orders = '/orders';
  static const ordersActive = '/orders/active';
  static String orderById(String id) => '/orders/$id';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderReorder(String id) => '/orders/$id/reorder';
  static String orderInvoice(String id) => '/orders/$id/invoice';

  static const paymentsCreateOrder = '/payments/create-order';
  static const paymentsVerify = '/payments/verify';
  static const paymentsHistory = '/payments/history';
  static String paymentStatus(String razorpayOrderId) =>
      '/payments/status/$razorpayOrderId';
  static const paymentOffers = '/payment-offers';

  static const tipPresets = '/tip-presets';

  static const productsPriceDrops = '/products/price-drops';
  static const productsLastMinute = '/products/last-minute';

  static const appVersionCheck = '/app/version-check';

  static const wallet = '/wallet';
  static const walletTransactions = '/wallet/transactions';
  static const walletTopup = '/wallet/topup';
  static const walletTopupVerify = '/wallet/topup/verify';
  static const walletPay = '/wallet/pay';
  static const walletTransfer = '/wallet/transfer';
  static const walletRecipientSearch = '/wallet/recipient/search';

  static const wishlist = '/wishlist';
  static const wishlistItems = '/wishlist/items';
  static const wishlistMoveToCart = '/wishlist/move-to-cart';
  static String wishlistItem(String productId) => '/wishlist/items/$productId';

  static const reviews = '/reviews';
  static const myReviews = '/reviews/my-reviews';
  static String reviewsForProduct(String id) => '/reviews/products/$id';
  static String reviewEligibility(String id) => '/reviews/eligibility/$id';
  static String orderReviews(String orderId) => '/reviews/order/$orderId';
  static String reviewById(String id) => '/reviews/$id';

  static const refundRequests = '/refund-requests';

  static const notifications = '/notifications';
  static const notificationTokens = '/notifications/tokens';
  static const notificationPreferences = '/notifications/preferences';
  static const notificationReadAll = '/notifications/read-all';
  static String notificationById(String id) => '/notifications/$id';
  static String notificationRead(String id) => '/notifications/$id/read';

  static const banners = '/banners';
  static const tutorials = '/tutorials';
  static const activeTheme = '/theme/active';
  static const tabThemes = '/theme/tabs';
  static const sectionManifest = '/theme/tabs';
  static const themeAnalytics = '/theme/analytics';
  static const branding = '/branding';

  // Allocation
  static const allocationMyShops = '/allocation/my-shops';
  static const allocationAutoAssign = '/allocation/auto-assign';
  static const allocationRecompute = '/allocation/recompute';

  static const uploadImage = '/uploads/image';

  static String? proxyMediaUrl(String? rawUrl) {
    final resolved = resolveMediaUrl(rawUrl);
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme || !uri.host.contains('cloudinary.com')) {
      return resolved;
    }

    final apiUri = Uri.tryParse(baseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      return resolved;
    }

    return apiUri.replace(
      pathSegments: <String>[
        ...apiUri.pathSegments.where((String segment) => segment.isNotEmpty),
        'uploads',
        'proxy',
      ],
      queryParameters: <String, String>{'url': resolved},
    ).toString();
  }

  static OptimizedMediaAsset proxiedOptimizedMedia(
    String? rawUrl, {
    required CustomerImageProfile profile,
  }) {
    final asset = optimizedMedia(rawUrl, profile: profile);
    return OptimizedMediaAsset(
      url: proxyMediaUrl(asset.url),
      memCacheWidth: asset.memCacheWidth,
      memCacheHeight: asset.memCacheHeight,
    );
  }

  static String? resolveMediaUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final cached = _resolvedMediaUrlCache[value];
    if (_resolvedMediaUrlCache.containsKey(value)) {
      return cached;
    }

    if (value.startsWith('data:')) {
      return _cacheResolvedMediaUrl(value, value);
    }

    final sanitizedCloudinary = _sanitizeCloudinaryUrl(value);
    if (sanitizedCloudinary != null) {
      return _cacheResolvedMediaUrl(
        value,
        _normalizeLocalhost(sanitizedCloudinary),
      );
    }

    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return _cacheResolvedMediaUrl(value, _normalizeLocalhost(value));
    }

    final apiUri = Uri.tryParse(baseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      return _cacheResolvedMediaUrl(value, value);
    }

    final origin = apiUri.replace(
      path: '',
      query: null,
      fragment: null,
    );
    final normalizedPath = value.startsWith('/') ? value : '/$value';
    return _cacheResolvedMediaUrl(
      value,
      origin.resolve(normalizedPath).toString(),
    );
  }

  static String? optimizeCloudinaryUrl(
    String? rawUrl, {
    required int width,
    int? height,
    String crop = 'fill',
  }) {
    final resolved = resolveMediaUrl(rawUrl);
    if (resolved == null || resolved.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme || !uri.host.contains('cloudinary.com')) {
      return resolved;
    }

    const marker = '/upload/';
    if (!resolved.contains(marker)) {
      return proxyMediaUrl(resolved) ?? resolved;
    }

    final transforms = <String>[
      'f_auto',
      'q_auto',
      'dpr_2',
      'c_$crop',
      'w_$width',
      if (height != null) 'h_$height',
    ].join(',');

    final optimized = resolved.replaceFirst(
      marker,
      '/upload/$transforms/',
    );
    return proxyMediaUrl(optimized) ?? optimized;
  }

  static OptimizedMediaAsset optimizedMedia(
    String? rawUrl, {
    required CustomerImageProfile profile,
  }) {
    final config = _profileFor(profile);
    final cacheKey =
        '${profile.name}|${rawUrl?.trim() ?? '<empty>'}|${config.width}|${config.height}|${config.crop}';
    final cached = _optimizedMediaCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final resolved = resolveMediaUrl(rawUrl);
    if (resolved == null || resolved.isEmpty) {
      return _cacheOptimizedMedia(
        cacheKey,
        OptimizedMediaAsset(
          url: null,
          memCacheWidth: config.width,
          memCacheHeight: config.height,
        ),
      );
    }

    return _cacheOptimizedMedia(
      cacheKey,
      OptimizedMediaAsset(
        url: _optimizeResolvedCloudinaryUrl(
          resolved,
          width: config.width,
          height: config.height,
          crop: config.crop,
        ),
        memCacheWidth: config.width,
        memCacheHeight: config.height,
      ),
    );
  }

  static String? _cacheResolvedMediaUrl(String rawValue, String? resolved) {
    if (_resolvedMediaUrlCache.length >= _optimizedMediaCacheLimit) {
      _resolvedMediaUrlCache.remove(_resolvedMediaUrlCache.keys.first);
    }
    _resolvedMediaUrlCache[rawValue] = resolved;
    return resolved;
  }

  static OptimizedMediaAsset _cacheOptimizedMedia(
    String cacheKey,
    OptimizedMediaAsset asset,
  ) {
    if (_optimizedMediaCache.length >= _optimizedMediaCacheLimit) {
      _optimizedMediaCache.remove(_optimizedMediaCache.keys.first);
    }
    _optimizedMediaCache[cacheKey] = asset;
    return asset;
  }

  static String? _optimizeResolvedCloudinaryUrl(
    String resolvedUrl, {
    required int width,
    int? height,
    String crop = 'fill',
  }) {
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || !uri.hasScheme || !uri.host.contains('cloudinary.com')) {
      return resolvedUrl;
    }

    const marker = '/upload/';
    if (!resolvedUrl.contains(marker)) {
      return proxyMediaUrl(resolvedUrl) ?? resolvedUrl;
    }

    final transforms = <String>[
      'f_auto',
      'q_auto',
      'dpr_2',
      'c_$crop',
      'w_$width',
      if (height != null) 'h_$height',
    ].join(',');

    final optimized = resolvedUrl.replaceFirst(
      marker,
      '/upload/$transforms/',
    );
    return proxyMediaUrl(optimized) ?? optimized;
  }

  static _ImageProfileConfig _profileFor(CustomerImageProfile profile) {
    switch (profile) {
      case CustomerImageProfile.banner:
        return const _ImageProfileConfig(
          width: 1080,
          height: 486,
          crop: 'fill',
        );
      case CustomerImageProfile.customBanner:
        return const _ImageProfileConfig(
          width: 1080,
          height: 540,
          crop: 'fit',
        );
      case CustomerImageProfile.categoryTile:
        return const _ImageProfileConfig(
          width: 160,
          height: 160,
          crop: 'fill',
        );
      case CustomerImageProfile.homeProduct:
        return const _ImageProfileConfig(
          width: 132,
          height: 132,
          crop: 'fit',
        );
      case CustomerImageProfile.seasonalHeroArtwork:
        return const _ImageProfileConfig(
          width: 500,
          height: 500,
          crop: 'fit',
        );
      case CustomerImageProfile.listProduct:
        return const _ImageProfileConfig(
          width: 320,
          height: 320,
          crop: 'fit',
        );
      case CustomerImageProfile.detailGallery:
        return const _ImageProfileConfig(
          width: 520,
          height: 520,
          crop: 'fit',
        );
      case CustomerImageProfile.cartThumb:
        return const _ImageProfileConfig(
          width: 80,
          height: 80,
          crop: 'fill',
        );
    }
  }

  static String _normalizeLocalhost(String rawUrl) {
    if (rawUrl.isEmpty ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl;
    }

    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') {
      return rawUrl;
    }

    return uri.replace(host: '10.0.2.2').toString();
  }

  static String? _sanitizeCloudinaryUrl(String rawUrl) {
    if (!rawUrl.contains('cloudinary')) {
      return null;
    }

    final directUri = Uri.tryParse(rawUrl);
    if (directUri != null &&
        directUri.hasScheme &&
        directUri.host.contains('cloudinary.com')) {
      return rawUrl;
    }

    final cloudMatches = RegExp(
      r'https?://res\.cloudinary\.com/([^/]+)/image/upload/',
    ).allMatches(rawUrl);
    if (cloudMatches.isEmpty) {
      return null;
    }

    final cloudName = cloudMatches.last.group(1);
    if (cloudName == null || cloudName.isEmpty) {
      return null;
    }

    final uploadMatches = RegExp(
      r'image/upload/(?:[^/]+/)*v(\d+)/([^?\s]+)',
    ).allMatches(rawUrl);
    if (uploadMatches.isEmpty) {
      return null;
    }

    final version = uploadMatches.last.group(1);
    var publicId = uploadMatches.last.group(2);
    if (version == null || publicId == null || publicId.isEmpty) {
      return null;
    }

    publicId = publicId.split('/image/upload/').first;
    publicId = publicId.replaceFirst(RegExp(r'\?.*$'), '');
    publicId = publicId.replaceFirst(
      RegExp(r'(?:\.[a-zA-Z0-9]+)+(?:com/.*)?$'),
      '',
    );

    if (publicId.isEmpty) {
      return null;
    }

    return 'https://res.cloudinary.com/$cloudName/image/upload/v$version/$publicId';
  }
}
