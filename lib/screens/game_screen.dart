import 'dart:math';
import 'package:ring_react_game/widgets/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ads_service.dart';
import '../widgets/ring_painter.dart';
import '../services/prefs_service.dart'; // provider is here
import '../services/audio_service.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  double ballAngle = 0.0;
  double safeStart = pi / 4;
  double safeSweep = pi / 3;
  double ballSpeed = 0.03;
  int score = 0;
  bool isGameOver = false;
  bool isAdLoading = false;

  final double maxBallSpeed = 0.15;
  final double minSafeSweep = pi / 5;

  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Load all ads
    AdsService.instance.loadInterstitialAd(
      onLoaded: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AdsService.instance.showInterstitialAd();
        });
      },
    );
    AdsService.instance.loadRewardedAd();
    AdsService.instance.loadBannerAd();

    _ticker = AnimationController(vsync: this);
    _ticker.addListener(_onTick);
    _ticker.repeat(period: const Duration(milliseconds: 16));
  }

  void _onTick() {
    if (!isGameOver) {
      setState(() {
        ballAngle += ballSpeed;
        if (ballAngle > 2 * pi) ballAngle -= 2 * pi;
      });
    }
  }

  bool _ballInSafe() {
    double norm = (ballAngle - safeStart) % (2 * pi);
    if (norm < 0) norm += 2 * pi;
    return norm <= safeSweep;
  }

  void _handleTap() {
    if (isGameOver) return;
    if (_ballInSafe()) {
      ref.read(audioServiceProvider).playTap();
      setState(() {
        score++;
        ballSpeed = (ballSpeed + 0.001).clamp(0.0, maxBallSpeed);
        safeSweep = max(minSafeSweep, safeSweep - 0.010);
        safeStart = Random().nextDouble() * 2 * pi;
      });
      // Play level up sound every time difficulty increases
      if (score % 10 == 0 && score > 0) {
        ref.read(audioServiceProvider).playLevelUp();
      }
      // Update high score via Riverpod notifier if needed
      final prefsState = ref.read(prefsNotifierProvider);
      if (score > prefsState.highScore) {
        ref.read(prefsNotifierProvider.notifier).setHighScore(score);
      }
    } else {
      setState(() {
        isGameOver = true;
      });
      ref.read(audioServiceProvider).playLose();
      _showGameOverDialog();
    }
  }

  void _restart() {
    setState(() {
      score = 0;
      ballSpeed = 0.03;
      safeSweep = pi / 3;
      safeStart = Random().nextDouble() * 2 * pi;
      isGameOver = false;
    });
  }

  Future<void> _watchAdAndContinue() async {
    if (isAdLoading) return;
    setState(() => isAdLoading = true);

    final rewarded = await AdsService.instance.showRewardedAd();

    if (rewarded == true) {
      setState(() {
        isGameOver = false;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not available right now. Try later.')),
      );
    }
    if (mounted) {
      setState(() => isAdLoading = false);
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final prefsState = ref.read(prefsNotifierProvider);
        final themeMode = prefsState.themeMode;
        final Brightness platformBrightness = MediaQuery.of(
          context,
        ).platformBrightness;
        final isDark = themeMode == ThemeMode.system
            ? platformBrightness == Brightness.dark
            : themeMode == ThemeMode.dark;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              SystemNavigator.pop();
            }
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  Icon(
                    Icons.sentiment_dissatisfied,
                    size: 54,
                    color: isDark ? Colors.red[400] : Colors.redAccent,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Game Over',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Score: $score',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  Colors.greenAccent.shade400,
                                  Colors.green.shade700,
                                ]
                              : [Colors.green.shade400, Colors.green.shade800],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isAdLoading
                            ? null
                            : () async {
                                if (mounted) {
                                  Navigator.of(ctx).pop();
                                  await _watchAdAndContinue();
                                }
                              },
                        icon: isAdLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_circle_fill, size: 26),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            isAdLoading ? 'Loading...' : 'Watch Ad to Continue',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        if (mounted) {
                          Navigator.of(ctx).pop();
                          _restart();
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('Restart', style: TextStyle(fontSize: 16)),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Unlock orientation when disposing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(prefsNotifierProvider);
    final themeMode = prefsState.themeMode;
    final highScore = prefsState.highScore;
    final Brightness platformBrightness = MediaQuery.of(
      context,
    ).platformBrightness;
    final bool isDark = themeMode == ThemeMode.system
        ? platformBrightness == Brightness.dark
        : themeMode == ThemeMode.dark;

    final bgGradient = isDark
        ? const LinearGradient(colors: [Color(0xFF0F1724), Color(0xFF0B1220)])
        : const LinearGradient(colors: [Color(0xFFE8F0FF), Color(0xFFF8FAFF)]);
    final size = MediaQuery.of(context).size.width * 0.8;

    // Difficulty levels
    final difficulties = [
      {'text': 'Beginner', 'emoji': '🐣'},
      {'text': 'Easy', 'emoji': '😊'},
      {'text': 'Casual', 'emoji': '🙂'},
      {'text': 'Normal', 'emoji': '😎'},
      {'text': 'Challenging', 'emoji': '😏'},
      {'text': 'Hard', 'emoji': '😤'},
      {'text': 'Very Hard', 'emoji': '🔥'},
      {'text': 'Insane', 'emoji': '😱'},
      {'text': 'Extreme', 'emoji': '🤯'},
      {'text': 'Impossible', 'emoji': '😈'},
      {'text': 'G.O.A.T', 'emoji': '💀'},
      {'text': 'Beyond Reality', 'emoji': '👽'},
      {'text': 'Ultra Instinct', 'emoji': '🐉'},
    ];

    final difficultyIndex = ((score ~/ 10)).clamp(0, difficulties.length - 1);
    final difficultyText = difficulties[difficultyIndex]['text']!;
    final emoji = difficulties[difficultyIndex]['emoji']!;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'High Score: $highScore',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor:
              Theme.of(context).appBarTheme.foregroundColor ??
              (isDark ? Colors.white : Colors.black),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                showSettingsMenu(context, ref);
              },
            ),
          ],
        ),

        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(gradient: bgGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 10),
                Text(
                  '$emoji $difficultyText',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),

                Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ring and score
                        CustomPaint(
                          size: Size(size, size),
                          painter: RingPainter(
                            ballAngle: ballAngle,
                            safeStart: safeStart,
                            safeSweep: safeSweep,
                            isGameOver: isGameOver,
                            isDark: isDark,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap when it\'s green',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 80,
                  child: AdsService.instance.getBannerAd(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
