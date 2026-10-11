import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';

/// Screen allowing users to enter, validate, normalize, and prepare suspicious
/// message text locally without performing network requests or analysis.
class InputTextScreen extends GetView<InputTextController> {
  const InputTextScreen({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (controller.focusNode.hasFocus) {
      controller.focusNode.unfocus();
    }
    if (controller.hasDraft) {
      final shouldDiscard = await controller.confirmDiscard(context);
      if (!shouldDiscard) return;
    }
    if (!context.mounted) return;
    controller.isNavigatingAway.value = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final canDirectlyPop =
          Navigator.of(context).canPop() &&
          (!controller.hasDraft || controller.isNavigatingAway.value);

      return PopScope(
        canPop: canDirectlyPop,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Message text'),
            leading: BackButton(onPressed: () => _handleBack(context)),
          ),
          body: AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                Text(
                  'Type or paste the message you want to review.',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'For messages copied from SMS, email, or chat.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.pagePaddingLarge),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Text preparation is available. Scam analysis is not available in this build yet.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.pagePaddingLarge),
                AppTextField(
                  label: 'Message',
                  hint: 'Paste or type suspicious message text here',
                  helperText: 'Never include passwords, PINs, or one-time verification codes.',
                  errorText: controller.validationError.value?.message,
                  counterText: controller.characterCountText,
                  controller: controller.textEditingController,
                  focusNode: controller.focusNode,
                  multiline: true,
                  minLines: 5,
                  maxLines: 12,
                ),
                if (controller.showPreparedConfirmation.value) ...[
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Text prepared on this device. It has not been analyzed or sent anywhere.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.pagePaddingLarge),
                AppButton.primary(
                  label: 'Prepare text',
                  onPressed: controller.isPreparationDisabled
                      ? null
                      : () => controller.prepareText(),
                ),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                AppButton.secondary(
                  label: 'Clear text',
                  onPressed: controller.isClearDisabled
                      ? null
                      : () => controller.requestClearText(context),
                ),
                const SizedBox(height: AppSpacing.pagePaddingLarge),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety reminder',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review suspicious messages without clicking links or sharing verification codes.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                AppButton.secondary(
                  label: 'Review safe-use guidance',
                  onPressed: () {
                    if (Get.currentRoute != AppRoutes.guidance) {
                      Get.toNamed(AppRoutes.guidance);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
