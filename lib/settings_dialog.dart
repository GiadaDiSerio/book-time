import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

/// Mostra il dialog delle impostazioni: lingua dei risultati e tema dell'app.
void showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          final appState = dialogCtx.watch<AppState>();
          return AlertDialog(
            title: const Text('Impostazioni'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      dialogCtx.read<AppState>().setThemeMode(newValue);
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
