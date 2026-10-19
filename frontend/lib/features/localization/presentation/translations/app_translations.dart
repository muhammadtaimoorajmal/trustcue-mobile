import 'package:get/get.dart';

/// Centralized localization dictionary for TrustCue.
///
/// Invariants:
/// - Provides stable translation keys for English (`en_US`) and Urdu (`ur_PK`).
/// - Urdu translations support natural RTL reading while preserving technical
///   terms, domain models, and privacy guarantees.
/// - Language switching changes user-facing interface labels only;
///   detection rules evaluate English text, and OCR targets Latin script.
/// - User snapshots and evidence highlights are never translated or modified.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'en_US': enUS, 'ur_PK': urPK};

  static const Map<String, String> enUS = {
    // Common
    'app_name': 'TrustCue',
    'cancel': 'Cancel',
    'save': 'Save',
    'close': 'Close',
    'confirm': 'Confirm',
    'delete': 'Delete',
    'back': 'Back',
    'saved_on_device': 'Saved on this device',
    'language': 'Language',
    'settings': 'Settings',

    // Home
    'home_title': 'TrustCue',
    'home_headline': 'Understand the signals.',
    'home_subtitle':
        'Choose how you want to review a suspicious message or link.',
    'home_local_checks_note':
        'Local checks are available. Results are indicators, not a verdict.',
    'home_message_text_title': 'Message text',
    'home_message_text_desc': 'For messages copied from SMS, email, or chat. Review and local checks are available on this device.',
    'home_screenshot_title': 'Screenshot',
    'home_screenshot_desc': 'For suspicious messages captured in an image. Preview, local text extraction, and local checks are available.',
    'home_link_title': 'Link or QR code',
    'home_link_desc': 'For reviewing a destination before opening it. Link inspection, QR decoding, and local checks are available.',
    'home_education_title': 'Scam Education Center',
    'home_education_desc': 'Explore 10 scam indicator patterns, safe verification steps, and interactive practice examples.',
    'home_education_action': 'Explore Education',
    'home_pause_title': 'Pause before you act.',
    'home_pause_desc': 'Verify unexpected requests through contact details you already trust. Never share passwords or one-time codes in response to an unverified message.',
    'home_safe_use_btn': 'Review safe-use guidance',

    // Education & Practice
    'education_title': 'Scam Education Center',
    'education_subtitle': 'Learn how scam patterns work, why they deserve attention, and how to verify independently.',
    'education_search_hint': 'Search indicator topics...',
    'education_practice_banner_title': 'Safe Practice Examples',
    'education_practice_banner_desc': 'Practice identifying indicators using realistic synthetic messages without risk.',
    'education_what_observed': 'What pattern is observed',
    'education_why_attention': 'Why it deserves attention',
    'education_cannot_establish': 'What this check cannot establish',
    'education_synthetic_example': 'Synthetic practice example',
    'education_contrasting_example': 'Contrasting ordinary example',
    'education_contrasting_why': 'Why this differs from a scam',
    'education_verification_step': 'Practical independent verification steps',
    'education_primary_source': 'Official Reference Guidance',
    'education_try_example_btn': 'Practice with this example',
    'education_try_example_note': 'Loads this synthetic text into the review screen for safe offline analysis.',
    'education_draft_replace_title': 'Replace current draft?',
    'education_draft_replace_desc': 'You have text entered in the review input. Replacing it will overwrite your draft with this educational example.',
    'education_replace_btn': 'Replace Draft',
    'education_keep_draft_btn': 'Keep Existing Draft',
    'education_all_topics': 'All 10 Indicator Families',

    // Feedback
    'feedback_dialog_title': 'Was this helpful?',
    'feedback_disclaimer': 'TrustCue is an educational tool, not a law enforcement agency or reporting authority. Submitting feedback will NOT report a scam to authorities or protect against fraud.',
    'feedback_rate_helpful': 'Helpful',
    'feedback_rate_unhelpful': 'Not helpful',
    'feedback_rate_neutral': 'Neutral',
    'feedback_reasons_title': 'What was your experience?',
    'feedback_comment_label': 'Optional comment (max 200 chars)',
    'feedback_privacy_warning':
        'Do not enter passwords, phone numbers, or private personal data.',
    'feedback_save_btn': 'Save Feedback',
    'feedback_saved_msg': 'Feedback saved locally on this device.',
    'feedback_local_notice':
        'Your feedback is stored anonymously on this device only.',

    // Reason chips
    'feedback_chip_clear_explanation': 'Clear explanation',
    'feedback_chip_good_example': 'Good example',
    'feedback_chip_easy_to_verify': 'Clear verification steps',
    'feedback_chip_confusing_terms': 'Confusing terminology',
    'feedback_chip_too_technical': 'Too technical',
    'feedback_chip_example_mismatch': 'Example mismatch',
    'feedback_chip_missing_steps': 'Missing verification step',
    'feedback_chip_other': 'Other',

    // Language Selector
    'language_selector_title': 'Choose Language',
    'language_notice': 'Changing the app language translates interface labels. Scam detection rules evaluate English messages, and OCR detects Latin characters. Analyzed text and evidence excerpts are never altered or translated.',
    'language_system': 'System default',
    'language_english': 'English',
    'language_urdu': 'Urdu (اردو)',

    // Privacy & About
    'about_title': 'About TrustCue',
    'privacy_title': 'Privacy & Data Controls',
    'privacy_feedback_title': 'Local Anonymous Feedback',
    'privacy_feedback_desc':
        'Usefulness ratings and comments stored locally on this device.',
    'privacy_clear_feedback_btn': 'Clear Local Feedback',
    'privacy_feedback_cleared': 'All local feedback records cleared.',
    'privacy_feedback_count': '@count feedback records saved locally',

    // Export & Sharing
    'export_report_title': 'Export & Share Report',
    'export_format_label': 'Export Format',
    'export_format_plain_text': 'Plain Text (.txt)',
    'export_format_pdf': 'PDF Document (.pdf)',
    'export_include_options_title': 'Information to Include',
    'export_include_text': 'Include reviewed message text',
    'export_include_text_desc':
        'Exposes analyzed message content in the exported file.',
    'export_include_evidence': 'Include evidence quotes',
    'export_include_evidence_desc':
        'Exposes specific text excerpts cited in findings.',
    'export_include_ai': 'Include AI explanations',
    'export_include_ai_desc':
        'Exposes detailed server-assisted analysis reasoning.',
    'export_privacy_warning': 'Warning: Exported reports may expose sensitive communication. Only share with parties you trust.',
    'export_share_button': 'Share Report',
    'export_copy_button': 'Copy Text',
    'export_copied_toast': 'Report copied to clipboard',
    'export_preview_title': 'Report Preview',
    'export_generating': 'Preparing export file...',
    'export_sharing': 'Opening share sheet...',
    'export_pdf_urdu_notice': 'PDF uses Latin typography. Plain Text (.txt) is recommended for full Urdu and non-Latin script fidelity.',
    'export_action_tooltip': 'Export or Share Report',

    // Analysis Results & Guidance (Module 50B)
    'how_to_read_results_title': 'How to read this result',
    'how_to_read_results_subtitle': 'Quick guide to understanding TrustCue indicators and safety boundaries.',
    'help_clues_title': 'Warning signs are clues, not a final verdict',
    'help_clues_desc': 'TrustCue flags patterns commonly found in scams. Finding a warning sign does not prove fraud, and finding nothing does not prove a message is safe.',
    'help_no_matches_title': 'No matches does not guarantee safety',
    'help_no_matches_desc': 'On-device checks look for specific known patterns. New scams, polite phrasing, or unusual formats may not trigger an indicator.',
    'help_evidence_title': 'Evidence shows what triggered a finding',
    'help_evidence_desc': 'Each finding cites the exact text or link structure that raised a flag, so you can inspect the reasoning yourself.',
    'help_local_ai_title': 'Local analysis and optional AI are different',
    'help_local_ai_desc': 'On-device checks run completely offline without uploading data. Optional Cloud AI evaluates secondary patterns only when you give explicit consent.',
    'help_actions_title': 'Saving, backup, and export are separate actions',
    'help_actions_desc': 'Saving keeps a copy on this device only. Optional cloud backup syncs report metadata only (never message text). Export lets you share a file.',
    'help_close_btn': 'Got it',

    'outcome_indicators_found': 'Potential warning signs found',
    'outcome_indicators_found_single': '1 potential warning sign found',
    'outcome_no_matches': 'No warning signs found by the on-device checks',
    'outcome_no_matches_calm': 'These checks found no matching warning signs. This does not verify the sender or guarantee that the message or link is safe.',
    'outcome_limited_coverage': 'Only part of this content could be checked',
    'outcome_check_failed': 'We couldn’t complete this check',

    'what_was_checked_title': 'What was checked',
    'checked_on_device': 'On-device checks: Evaluated against 10 local heuristic rules without sending data anywhere.',
    'checked_url_offline': 'Offline URL inspection: Analyzed web address structure offline; the destination website was not visited or verified.',
    'checked_language_limits': 'Language & text boundaries: Rules evaluate English message patterns; text extraction covers Latin script.',
    'checked_cloud_ai_completed': 'Cloud AI assistance: Evaluated secondary linguistic patterns via Groq Cloud.',
    'checked_cloud_ai_idle': 'Cloud AI assistance: Not requested. Local on-device checks only.',
    'checked_cloud_ai_failed': 'Cloud AI assistance: Could not be completed. Your local results remain valid and unaffected.',

    'technical_details_title': 'Technical details & rule offsets',
    'show_technical_details': 'Show technical details',
    'hide_technical_details': 'Hide technical details',
    'cloud_summary_no_text_notice': 'Original message text and evidence quotes are omitted from cloud backups to protect your privacy. Only report metadata (timestamp, source, category count) is synchronized.',
  };

  static const Map<String, String> urPK = {
    // Common
    'app_name': 'ٹرسٹ کیو',
    'cancel': 'منسوخ کریں',
    'save': 'محفوظ کریں',
    'close': 'بند کریں',
    'confirm': 'تصدیق کریں',
    'delete': 'حذف کریں',
    'back': 'واپس',
    'saved_on_device': 'اس ڈیوائس پر محفوظ ہو گیا',
    'language': 'زبان',
    'settings': 'ترتیبات',

    // Home
    'home_title': 'ٹرسٹ کیو',
    'home_headline': 'اشاروں کو سمجھیں۔',
    'home_subtitle': 'مشتبہ پیغام یا لنک کا جائزہ لینے کا طریقہ منتخب کریں۔',
    'home_local_checks_note':
        'مقامی جانچ دستیاب ہے۔ نتائج صرف اشارے ہیں، کوئی حتمی فیصلہ نہیں۔',
    'home_message_text_title': 'پیغام کا متن',
    'home_message_text_desc': 'ایس ایم ایس، ای میل یا چیٹ سے کاپی کردہ پیغامات کے لیے۔ اس ڈیوائس پر جائزہ اور مقامی جانچ دستیاب ہے۔',
    'home_screenshot_title': 'اسکرین شاٹ',
    'home_screenshot_desc': 'تصویر میں موجود مشتبہ پیغامات کے لیے۔ پیش نظارہ، مقامی متن کا اخراج اور جانچ دستیاب ہے۔',
    'home_link_title': 'لنک یا کیو آر کوڈ',
    'home_link_desc': 'کسی ویب سائٹ کو کھولنے سے پہلے جانچنے کے لیے۔ لنک معائنہ، کیو آر کوڈ اور مقامی جانچ دستیاب ہے۔',
    'home_education_title': 'اسکیم آگاہی مرکز',
    'home_education_desc':
        'اسکیم کے 10 اشارے، محفوظ تصدیق کے طریقے، اور انٹرایکٹو مشقیں دیکھیں۔',
    'home_education_action': 'آگاہی مرکز دیکھیں',
    'home_pause_title': 'کوئی قدم اٹھانے سے پہلے رکیں۔',
    'home_pause_desc': 'غیر متوقع پیغامات کی تصدیق ان رابطوں سے کریں جن پر آپ پہلے سے بھروسہ کرتے ہیں۔ کبھی بھی غیر تصدیق شدہ پیغام کے جواب میں پاس ورڈ یا او ٹی پی کوڈ نہ دیں۔',
    'home_safe_use_btn': 'محفوظ استعمال کی رہنمائی دیکھیں',

    // Education & Practice
    'education_title': 'اسکیم آگاہی مرکز',
    'education_subtitle': 'جانیے کہ اسکیم کے طریقے کیسے کام کرتے ہیں، ان پر توجہ دینا کیوں ضروری ہے، اور آزادانہ تصدیق کیسے کی جائے۔',
    'education_search_hint': 'آگاہی کے موضوعات تلاش کریں...',
    'education_practice_banner_title': 'محفوظ مشق کی مثالیں',
    'education_practice_banner_desc':
        'بغیر کسی خطرے کے بناوٹی پیغامات کے ذریعے اشاروں کی شناخت کی مشق کریں۔',
    'education_what_observed': 'یہ کون سا انداز یا اشارہ ہے',
    'education_why_attention': 'اس پر توجہ دینا کیوں ضروری ہے',
    'education_cannot_establish': 'یہ جانچ کیا ثابت نہیں کر سکتی',
    'education_synthetic_example': 'بناوٹی مشق کی مثال',
    'education_contrasting_example': 'عام یا جائز مثال کے ساتھ موازنہ',
    'education_contrasting_why': 'یہ اسکیم سے کیوں مختلف ہے',
    'education_verification_step': 'آزادانہ تصدیق کے عملی اقدامات',
    'education_primary_source': 'سرکاری رہنمائی کا حوالہ',
    'education_try_example_btn': 'اس مثال کے ساتھ مشق کریں',
    'education_try_example_note': 'اس بناوٹی متن کو محفوظ آف لائن جانچ کے لیے جائزہ اسکرین میں لوڈ کرتا ہے۔',
    'education_draft_replace_title': 'کیا موجودہ مسودہ تبدیل کریں؟',
    'education_draft_replace_desc': 'آپ کے پاس جائزے میں پہلے سے متن موجود ہے۔ اسے تبدیل کرنے سے آپ کا مسودہ اس تعلیمی مثال سے بدل جائے گا۔',
    'education_replace_btn': 'مسودہ تبدیل کریں',
    'education_keep_draft_btn': 'موجودہ مسودہ رکھیں',
    'education_all_topics': 'تمام 10 اشاریاتی خاندان',

    // Feedback
    'feedback_dialog_title': 'کیا یہ معلومات مفید تھیں؟',
    'feedback_disclaimer': 'ٹرسٹ کیو ایک تعلیمی ٹول ہے، کوئی قانون نافذ کرنے والا یا رپورٹنگ ادارہ نہیں۔ یہاں رائے جمع کرانے سے پولیس کو رپورٹ درج نہیں ہوگی۔',
    'feedback_rate_helpful': 'مفید',
    'feedback_rate_unhelpful': 'مفید نہیں',
    'feedback_rate_neutral': 'عام',
    'feedback_reasons_title': 'آپ کا تجربہ کیسا رہا؟',
    'feedback_comment_label': 'اضافی رائے (زیادہ سے زیادہ 200 حروف)',
    'feedback_privacy_warning':
        'پاس ورڈ، فون نمبر یا ذاتی معلومات درج نہ کریں۔',
    'feedback_save_btn': 'رائے محفوظ کریں',
    'feedback_saved_msg': 'رائے مقامی طور پر اس ڈیوائس پر محفوظ ہو گئی۔',
    'feedback_local_notice':
        'آپ کی رائے مکمل طور پر گمنام اور صرف اس ڈیوائس پر محفوظ ہوتی ہے۔',

    // Reason chips
    'feedback_chip_clear_explanation': 'واضح وضاحت',
    'feedback_chip_good_example': 'اچھی مثال',
    'feedback_chip_easy_to_verify': 'تصدیق کے آسان طریقے',
    'feedback_chip_confusing_terms': 'مشکل اصطلاحات',
    'feedback_chip_too_technical': 'بہت تکنیکی',
    'feedback_chip_example_mismatch': 'مثال غیر متعلقہ تھی',
    'feedback_chip_missing_steps': 'تصدیقی قدم کی کمی',
    'feedback_chip_other': 'دیگر',

    // Language Selector
    'language_selector_title': 'زبان کا انتخاب کریں',
    'language_notice': 'ایپ کی زبان تبدیل کرنے سے صرف انٹرفیس کے الفاظ بدلتے ہیں۔ قواعد انگریزی پیغامات کا جائزہ لیتے ہیں اور او سی آر صرف لاطینی حروف پہچانتا ہے۔ جانچے گئے پیغامات اور شواہد کو کبھی تبدیل یا ترجمہ نہیں کیا جاتا تاکہ وہ اصل حالت میں رہیں۔',
    'language_system': 'سسٹم ڈیفالٹ',
    'language_english': 'English (انگریزی)',
    'language_urdu': 'اردو (Urdu)',

    // Privacy & About
    'about_title': 'ٹرسٹ کیو کے بارے میں',
    'privacy_title': 'رازداری اور ڈیٹا کے کنٹرول',
    'privacy_feedback_title': 'مقامی گمنام رائے',
    'privacy_feedback_desc': 'اس ڈیوائس پر مقامی طور پر محفوظ کردہ مفید ہونے کی درجہ بندی اور تبصرے۔',
    'privacy_clear_feedback_btn': 'مقامی رائے کا ڈیٹا صاف کریں',
    'privacy_feedback_cleared': 'مقامی رائے کے تمام ریکارڈ صاف کر دیے گئے۔',
    'privacy_feedback_count': '@count مقامی طور پر محفوظ شدہ رائے کے اندراجات',

    // Export & Sharing
    'export_report_title': 'رپورٹ ایکسپورٹ اور شیئر کریں',
    'export_format_label': 'ایکسپورٹ فارمیٹ',
    'export_format_plain_text': 'سادہ متن (.txt)',
    'export_format_pdf': 'پی ڈی ایف (.pdf)',
    'export_include_options_title': 'شامل کی جانے والی معلومات',
    'export_include_text': 'جائزہ شدہ پیغام کا متن شامل کریں',
    'export_include_text_desc':
        'ایکسپورٹ شدہ فائل میں تجزیہ کردہ پیغام کا متن ظاہر کرتا ہے۔',
    'export_include_evidence': 'شواہد کے اقتباسات شامل کریں',
    'export_include_evidence_desc':
        'نتائج میں حوالہ دیے گئے مخصوص متنی اقتباسات ظاہر کرتا ہے۔',
    'export_include_ai': 'مصنوعی ذہانت کی وضاحتیں شامل کریں',
    'export_include_ai_desc':
        'سرور کے معاونتی تجزیے کی تفصیلی وجوہات ظاہر کرتا ہے۔',
    'export_privacy_warning': 'انتباہ: ایکسپورٹ کردہ رپورٹ حساس معلومات ظاہر کر سکتی ہے۔ صرف قابل اعتماد افراد سے شیئر کریں۔',
    'export_share_button': 'رپورٹ شیئر کریں',
    'export_copy_button': 'متن کاپی کریں',
    'export_copied_toast': 'رپورٹ کا متن کلپ بورڈ پر کاپی ہو گیا',
    'export_preview_title': 'رپورٹ کا پیش نظارہ',
    'export_generating': 'ایکسپورٹ فائل تیار ہو رہی ہے...',
    'export_sharing': 'شیئر کا آپشن کھولا جا رہا ہے...',
    'export_pdf_urdu_notice': 'پی ڈی ایف صرف لاطینی رسم الخط کو سپورٹ کرتا ہے۔ مکمل اردو رسم الخط کے لیے سادہ متن (.txt) تجویز کیا جاتا ہے۔',
    'export_action_tooltip': 'رپورٹ ایکسپورٹ یا شیئر کریں',

    // Analysis Results & Guidance (Module 50B)
    'how_to_read_results_title': 'نتائج کو سمجھنے کا طریقہ',
    'how_to_read_results_subtitle': 'ٹرسٹ کیو کے انتباہی اشاروں اور حفاظتی حدود کو سمجھنے کی مختصر رہنمائی۔',
    'help_clues_title': 'انتباہی اشارے صرف سراغ ہیں، حتمی فیصلہ نہیں',
    'help_clues_desc': 'ٹرسٹ کیو ان عمومی طریقوں کو نمایاں کرتا ہے جو دھوکہ دہی میں استعمال ہوتے ہیں۔ کسی انتباہی اشارے کا ملنا حتمی دھوکہ ثابت نہیں کرتا، اور کوئی اشارہ نہ ملنا پیغام کے محفوظ ہونے کی تصدیق نہیں کرتا۔',
    'help_no_matches_title': 'کوئی اشارہ نہ ملنا تحفظ کی ضمانت نہیں',
    'help_no_matches_desc': 'ڈیوائس پر کی جانے والی جانچ صرف مخصوص اور معلوم دھوکہ دہی کے پیٹرنز کو تلاش کرتی ہے۔ نئے طریقے، شائستہ گفتگو، یا غیر جانچے گئے فارمیٹس کسی اشارے کو متحرک نہیں کر سکتے۔',
    'help_evidence_title': 'شواہد بتاتے ہیں کہ نتیجہ کس بنیاد پر نکلا',
    'help_evidence_desc': 'ہر نتیجہ آپ کے پیغام میں موجود اصل متنی اقتباس یا لنک کی جانب اشارہ کرتا ہے تاکہ آپ مبہم اسکور پر بھروسہ کرنے کے بجائے خود وجہ دیکھ سکیں۔',
    'help_local_ai_title': 'مقامی جانچ اور کلاؤڈ AI میں فرق',
    'help_local_ai_desc': 'مقامی جانچ بغیر انٹرنیٹ کے مکمل طور پر آپ کے فون پر چلتی ہے۔ اختیاری کلاؤڈ AI صرف آپ کی واضح رضامندی کے بعد ثانوی لسانی جائزے کے لیے استعمال ہوتا ہے۔',
    'help_actions_title': 'محفوظ کرنا، بیک اپ اور ایکسپورٹ الگ الگ ہیں',
    'help_actions_desc': 'محفوظ کرنے سے رپورٹ صرف آپ کے فون کی نجی اسٹوریج میں رہتی ہے۔ اختیاری کلاؤڈ بیک اپ صرف میٹا ڈیٹا محفوظ کرتا ہے (کبھی اصل متن نہیں۔) ایکسپورٹ سے آپ فائل شیئر کر سکتے ہیں۔',
    'help_close_btn': 'سمجھ گیا',

    'outcome_indicators_found': 'ممکنہ انتباہی اشارے ملے',
    'outcome_indicators_found_single': '1 ممکنہ انتباہی اشارہ ملا',
    'outcome_no_matches': 'ڈیوائس کی جانچ میں کوئی انتباہی اشارہ نہیں ملا',
    'outcome_no_matches_calm': 'ان جانچوں میں کوئی مماثل انتباہی اشارہ نہیں ملا۔ یہ بھیجنے والے کی تصدیق نہیں کرتا اور نہ ہی یہ گارنٹی دیتا ہے کہ پیغام یا لنک محفوظ ہے۔',
    'outcome_limited_coverage': 'اس مواد کے صرف کچھ حصے کی جانچ ہو سکی',
    'outcome_check_failed': 'ہم اس جانچ کو مکمل نہیں کر سکے',

    'what_was_checked_title': 'کیا جانچا گیا',
    'checked_on_device': 'آن ڈیوائس جانچ: بغیر کسی نیٹ ورک ٹرانسفر کے 10 مقامی قواعد کے تحت جائزہ لیا گیا۔',
    'checked_url_offline': 'آف لائن لنک معائنہ: ویب ایڈریس کی ساخت کا آف لائن معائنہ کیا گیا؛ ویب سائٹ کو کھولا یا جانچا نہیں گیا۔',
    'checked_language_limits': 'زبان اور متن کی حدود: قواعد انگریزی پیغامات کا جائزہ لیتے ہیں؛ او سی آر لاطینی حروف پہچانتا ہے۔',
    'checked_cloud_ai_completed': 'کلاؤڈ AI مدد: Groq کلاؤڈ کے ذریعے ثانوی لسانی پیٹرنز کا جائزہ لیا گیا۔',
    'checked_cloud_ai_idle': 'کلاؤڈ AI مدد: درخواست نہیں کی گئی۔ صرف ڈیوائس کی مقامی جانچ کی گئی۔',
    'checked_cloud_ai_failed': 'کلاؤڈ AI مدد: مکمل نہیں ہو سکی۔ آپ کے مقامی نتائج مکمل اور محفوظ ہیں۔',

    'technical_details_title': 'تکنیکی تفصیلات اور قواعد کے آفسیٹس',
    'show_technical_details': 'تکنیکی تفصیلات دیکھیں',
    'hide_technical_details': 'تکنیکی تفصیلات چھپائیں',
    'cloud_summary_no_text_notice': 'آپ کی رازداری کے تحفظ کے لیے کلاؤڈ بیک اپ میں اصل پیغام کا متن اور شواہد شامل نہیں کیے جاتے۔ صرف میٹا ڈیٹا (تاریخ، ماخذ اور زمرہ جات) مطابقت پذیر کیا جاتا ہے۔',
  };
}
