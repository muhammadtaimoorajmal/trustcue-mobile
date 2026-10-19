import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/widgets/illustrations/app_illustrations.dart';
import 'package:trustcue_mobile/features/guide/domain/models/guide_topic.dart';
import 'package:trustcue_mobile/features/guide/domain/models/practice_example.dart';

/// Authoritative catalog of offline User Guide topics and safe practice examples.
class GuideCatalog {
  const GuideCatalog._();

  /// The two synthetic demonstration practice examples.
  static const List<PracticeExample> practiceExamples = [
    PracticeExample(
      id: 'practice_warning_threat',
      isWarningSample: true,
      titleKey: 'guide_practice_ex1_title',
      descriptionKey: 'guide_practice_ex1_desc',
      syntheticText: 'URGENT: Your bank account has been suspended due to suspicious activity. Send your login credentials immediately to verify your identity or your account will be permanently closed within 24 hours.',
      explanationKey: 'guide_practice_ex1_explanation',
      expectedRuleIds: [
        'rule.urgency.immediate_action',
        'rule.threat.account_suspension',
        'rule.credentials.harvesting',
      ],
    ),
    PracticeExample(
      id: 'practice_benign_friendly',
      isWarningSample: false,
      titleKey: 'guide_practice_ex2_title',
      descriptionKey: 'guide_practice_ex2_desc',
      syntheticText: 'Hi Mom, please bring groceries home tonight. Love you.',
      explanationKey: 'guide_practice_ex2_explanation',
      expectedRuleIds: [],
    ),
  ];

  /// All 6 comprehensive user guide topics covering actual implemented functionality.
  static List<GuideTopic> getTopics() {
    return [
      // Topic 1: Start a check
      const GuideTopic(
        id: 'start_check',
        titleKey: 'guide_topic1_title',
        subtitleKey: 'guide_topic1_subtitle',
        icon: Icons.search,
        sections: [
          GuideSection(
            titleKey: 'guide_topic1_sec1_title',
            bodyKey: 'guide_topic1_sec1_body',
            icon: Icons.short_text,
          ),
          GuideSection(
            titleKey: 'guide_topic1_sec2_title',
            bodyKey: 'guide_topic1_sec2_body',
            icon: Icons.image_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic1_sec3_title',
            bodyKey: 'guide_topic1_sec3_body',
            icon: Icons.link,
          ),
          GuideSection(
            titleKey: 'guide_topic1_sec4_title',
            bodyKey: 'guide_topic1_sec4_body',
            icon: Icons.qr_code,
          ),
          GuideSection(
            titleKey: 'guide_topic1_sec5_title',
            bodyKey: 'guide_topic1_sec5_body',
            icon: Icons.share_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic1_sec6_title',
            bodyKey: 'guide_topic1_sec6_body',
            icon: Icons.info_outline,
          ),
        ],
      ),

      // Topic 2: Review before analysis
      GuideTopic(
        id: 'review_prepare',
        titleKey: 'guide_topic2_title',
        subtitleKey: 'guide_topic2_subtitle',
        icon: Icons.visibility_outlined,
        illustrationBuilder: (context) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: TextExtractionIllustration(width: 220, height: 100),
        ),
        sections: const [
          GuideSection(
            titleKey: 'guide_topic2_sec1_title',
            bodyKey: 'guide_topic2_sec1_body',
            icon: Icons.spellcheck,
          ),
          GuideSection(
            titleKey: 'guide_topic2_sec2_title',
            bodyKey: 'guide_topic2_sec2_body',
            icon: Icons.translate,
          ),
          GuideSection(
            titleKey: 'guide_topic2_sec3_title',
            bodyKey: 'guide_topic2_sec3_body',
            icon: Icons.edit_note,
          ),
          GuideSection(
            titleKey: 'guide_topic2_sec4_title',
            bodyKey: 'guide_topic2_sec4_body',
            icon: Icons.security,
          ),
          GuideSection(
            titleKey: 'guide_topic2_sec5_title',
            bodyKey: 'guide_topic2_sec5_body',
            icon: Icons.hourglass_empty,
          ),
        ],
      ),

      // Topic 3: Understand a result
      GuideTopic(
        id: 'understand_results',
        titleKey: 'guide_topic3_title',
        subtitleKey: 'guide_topic3_subtitle',
        icon: Icons.fact_check_outlined,
        illustrationBuilder: (context) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: EvidenceReviewIllustration(width: 220, height: 100),
        ),
        sections: const [
          GuideSection(
            titleKey: 'guide_topic3_sec1_title',
            bodyKey: 'guide_topic3_sec1_body',
            icon: Icons.warning_amber_rounded,
          ),
          GuideSection(
            titleKey: 'guide_topic3_sec2_title',
            bodyKey: 'guide_topic3_sec2_body',
            icon: Icons.format_quote,
          ),
          GuideSection(
            titleKey: 'guide_topic3_sec3_title',
            bodyKey: 'guide_topic3_sec3_body',
            icon: Icons.check_circle_outline,
          ),
          GuideSection(
            titleKey: 'guide_topic3_sec4_title',
            bodyKey: 'guide_topic3_sec4_body',
            icon: Icons.rule,
          ),
          GuideSection(
            titleKey: 'guide_topic3_sec5_title',
            bodyKey: 'guide_topic3_sec5_body',
            icon: Icons.verified_user_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic3_sec6_title',
            bodyKey: 'guide_topic3_sec6_body',
            icon: Icons.link_off,
          ),
          GuideSection(
            titleKey: 'guide_topic3_sec7_title',
            bodyKey: 'guide_topic3_sec7_body',
            icon: Icons.psychology_outlined,
          ),
        ],
      ),

