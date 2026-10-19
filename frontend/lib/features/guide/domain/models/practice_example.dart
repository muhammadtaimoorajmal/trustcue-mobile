/// Definition of a synthetic practice example used in safe guided demonstrations.
class PracticeExample {
  final String id;
  final bool isWarningSample;
  final String titleKey;
  final String descriptionKey;
  final String syntheticText;
  final String explanationKey;
  final List<String> expectedRuleIds;

  const PracticeExample({
    required this.id,
    required this.isWarningSample,
    required this.titleKey,
    required this.descriptionKey,
    required this.syntheticText,
    required this.explanationKey,
    required this.expectedRuleIds,
  });
}
