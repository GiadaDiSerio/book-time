import 'package:flutter/material.dart';
import 'app_state.dart';

/// Mostra il dialog delle impostazioni: lingua dei risultati e tema dell'app.
void showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            title: const Text('Impostazioni'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lingua dei risultati:'),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  value: appState.languageCode,
                  items: const [
                    DropdownMenuItem(value: 'ita', child: Text('Italiano')),
                    DropdownMenuItem(value: 'eng', child: Text('English')),
                    DropdownMenuItem(value: 'spa', child: Text('Español')),
                    DropdownMenuItem(value: 'fre', child: Text('Français')),
                    DropdownMenuItem(value: 'ger', child: Text('Deutsch')),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      appState.setLanguageCode(newValue);
                      setStateDialog(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Tema dell\'app:'),
                const SizedBox(height: 8),
                DropdownButton<ThemeMode>(
                  isExpanded: true,
                  value: appState.themeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Chiaro')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Scuro')),
                  ],
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      appState.setThemeMode(newValue);
                      setStateDialog(() {});
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CHIUDI'),
              ),
            ],
          );
        }
      );
    },
  );
}
