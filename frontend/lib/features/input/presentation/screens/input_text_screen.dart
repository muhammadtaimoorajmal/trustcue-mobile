import 'package:flutter/material.dart';
import 'package:trustcue_mobile/features/input/presentation/widgets/input_preparation_layout.dart';

class InputTextScreen extends StatelessWidget {
  const InputTextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InputPreparationLayout(
      title: 'Message text',
      icon: Icons.chat_bubble_outline,
      description: 'For messages copied from SMS, email, or chat.',
      unavailabilityNotice: 'Analysis is not available in this development build yet. Text submission and automated evaluation will be added in upcoming modules.',
      methodSafetyGuidance: 'Remove passwords, OTPs, and personal details before sharing content.',
    );
  }
}
