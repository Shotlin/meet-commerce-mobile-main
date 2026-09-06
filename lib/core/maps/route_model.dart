import 'package:equatable/equatable.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';

class RouteModel extends Equatable {
  const RouteModel({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<GeoPoint> points;
  final int distanceMeters;
  final int durationSeconds;

  @override
  List<Object?> get props => <Object?>[points, distanceMeters, durationSeconds];
}