      // Topic 4: Save, find, and share
      const GuideTopic(
        id: 'save_find_share',
        titleKey: 'guide_topic4_title',
        subtitleKey: 'guide_topic4_subtitle',
        icon: Icons.folder_shared_outlined,
        sections: [
          GuideSection(
            titleKey: 'guide_topic4_sec1_title',
            bodyKey: 'guide_topic4_sec1_body',
            icon: Icons.save_alt,
          ),
          GuideSection(
            titleKey: 'guide_topic4_sec2_title',
            bodyKey: 'guide_topic4_sec2_body',
            icon: Icons.history,
          ),
          GuideSection(
            titleKey: 'guide_topic4_sec3_title',
            bodyKey: 'guide_topic4_sec3_body',
            icon: Icons.file_download_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic4_sec4_title',
            bodyKey: 'guide_topic4_sec4_body',
            icon: Icons.description_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic4_sec5_title',
            bodyKey: 'guide_topic4_sec5_body',
            icon: Icons.send_outlined,
          ),
        ],
      ),

      // Topic 5: Optional account and cloud features
      GuideTopic(
        id: 'account_cloud',
        titleKey: 'guide_topic5_title',
        subtitleKey: 'guide_topic5_subtitle',
        icon: Icons.cloud_outlined,
        illustrationBuilder: (context) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: LocalCloudBoundaryIllustration(width: 220, height: 100),
        ),
        sections: const [
          GuideSection(
            titleKey: 'guide_topic5_sec1_title',
            bodyKey: 'guide_topic5_sec1_body',
            icon: Icons.person_outline,
          ),
          GuideSection(
            titleKey: 'guide_topic5_sec2_title',
            bodyKey: 'guide_topic5_sec2_body',
            icon: Icons.login,
          ),
          GuideSection(
            titleKey: 'guide_topic5_sec3_title',
            bodyKey: 'guide_topic5_sec3_body',
            icon: Icons.privacy_tip_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic5_sec4_title',
            bodyKey: 'guide_topic5_sec4_body',
            icon: Icons.speed,
          ),
          GuideSection(
            titleKey: 'guide_topic5_sec5_title',
            bodyKey: 'guide_topic5_sec5_body',
            icon: Icons.cloud_sync_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic5_sec6_title',
            bodyKey: 'guide_topic5_sec6_body',
            icon: Icons.delete_sweep_outlined,
          ),
        ],
      ),

      // Topic 6: Troubleshooting
      const GuideTopic(
        id: 'troubleshooting',
        titleKey: 'guide_topic6_title',
        subtitleKey: 'guide_topic6_subtitle',
        icon: Icons.build_outlined,
        sections: [
          GuideSection(
            titleKey: 'guide_topic6_sec1_title',
            bodyKey: 'guide_topic6_sec1_body',
            icon: Icons.broken_image_outlined,
          ),
          GuideSection(
            titleKey: 'guide_topic6_sec2_title',
            bodyKey: 'guide_topic6_sec2_body',
            icon: Icons.language,
          ),
          GuideSection(
            titleKey: 'guide_topic6_sec3_title',
            bodyKey: 'guide_topic6_sec3_body',
            icon: Icons.qr_code_scanner,
          ),
          GuideSection(
            titleKey: 'guide_topic6_sec4_title',
            bodyKey: 'guide_topic6_sec4_body',
            icon: Icons.lock_open,
          ),
          GuideSection(
            titleKey: 'guide_topic6_sec5_title',
            bodyKey: 'guide_topic6_sec5_body',
            icon: Icons.wifi_off,
          ),
          GuideSection(
            titleKey: 'guide_topic6_sec6_title',
            bodyKey: 'guide_topic6_sec6_body',
            icon: Icons.restore,
          ),
        ],
      ),
    ];
  }
}
