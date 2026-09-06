import 'package:flutter/widgets.dart';

class SpacerSection extends StatelessWidget {
  const SpacerSection({
    required this.height,
    super.key,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}
