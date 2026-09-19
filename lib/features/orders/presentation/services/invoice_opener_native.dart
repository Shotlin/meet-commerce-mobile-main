import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';

class InvoiceOpenResult {
  const InvoiceOpenResult({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;
}

Future<InvoiceOpenResult> openInvoice(InvoiceFileResult invoice) async {
  try {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${invoice.fileName}');
    await file.writeAsBytes(invoice.bytes, flush: true);
    final result = await OpenFile.open(file.path);
    if (result.type == ResultType.done) {
      return InvoiceOpenResult(
        message: 'Invoice downloaded: ${invoice.fileName}',
        isSuccess: true,
      );
    }
    return InvoiceOpenResult(message: result.message, isSuccess: false);
  } catch (_) {
    return const InvoiceOpenResult(
      message: 'Unable to open the invoice right now.',
      isSuccess: false,
    );
  }
}
