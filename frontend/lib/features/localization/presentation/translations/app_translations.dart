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
    'export_privacy_warning':
        'Warning: Exported reports may expose sensitive communication. Only share with parties you trust.',
    'export_share_button': 'Share Report',
    'export_copy_button': 'Copy Text',
    'export_copied_toast': 'Report copied to clipboard',
    'export_preview_title': 'Report Preview',
    'export_generating': 'Preparing export file...',
    'export_sharing': 'Opening share sheet...',
    'export_pdf_urdu_notice':
        'PDF uses Latin typography. Plain Text (.txt) is recommended for full Urdu and non-Latin script fidelity.',
    'export_action_tooltip': 'Export or Share Report',
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
    'export_privacy_warning':
        'انتباہ: ایکسپورٹ کردہ رپورٹ حساس معلومات ظاہر کر سکتی ہے۔ صرف قابل اعتماد افراد سے شیئر کریں۔',
    'export_share_button': 'رپورٹ شیئر کریں',
    'export_copy_button': 'متن کاپی کریں',
    'export_copied_toast': 'رپورٹ کا متن کلپ بورڈ پر کاپی ہو گیا',
    'export_preview_title': 'رپورٹ کا پیش نظارہ',
    'export_generating': 'ایکسپورٹ فائل تیار ہو رہی ہے...',
    'export_sharing': 'شیئر کا آپشن کھولا جا رہا ہے...',
    'export_pdf_urdu_notice':
        'پی ڈی ایف صرف لاطینی رسم الخط کو سپورٹ کرتا ہے۔ مکمل اردو رسم الخط کے لیے سادہ متن (.txt) تجویز کیا جاتا ہے۔',
    'export_action_tooltip': 'رپورٹ ایکسپورٹ یا شیئر کریں',
  };
}
