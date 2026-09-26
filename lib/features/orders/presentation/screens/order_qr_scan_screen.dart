import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/orders/presentation/screens/order_qr_scan_outcome.dart';

/// Camera QR scanner reached from Order Details' "Scan / View QR" card.
/// Scanning either the printed invoice's QR or the on-screen code (they
/// encode the same `FRESHCUTS-ORDER|orderNumber|id` payload) resolves that
/// order's vendor cleaning/packing video.
///
/// **Scoped to the order the scanner was opened from** (`expectedOrderId`,
/// passed by `OrderQrCard` as the route's `extra`): a customer must only
/// ever be able to unlock the video for the exact order they're currently
/// viewing, not a different one of their own past orders just because its
/// QR happens to be genuinely valid. Scanning any other order's QR is
/// rejected with a clear message and the camera stays open to retry —
/// `expectedOrderId` is nullable only as a defensive fallback for a route
/// entry with no order in scope (there is currently no such call site).
class OrderQrScanScreen extends StatefulWidget {
  const OrderQrScanScreen({this.expectedOrderId, this.expectedOrderNumber, super.key});

  /// The real `orders.id` of the order this scanner was opened from.
  final String? expectedOrderId;

  /// The human-readable order number (e.g. `FC-KOL-...-0001`), shown in
  /// the mismatch message so the customer knows which order they're
  /// actually inside.
  final String? expectedOrderNumber;

  @override
  State<OrderQrScanScreen> createState() => _OrderQrScanScreenState();
}

class _OrderQrScanScreenState extends State<OrderQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handledScan = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handledScan) return;
    final rawValue = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;

    // The actual validation (including the core requirement — this QR
    // must belong to the exact order the scanner was opened from) is a
    // pure function so it's directly unit-tested without a real camera.
    final outcome = resolveQrScanOutcome(
      rawValue: rawValue,
      expectedOrderId: widget.expectedOrderId,
      expectedOrderNumber: widget.expectedOrderNumber,
    );

    switch (outcome) {
      case QrScanRejected(:final message):
        // Camera keeps running — the customer can immediately try again
        // (the right invoice, or a valid FreshCuts code).
        setState(() {
          _errorMessage = message;
        });
      case QrScanMatch(:final orderId):
        setState(() {
          _handledScan = true;
          _errorMessage = null;
        });
        unawaited(_controller.stop());
        context.pushReplacement('/scan-order-qr/$orderId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Simple viewfinder frame — purely visual, no scan logic here.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  _CircleIconButton(
                    icon: PhosphorIcons.x,
                    onTap: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              children: <Widget>[
                const Text(
                  'Point your camera at the QR code on your invoice',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: PhosphorIcon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
