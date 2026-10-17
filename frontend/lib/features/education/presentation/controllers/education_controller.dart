import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/category_educational_catalog.dart';
import 'package:trustcue_mobile/features/education/domain/models/educational_topic.dart';
import 'package:trustcue_mobile/features/education/presentation/widgets/draft_replacement_dialog.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';

/// Presentation controller managing the Scam Education Center and Safe Practice Examples.
class EducationController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<EducationalTopic> allTopics = <EducationalTopic>[].obs;

  @override
  void onInit() {
    super.onInit();
    allTopics.value = CategoryEducationalCatalog.getAllTopics();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.onClose();
  }

  void _onSearchChanged() {
    searchQuery.value = searchController.text.trim();
  }

  /// Filtered topics based on user search query.
  List<EducationalTopic> get filteredTopics {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) return allTopics;

    return allTopics.where((topic) {
      return topic.title.toLowerCase().contains(query) ||
          topic.whatObserved.toLowerCase().contains(query) ||
          topic.syntheticSuspiciousExample.toLowerCase().contains(query) ||
          topic.categoryId.toLowerCase().contains(query);
    }).toList();
  }

  /// Loads an educational synthetic example into the review input flow.
  ///
  /// Invariants:
  /// - Checks whether the user already has an active, non-empty draft.
  /// - If an active draft exists, prompts for explicit confirmation before replacing.
  /// - If confirmed or if no draft exists, populates the example text into [InputTextController].
  /// - Strictly user-triggered: does NOT automatically execute local analysis,
  ///   does NOT upload to AI, does NOT save to SQLite history, and does NOT sync to cloud.
  Future<void> practiceWithExample(
    EducationalTopic topic,
    BuildContext context,
  ) async {
    final exampleText = topic.syntheticSuspiciousExample;

    if (Get.isRegistered<InputTextController>()) {
      final inputController = Get.find<InputTextController>();
      if (inputController.text.value.trim().isNotEmpty) {
        final confirmed = await DraftReplacementDialog.show(context);
        if (!confirmed) {
          return;
        }
      }
      inputController.populateSharedText(exampleText);
      if (Get.currentRoute != AppRoutes.inputText) {
        Get.toNamed(AppRoutes.inputText);
      }
    } else {
      Get.toNamed(AppRoutes.inputText, arguments: {'sharedText': exampleText});
    }
  }
}
