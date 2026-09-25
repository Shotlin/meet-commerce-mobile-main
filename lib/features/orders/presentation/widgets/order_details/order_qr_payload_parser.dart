/// Parses the plain-text QR payload `order_qr_card.dart#orderQrPayload`
/// encodes on-screen and `invoiceGenerator.js#buildOrderQrPayload` draws on
/// the printed PDF — `FRESHCUTS-ORDER|<orderNumber>|<id>`. Both producers
/// must stay in sync with this parser's expected format.
///
/// Returns the order id, or null if the scanned text isn't a recognisable
/// FreshCuts order QR (a different app's QR, a random code, garbage input).
String? parseFreshCutsOrderQrPayload(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (!trimmed.startsWith('FRESHCUTS-ORDER|')) return null;

  final parts = trimmed.split('|');
  if (parts.length != 3) return null;

  final orderId = parts[2].trim();
  return orderId.isEmpty ? null : orderId;
}
