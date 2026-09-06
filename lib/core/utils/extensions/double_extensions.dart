import 'package:intl/intl.dart';

extension DoubleExtensions on num {
  String get toInrCurrency {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: this % 1 == 0 ? 0 : 2,
    );
    return formatter.format(this);
  }

  String get toPercentage {
    return '${toStringAsFixed(0)}%';
  }
}
