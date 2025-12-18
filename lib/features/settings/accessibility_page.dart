import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';

class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Accessibility")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: themeService.themeMode == ThemeMode.dark ||
                (themeService.themeMode == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) ==
                        Brightness.dark),
            onChanged: (val) {
              themeService.toggleTheme(val);
            },
          ),
          const Divider(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
                "Font Size Scaling (${themeService.textScaleFactor.toStringAsFixed(1)}x)",
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Slider(
            value: themeService.textScaleFactor,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            label: themeService.textScaleFactor.toString(),
            onChanged: (val) {
              themeService.updateTextScale(val);
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Adjust the slider to increase or decrease the text size across the entire application.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
