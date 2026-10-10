import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About TrustCue',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48), // Ensure touch target
            onPressed: () {
              // Rapid repeated taps shouldn't stack duplicate pages
              if (Get.currentRoute != AppRoutes.about) {
                Get.toNamed(AppRoutes.about);
              }
            },
          ),
        ],
      ),
      body: AppPageBody(
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'You have pushed the button this many times:',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Obx(
                  () => Text(
                    '${controller.counter}',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
