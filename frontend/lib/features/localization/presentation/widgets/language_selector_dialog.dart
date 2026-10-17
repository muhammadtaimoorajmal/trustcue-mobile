// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';
import 'package:trustcue_mobile/features/localization/presentation/controllers/localization_controller.dart';

/// Modal dialog allowing the user to select their preferred interface language.
class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const LanguageSelectorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.isRegistered<LocalizationController>()
        ? Get.find<LocalizationController>()
        : Get.put(LocalizationController());

    return AlertDialog(
      title: Text(
        'language_selector_title'.tr,
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final selected = controller.currentLanguage.value;
              return Column(
                children: AppLanguage.values.map((lang) {
                  final isSelected = selected == lang;
                  return RadioListTile<AppLanguage>(
                    value: lang,
                    groupValue: selected,
                    title: Text(
                      lang == AppLanguage.system
                          ? 'language_system'.tr
                          : lang == AppLanguage.english
                          ? 'language_english'.tr
                          : 'language_urdu'.tr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        controller.changeLanguage(val);
                      }
                    },
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'language_notice'.tr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton.secondary(
          label: 'close'.tr,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
