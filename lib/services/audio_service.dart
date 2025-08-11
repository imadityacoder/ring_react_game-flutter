import 'package:audioplayers/audioplayers.dart';
import 'package:ring_react_game/services/prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  factory AudioService() => instance;
  AudioService._internal();

  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _musicOn = true;

  bool get musicOn => _musicOn;

  /// Called from a provider to sync with prefs
  void updateMusicSetting(bool value) {
    _musicOn = value;
  }

  Future<void> playLevelUp() async {
    if (!_musicOn) return;
    await _effectPlayer.play(AssetSource('audio/levelup.mp3'));
  }

  Future<void> playLose() async {
    if (!_musicOn) return;
    await _effectPlayer.play(AssetSource('audio/lose.mp3'));
  }

  Future<void> playTap() async {
    if (!_musicOn) return;
    await _effectPlayer.play(AssetSource('audio/tap.mp3'));
  }
}

/// Listens to prefsNotifierProvider.musicOn and updates AudioService automatically
final audioServiceProvider = Provider<AudioService>((ref) {
  final musicOn = ref.watch(prefsNotifierProvider).musicOn;
  AudioService.instance.updateMusicSetting(musicOn);
  return AudioService.instance;
});
