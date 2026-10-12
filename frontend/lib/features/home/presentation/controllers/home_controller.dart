import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';

class HomeController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<IncomingShareCoordinator>()) {
        Get.find<IncomingShareCoordinator>().presentPendingShare();
      }
    });
  }
}
