class AppConstants {
  AppConstants._();

  static const paginationLimit = 20;
  static const searchDebounceMs = 300;
  static const otpLength = 6;
  static const otpResendSeconds = 60;
  static const freeDeliveryThreshold = 499.0;
  static const standardDeliveryFee = 25.0;
  static const platformFee = 5.0;
  static const maxCodAmount = 2000.0;
  static const maxSearchHistory = 10;
  static const maxRecentlyViewed = 12;
  static const imageCacheSizeMB = 256;
  static const imageCacheMaxCount = 1000;
  static const socketReconnectAttempts = 10;
  static const socketReconnectDelayMs = 2000;
  // PHASE 4 FIX: Mobile data + Cloudflare tunnel needs a more forgiving
  // connect timeout. 15s was too aggressive — a cold mobile-data connection
  // through the tunnel routinely exceeded it and tripped the
  // service-unavailable blocker. 25s connect / 40s receive is safe.
  static const connectTimeoutSeconds = 25;
  static const receiveTimeoutSeconds = 40;

  // Official company contact — shown in the in-app Support sheet, and must
  // match Privacy Policy / Terms / Play Console Store Settings exactly.
  static const supportPhone = '+91 99249 98906';
  static const supportPhoneDialable = '+919924998906';
  static const supportEmail = 'support@bakaloo.in';

  // Wallet-to-wallet transfer (send money to another Bakaloo user) is
  // disabled for this release: it requires RBI Full-KYC PPI authorization
  // regardless of transfer/balance limits, which this platform does not
  // have. The backend already rejects every transfer (wallet_max_transfer_amount
  // is 0 in production), so this only controls whether the UI still offers
  // an entry point into a feature that will fail. Flip back on together with
  // re-enabling it on the backend once that's been cleared.
  static const walletTransfersEnabled = false;
}
