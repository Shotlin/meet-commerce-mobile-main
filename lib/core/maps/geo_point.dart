import 'package:equatable/equatable.dart';

class GeoPoint extends Equatable {
  const GeoPoint({
    required this.lat,
    required this.lng,
  });

  final double lat;
  final double lng;

  bool get isValid => lat.isFinite && lng.isFinite && !(lat == 0 && lng == 0);

  @override
  List<Object?> get props => <Object?>[lat, lng];
}
