import 'package:flutter/material.dart';
import 'package:trustcue_mobile/features/input/presentation/widgets/input_preparation_layout.dart';

class InputLinkScreen extends StatelessWidget {
  const InputLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InputPreparationLayout(
      title: 'Link or QR code',
      icon: Icons.link_outlined,
      description: 'For reviewing a destination before opening it.',
      unavailabilityNotice: 'Analysis is not available in this development build yet. URL inspection and QR code decoding will be added in upcoming modules.',
      methodSafetyGuidance:
          'Avoid opening an unfamiliar destination just to check it.',
    );
  }
}
