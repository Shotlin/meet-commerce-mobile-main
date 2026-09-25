import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_qr_payload_parser.dart';

/// Camera QR scanner reached from Order Details' "Scan / View QR" card.
/// Scanning either the printed invoice's QR or the on-screen code (they
/// encode the same `FRESHCUTS-ORDER|orderNumber|id` payload) resolves that
/// order's vendor cleaning/packing video — the order it resolves is
/// whichever one the scanned code names, not necessarily the order the
/// scanner was opened from, so an old invoice scanned later still works.
class OrderQrScanScreen extends StatefulWidget {
  const OrderQrScanScreen({super.key});

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
    final orderId = parseFreshCutsOrderQrPayload(rawValue);

    if (orderId == null) {
      setState(() {
        _errorMessage = "That doesn't look like a FreshCuts order QR — try again.";
      });
      return;
    }

    setState(() {
      _handledScan = true;
      _errorMessage = null;
    });
    unawaited(_controller.stop());
    context.pushReplacement('/scan-order-qr/$orderId');
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
