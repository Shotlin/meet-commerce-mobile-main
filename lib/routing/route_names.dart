class RouteNames {
  RouteNames._();

  static const root = '/';
  static const splash = '/splash';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const home = '/home';
  static const categories = '/categories';
  static const categoriesBrowse = '/categories/browse';
  static const categoryProducts = '/categories/:categoryId/products';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const orderDetail = '/orders/:orderId';
  static const tracking = '/orders/:orderId/track';
  static const profile = '/profile';
  static const wallet = '/profile/wallet';
  static const topup = '/profile/wallet/topup';
  static const walletSend = '/profile/wallet/send';
  static const wishlist = '/profile/wishlist';
  static const addresses = '/profile/addresses';
  static const addAddress = '/profile/addresses/add';
  static const notifications = '/profile/notifications';
  static const productDetail = '/product/:productId';
  static const search = '/search';
  static const myReviews = '/profile/reviews';
  static const settings = '/profile/settings';
  static const onboarding = '/onboarding';
  static const offZone = '/off_zone';
  static const superMall = '/super_mall';
  static const cafe = '/cafe';
  static const locationUnavailable = '/location-unavailable';
}
