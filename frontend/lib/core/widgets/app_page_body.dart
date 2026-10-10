import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';

class AppPageBody extends StatelessWidget {
  final Widget child;

  const AppPageBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double currentWidth = constraints.maxWidth;
        final double horizontalPadding =
            currentWidth >= AppSpacing.responsiveBreakpoint
            ? AppSpacing.pagePaddingLarge
            : AppSpacing.pagePaddingSmall;

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              key: const Key('app_page_body_constrained_box'),
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: AppSpacing.pagePaddingSmall,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
