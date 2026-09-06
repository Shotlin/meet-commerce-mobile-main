import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'
    as flutter_rating_bar;

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

class RatingBar extends StatelessWidget {
  const RatingBar({
    required this.rating,
    this.itemSize = 20,
    this.allowHalfRating = true,
    this.ignoreGestures = true,
    this.onRatingUpdate,
    super.key,
  });

  final double rating;
  final double itemSize;
  final bool allowHalfRating;
  final bool ignoreGestures;
  final ValueChanged<double>? onRatingUpdate;

  @override
  Widget build(BuildContext context) {
    return flutter_rating_bar.RatingBar.builder(
      initialRating: rating,
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: allowHalfRating,
      ignoreGestures: ignoreGestures,
      itemCount: 5,
      itemSize: itemSize,
      unratedColor: AppColors.borderLight,
      itemBuilder: (BuildContext context, int index) {
        return const Icon(
          Icons.star_rounded,
          color: AppColors.ratingGold,
        );
      },
      onRatingUpdate: onRatingUpdate ?? (_) {},
    );
  }
}
