// Browser-only implementation. dart:html is used here because the pinned
// Flutter SDK exposes Blob/Anchor download APIs through this library.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';

class InvoiceOpenResult {
  const InvoiceOpenResult({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;
}

Future<InvoiceOpenResult> openInvoice(InvoiceFileResult invoice) async {
  try {
    final blob = html.Blob(<Object>[invoice.bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = invoice.fileName
      ..style.display = 'none'
      ..click();
    Timer(const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
    return InvoiceOpenResult(
      message: 'Invoice download started: ${invoice.fileName}',
      isSuccess: true,
    );
  } catch (_) {
    return const InvoiceOpenResult(
      message: 'Unable to download the invoice right now.',
      isSuccess: false,
    );
  }
}
