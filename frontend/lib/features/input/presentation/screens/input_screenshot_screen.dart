import 'package:flutter/material.dart';
import 'package:trustcue_mobile/features/input/presentation/widgets/input_preparation_layout.dart';

class InputScreenshotScreen extends StatelessWidget {
  const InputScreenshotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InputPreparationLayout(
      title: 'Screenshot',
      icon: Icons.image_outlined,
      description: 'For suspicious messages captured in an image.',
      unavailabilityNotice: 'Analysis is not available in this development build yet. Image selection and on-device text extraction will be added in upcoming modules.',
      methodSafetyGuidance:
          'Review an image for private information before sharing it.',
    );
  }
}
