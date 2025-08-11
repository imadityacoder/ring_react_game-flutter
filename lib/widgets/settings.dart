import 'package:ring_react_game/services/audio_service.dart';
import 'package:ring_react_game/services/prefs_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void showSettingsMenu(BuildContext context, WidgetRef ref) {
  final prefs = ref.watch(prefsNotifierProvider);

  showDialog(
    context: context,
    barrierColor: Colors.black26,
    builder: (ctx) {
      return _SettingsDialog(
        initialThemeMode: prefs.themeMode,
        initialMusicOn: prefs.musicOn,
        onThemeModeChanged: (mode) {
          ref.read(prefsNotifierProvider.notifier).setThemeMode(mode);
        },
        onMusicToggle: (value) {
          ref.read(prefsNotifierProvider.notifier).setMusicOn(value);
          ref.read(audioServiceProvider).updateMusicSetting(value);
        },
      );
    },
  );
}

class _SettingsDialog extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool initialMusicOn;
  final ValueChanged<bool> onMusicToggle;

  const _SettingsDialog({
    required this.initialThemeMode,
    required this.onThemeModeChanged,
    required this.initialMusicOn,
    required this.onMusicToggle,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late ThemeMode currentThemeMode;
  late bool currentMusicOn;

  @override
  void initState() {
    super.initState();
    currentThemeMode = widget.initialThemeMode;
    currentMusicOn = widget.initialMusicOn;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = currentThemeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
              ? Colors.white
              : Colors.black
        : currentThemeMode == ThemeMode.dark
        ? Colors.white
        : Colors.black;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeOption(
              Icons.brightness_auto,
              'System Theme',
              ThemeMode.system,
              textColor,
            ),
            _themeOption(
              Icons.light_mode,
              'Light Mode',
              ThemeMode.light,
              textColor,
            ),
            _themeOption(
              Icons.dark_mode,
              'Dark Mode',
              ThemeMode.dark,
              textColor,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      currentMusicOn ? Icons.music_note : Icons.music_off,
                      color: textColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentMusicOn ? 'Music On' : 'Music Off',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: currentMusicOn,
                  onChanged: (value) {
                    setState(() => currentMusicOn = value);
                    widget.onMusicToggle(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: textColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(
    IconData icon,
    String label,
    ThemeMode mode,
    Color textColor,
  ) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(label, style: TextStyle(color: textColor)),
      trailing: Radio<ThemeMode>(
        value: mode,
        groupValue: currentThemeMode,
        onChanged: (val) {
          if (val == null) return;
          setState(() => currentThemeMode = val);
          widget.onThemeModeChanged(val);
        },
      ),
    );
  }
}
