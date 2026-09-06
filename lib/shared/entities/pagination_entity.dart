import 'package:equatable/equatable.dart';

class PaginationEntity extends Equatable {
  const PaginationEntity({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PaginationEntity.fromJson(Map<String, dynamic> json) {
    return PaginationEntity(
      page: _readInt(json['page'], fallback: 1),
      limit: _readInt(json['limit'], fallback: 20),
      total: _readInt(json['total']),
      totalPages: _readInt(json['totalPages']),
    );
  }

  /// Tolerant int reader: accepts int, num (e.g. `10.0`) and numeric strings.
  ///
  /// API number types can vary (JSON has no int/double distinction), so a hard
  /// `as int` cast would throw and fail the whole list parse.
  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
    };
  }

  @override
  List<Object?> get props => <Object?>[page, limit, total, totalPages];
}
