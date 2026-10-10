import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';

void main() {
  runApp(const ComponentPreviewApp());
}

class ComponentPreviewApp extends StatelessWidget {
  const ComponentPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustCue — Component Preview',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const ComponentPreviewScreen(),
    );
  }
}

class ComponentPreviewScreen extends StatefulWidget {
  const ComponentPreviewScreen({super.key});

  @override
  State<ComponentPreviewScreen> createState() => _ComponentPreviewScreenState();
}

class _ComponentPreviewScreenState extends State<ComponentPreviewScreen> {
  bool _isLoading = false;
  String? _sampleError;
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleLoading() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _toggleError() {
    setState(() {
      if (_sampleError == null) {
        _sampleError =
            'This is a synthetic sample error message demonstrating wrapping.';
      } else {
        _sampleError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrustCue — Component Preview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Buttons', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            AppButton.primary(
              label: 'Primary Button',
              isLoading: _isLoading,
              onPressed: () => _showFeedback('Primary pressed'),
            ),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'Secondary Button',
              isLoading: _isLoading,
              onPressed: () => _showFeedback('Secondary pressed'),
            ),
            const SizedBox(height: 16),
            const AppButton.primary(label: 'Disabled Primary', onPressed: null),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'Toggle Loading State',
              icon: Icons.sync,
              onPressed: _toggleLoading,
            ),
            const SizedBox(height: 32),
            Text(
              'Text Fields',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Standard Input',
              hint: 'Enter some synthetic text',
              helperText: 'Helper text can guide the user. It can also wrap if it gets too long for a single line on smaller screens.',
              controller: _textController,
              errorText: _sampleError,
            ),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'Toggle Error State',
              onPressed: _toggleError,
            ),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Multiline Input',
              hint: 'Type a lot of text here...',
              multiline: true,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 32),
            Text('Cards', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Short Content Card',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('This card has a small amount of text.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Long Content Card',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This card demonstrates how longer content flows within the padded surface. The padding is consistent, and the card expands vertically to fit the content, respecting the established design language. It remains non-interactive.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
