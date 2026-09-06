import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/features/auth/data/models/auth_response_model.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/tip_preset_entity.dart';
import 'package:bakaloo_flutter_app/shared/models/api_response.dart';

part 'api_client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  @POST(ApiConstants.sendOtp)
  Future<ApiResponse<void>> sendOtp(@Body() Map<String, dynamic> body);

  @POST(ApiConstants.verifyOtp)
  Future<ApiResponse<AuthResponseModel>> verifyOtp(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.refreshToken)
  Future<ApiResponse<TokenModel>> refreshToken(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.logout)
  Future<ApiResponse<void>> logout([
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @DELETE(ApiConstants.deleteAccount)
  Future<ApiResponse<void>> deleteAccount();

  @GET(ApiConstants.me)
  Future<HttpResponse<dynamic>> getMe();

  @PUT(ApiConstants.me)
  Future<HttpResponse<dynamic>> updateMe(
    @Body() Map<String, dynamic> body,
  );

  @MultiPart()
  @PUT(ApiConstants.meAvatar)
  Future<HttpResponse<dynamic>> uploadMeAvatar(
    @Part(name: 'avatar') MultipartFile avatar,
  );

  @MultiPart()
  @POST(ApiConstants.meAvatar)
  Future<HttpResponse<dynamic>> uploadMeAvatarPost(
    @Part(name: 'avatar') MultipartFile avatar,
  );

  @GET(ApiConstants.meStats)
  Future<HttpResponse<dynamic>> getMeStats();

  @GET(ApiConstants.olaMapsStyleUrl)
  Future<HttpResponse<dynamic>> getOlaMapsStyleUrl();

  @GET(ApiConstants.olaMapsStaticMapUrl)
  Future<HttpResponse<dynamic>> getOlaMapsStaticMapUrl(
    @Query('lat') double lat,
    @Query('lng') double lng,
    @Query('zoom') double zoom,
    @Query('width') int width,
    @Query('height') int height,
    @Query('marker') bool marker,
  );

  @GET(ApiConstants.olaMapsGeocode)
  Future<HttpResponse<dynamic>> getOlaMapsGeocode(
    @Query('address') String address,
  );

  @GET(ApiConstants.olaMapsReverseGeocode)
  Future<HttpResponse<dynamic>> getOlaMapsReverseGeocode(
    @Query('lat') double lat,
    @Query('lng') double lng,
  );

  @GET(ApiConstants.olaMapsDirections)
  Future<HttpResponse<dynamic>> getOlaMapsDirections(
    @Query('originLat') double originLat,
    @Query('originLng') double originLng,
    @Query('destLat') double destLat,
    @Query('destLng') double destLng,
  );

  @GET(ApiConstants.banners)
  Future<ApiResponse<List<dynamic>>> getBanners({@Query('type') String? type});

  @GET(ApiConstants.tutorials)
  Future<ApiResponse<List<dynamic>>> getTutorials();

  @GET(ApiConstants.categories)
  Future<ApiResponse<List<dynamic>>> getCategories();

  @GET('/categories/{id}/products')
  Future<HttpResponse<dynamic>> getCategoryProducts(
    @Path('id') String categoryId,
    @Query('page') int page,
    @Query('limit') int limit, {
    @Query('groupOptions') bool? groupOptions,
  });

  @GET(ApiConstants.products)
  Future<HttpResponse<dynamic>> getProducts(
    @Query('page') int page,
    @Query('limit') int limit, {
    @Query('groupOptions') bool? groupOptions,
  });

  @GET(ApiConstants.productsSearch)
  Future<HttpResponse<dynamic>> searchProducts(
    @Query('q') String query,
    @Query('page') int page,
    @Query('limit') int limit,
  );

  @GET(ApiConstants.cart)
  Future<HttpResponse<dynamic>> getCart();

  @GET(ApiConstants.cartSummary)
  Future<ApiResponse<BillSummaryEntity>> getCartSummary({
    @Query('quickDeliverySelected') bool quickDeliverySelected = false,
    @Query('addressId') String? addressId,
  });

  @GET(ApiConstants.cartQuickAdd)
  Future<HttpResponse<dynamic>> getCartQuickAdd(
    @Query('limit') int limit,
  );

  @POST(ApiConstants.cartItems)
  Future<HttpResponse<dynamic>> addCartItem(
    @Body() Map<String, dynamic> body,
  );

  @PUT('/cart/items/{productId}')
  Future<HttpResponse<dynamic>> updateCartItem(
    @Path('productId') String productId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/cart/items/{productId}')
  Future<HttpResponse<dynamic>> removeCartItem(
    @Path('productId') String productId, {
    @Query('shopProductId') String? shopProductId,
  });

  @GET('/products/{id}/options')
  Future<HttpResponse<dynamic>> getProductOptions(
    @Path('id') String productId,
  );

  @DELETE(ApiConstants.cart)
  Future<HttpResponse<dynamic>> clearCart();

  @PUT(ApiConstants.cartTip)
  Future<HttpResponse<dynamic>> updateCartTip(
    @Body() Map<String, dynamic> body,
  );

  @PUT(ApiConstants.cartDeliveryInstructions)
  Future<HttpResponse<dynamic>> updateDeliveryInstructions(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.cartValidate)
  Future<HttpResponse<dynamic>> validateCart(
    @Body() Map<String, dynamic> body,
  );

  @GET(ApiConstants.purchaseLimitsMyStatus)
  Future<HttpResponse<dynamic>> getPurchaseLimitsStatus(
    @Query('productIds') String productIds,
  );

  @GET(ApiConstants.addresses)
  Future<HttpResponse<dynamic>> getAddresses();

  @POST(ApiConstants.addresses)
  Future<HttpResponse<dynamic>> createAddress(
    @Body() Map<String, dynamic> body,
  );

  @PUT('/addresses/{id}')
  Future<HttpResponse<dynamic>> updateAddress(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/addresses/{id}')
  Future<HttpResponse<dynamic>> deleteAddress(
    @Path('id') String id,
  );

  @PUT('/addresses/{id}/default')
  Future<HttpResponse<dynamic>> setDefaultAddress(
    @Path('id') String id, [
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @POST(ApiConstants.validatePincode)
  Future<HttpResponse<dynamic>> validatePincode(
    @Body() Map<String, dynamic> body,
  );

  @GET(ApiConstants.couponsAvailable)
  Future<HttpResponse<dynamic>> getAvailableCoupons();

  @POST(ApiConstants.couponsValidate)
  Future<HttpResponse<dynamic>> validateCoupon(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.orders)
  Future<HttpResponse<dynamic>> placeOrder(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.paymentsCreateOrder)
  Future<HttpResponse<dynamic>> createPaymentOrder(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.paymentsVerify)
  Future<HttpResponse<dynamic>> verifyPayment(
    @Body() Map<String, dynamic> body,
  );

  @GET(ApiConstants.paymentsHistory)
  Future<HttpResponse<dynamic>> getPaymentHistory(
    @Query('page') int page,
    @Query('limit') int limit,
  );

  @GET('/payments/status/{razorpayOrderId}')
  Future<HttpResponse<dynamic>> getPaymentStatus(
    @Path('razorpayOrderId') String razorpayOrderId,
  );

  @GET(ApiConstants.wallet)
  Future<HttpResponse<dynamic>> getWallet();

  @GET(ApiConstants.walletTransactions)
  Future<HttpResponse<dynamic>> getWalletTransactions(
    @Query('page') int page,
    @Query('limit') int limit,
    @Query('type') String? type,
  );

  @POST(ApiConstants.walletTopup)
  Future<HttpResponse<dynamic>> createWalletTopup(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.walletTopupVerify)
  Future<HttpResponse<dynamic>> verifyWalletTopup(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.walletPay)
  Future<HttpResponse<dynamic>> payFromWallet(
    @Body() Map<String, dynamic> body,
  );

  @POST(ApiConstants.walletTransfer)
  Future<HttpResponse<dynamic>> transferWallet(
    @Body() Map<String, dynamic> body,
  );

  @GET(ApiConstants.walletRecipientSearch)
  Future<HttpResponse<dynamic>> searchWalletRecipient(
    @Query('q') String q,
  );

  @GET(ApiConstants.tipPresets)
  Future<ApiResponse<List<TipPresetEntity>>> getTipPresets();

  @GET(ApiConstants.paymentOffers)
  Future<ApiResponse<List<PaymentOfferEntity>>> getPaymentOffers(
    @Query('cart_total') double cartTotal,
  );

  @GET(ApiConstants.productsPriceDrops)
  Future<HttpResponse<dynamic>> getPriceDropProducts();

  @GET(ApiConstants.productsLastMinute)
  Future<HttpResponse<dynamic>> getLastMinuteProducts();

  @GET(ApiConstants.wishlist)
  Future<HttpResponse<dynamic>> getWishlist();

  @POST(ApiConstants.wishlistItems)
  Future<HttpResponse<dynamic>> addWishlistItemByBody(
    @Body() Map<String, dynamic> body,
  );

  @POST('/wishlist/items/{productId}')
  Future<HttpResponse<dynamic>> addWishlistItem(
    @Path('productId') String productId,
  );

  @DELETE('/wishlist/items/{productId}')
  Future<HttpResponse<dynamic>> removeWishlistItem(
    @Path('productId') String productId,
  );

  @POST(ApiConstants.wishlistMoveToCart)
  Future<HttpResponse<dynamic>> moveWishlistToCart(
    @Body() Map<String, dynamic> body,
  );

  @GET('/reviews/products/{productId}')
  Future<HttpResponse<dynamic>> getProductReviews(
    @Path('productId') String productId,
    @Query('page') int page,
    @Query('limit') int limit,
  );

  @GET('/reviews/eligibility/{productId}')
  Future<HttpResponse<dynamic>> getReviewEligibility(
    @Path('productId') String productId,
  );

  @GET('/reviews/order/{orderId}')
  Future<HttpResponse<dynamic>> getOrderReviews(
    @Path('orderId') String orderId,
  );

  @POST(ApiConstants.reviews)
  Future<HttpResponse<dynamic>> createReview(
    @Body() Map<String, dynamic> body,
  );

  @PUT('/reviews/{reviewId}')
  Future<HttpResponse<dynamic>> updateReview(
    @Path('reviewId') String reviewId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/reviews/{reviewId}')
  Future<HttpResponse<dynamic>> patchReview(
    @Path('reviewId') String reviewId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/reviews/{reviewId}')
  Future<HttpResponse<dynamic>> deleteReview(
    @Path('reviewId') String reviewId,
  );

  @GET(ApiConstants.myReviews)
  Future<HttpResponse<dynamic>> getMyReviews(
    @Query('page') int page,
    @Query('limit') int limit,
  );

  @POST(ApiConstants.refundRequests)
  Future<HttpResponse<dynamic>> createRefundRequest(
    @Body() Map<String, dynamic> body,
  );

  @GET('/refund-requests/order/{orderId}')
  Future<HttpResponse<dynamic>> getRefundRequestByOrder(
    @Path('orderId') String orderId,
  );

  @POST('/refund-requests/{id}/cancel')
  Future<HttpResponse<dynamic>> cancelRefundRequest(
    @Path('id') String id,
  );

  @GET(ApiConstants.productsFeatured)
  Future<ApiResponse<List<dynamic>>> getFeaturedProducts(
    @Query('limit') int limit,
  );

  @GET(ApiConstants.productsNewArrivals)
  Future<ApiResponse<List<dynamic>>> getNewArrivalProducts(
    @Query('limit') int limit,
  );

  @GET(ApiConstants.productsDeals)
  Future<ApiResponse<List<dynamic>>> getDealProducts(
    @Query('limit') int limit,
  );

  @GET('/products/{id}')
  Future<HttpResponse<dynamic>> getProductDetail(
    @Path('id') String productId,
  );

  @GET('/products/{id}/related')
  Future<ApiResponse<List<dynamic>>> getRelatedProducts(
    @Path('id') String productId,
    @Query('limit') int limit,
  );

  @GET('/products/{id}/pair-with')
  Future<ApiResponse<List<dynamic>>> getPairWithProducts(
    @Path('id') String productId,
    @Query('limit') int limit,
  );

  @GET(ApiConstants.notifications)
  Future<HttpResponse<dynamic>> getNotifications(
    @Query('page') int page,
    @Query('limit') int limit,
  );

  @PUT('/notifications/{id}/read')
  Future<HttpResponse<dynamic>> markNotificationRead(
    @Path('id') String id, [
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @PATCH('/notifications/{id}/read')
  Future<HttpResponse<dynamic>> markNotificationReadPatch(
    @Path('id') String id, [
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @PUT(ApiConstants.notificationReadAll)
  Future<HttpResponse<dynamic>> markAllNotificationsRead([
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @PATCH(ApiConstants.notificationReadAll)
  Future<HttpResponse<dynamic>> markAllNotificationsReadPatch([
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @PATCH('/notifications/campaigns/{campaignId}/opened')
  Future<HttpResponse<dynamic>> markCampaignOpened(
    @Path('campaignId') String campaignId, [
    @Body() Map<String, dynamic> body = const <String, dynamic>{},
  ]);

  @DELETE('/notifications/{id}')
  Future<HttpResponse<dynamic>> deleteNotification(
    @Path('id') String id,
  );

  @POST(ApiConstants.notificationTokens)
  Future<HttpResponse<dynamic>> registerNotificationToken(
    @Body() Map<String, dynamic> body,
  );

  @GET(ApiConstants.notificationPreferences)
  Future<HttpResponse<dynamic>> getNotificationPreferences();

  @PUT(ApiConstants.notificationPreferences)
  Future<HttpResponse<dynamic>> updateNotificationPreferences(
    @Body() Map<String, dynamic> body,
  );
}
