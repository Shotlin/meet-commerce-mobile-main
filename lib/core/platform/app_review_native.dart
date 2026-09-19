import 'package:in_app_review/in_app_review.dart';

Future<bool> requestAppReview() async {
  final review = InAppReview.instance;
  if (!await review.isAvailable()) {
    return false;
  }
  await review.requestReview();
  return true;
}
