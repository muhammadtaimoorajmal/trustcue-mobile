import 'package:flutter/widgets.dart';

/// Single subsection inside a user guide topic card.
class GuideSection {
  final String titleKey;
  final String bodyKey;
  final IconData? icon;

  const GuideSection({
    required this.titleKey,
    required this.bodyKey,
    this.icon,
  });
}

/// Comprehensive topic card model for the offline User Guide.
class GuideTopic {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final List<GuideSection> sections;
  final Widget Function(BuildContext)? illustrationBuilder;

  const GuideTopic({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.sections,
    this.illustrationBuilder,
  });
}
