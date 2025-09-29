import 'dart:math';
import 'package:ring_react_game/widgets/ring_layer.dart';
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

  final double maxBallSpeed = 0.2;
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
      // ✅ play sound before state update
      ref.read(audioServiceProvider).playTap();

      setState(() {
        score++;
        ballSpeed = (ballSpeed + 0.001).clamp(0.0, maxBallSpeed);
        safeSweep = max(minSafeSweep, safeSweep - 0.010);
        safeStart = Random().nextDouble() * 2 * pi;
      });

      // ✅ play "level up" outside of setState
      if (score % 10 == 0 && score > 0) {
        Future.microtask(() {
          ref.read(audioServiceProvider).playLevelUp();
        });
      }
    } else {
      // ✅ play lose sound first
      ref.read(audioServiceProvider).playLose();

      setState(() {
        isGameOver = true;
      });

      // Show game over + name if high score
      _showGameOverDialog();
    }
  }

  void _restart() {
    if (!mounted) return;
    setState(() {
      score = 0;
      ballSpeed = 0.03;
      safeSweep = pi / 3;
      safeStart = Random().nextDouble() * 2 * pi;
      isGameOver = false;
    });
  }

  void _restartSafely() {
    // separated restart logic so we never call restart inside a setState in unwanted places
    if (!mounted) return;
    setState(() {
      score = 0;
      ballSpeed = 0.03;
      safeSweep = pi / 3;
      safeStart = Random().nextDouble() * 2 * pi;
      isGameOver = false;
    });
  }

  // _resumeFromCheckpoint was removed because it was unused.

  Future<void> _watchAdAndContinue() async {
    if (isAdLoading) return;
    if (!mounted) return;

    setState(() => isAdLoading = true);

    bool rewarded = false;
    try {
      // showRewardedAd internally handles retries/timeouts
      final result = await AdsService.instance.showRewardedAd();
      // Support both Future<bool> and Future<void> (result will be null in that case)
      rewarded = result == true;
      debugPrint('[Game] showRewardedAd returned: $rewarded');
    } catch (e, st) {
      debugPrint('[Game] Error while showing rewarded ad: $e\n$st');
      rewarded = false;
    } finally {
      // Ensure loading state is cleared even if an error occurs or we return early.
      if (mounted) {
        setState(() => isAdLoading = false);
      }
    }

    if (!mounted) return;

    if (rewarded) {
      // ✅ Continue the game without restarting
      if (mounted) {
        setState(() {
          isGameOver = false;
        });
      }
    } else {
      // ❌ Ad failed or skipped → notify and fallback to restart
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not available. Restarting the game...'),
            duration: Duration(seconds: 2),
          ),
        );

        // Wait a little so the SnackBar is visible
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;
        _restartSafely();
      }
    }
  }

  String generateGameCode() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = (now.year % 100).toString().padLeft(2, '0'); // last 2 digits

    return "#$hour$minute$day$month$year";
  }

  void _showGameOverDialog() async {
    final prefsState = ref.read(prefsNotifierProvider);
    final themeMode = prefsState.themeMode;

    // Determine if this is a new high score
    final isNewRecord = score > prefsState.highScore;

    final Brightness platformBrightness = MediaQuery.of(
      context,
    ).platformBrightness;
    final isDark = themeMode == ThemeMode.system
        ? platformBrightness == Brightness.dark
        : themeMode == ThemeMode.dark;

    String? playerName;

    // Capture context before any `await` to avoid async gaps
    final BuildContext dialogContext = context;

    // Ask for name if it's a new record
    if (isNewRecord) {
      final prefsState = ref.read(prefsNotifierProvider);
      final nameController = TextEditingController(
        text: prefsState.highScoreName,
      );
      if (!mounted) return;
      playerName = await showDialog<String>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) SystemNavigator.pop();
            },
            child: AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              title: const Text("New High Score! 🎉"),
              content: TextField(
                autofocus: true,
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Enter your name",
                  hintText: "Player123",
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop(
                        nameController.text.trim().isEmpty
                            ? "Player"
                            : nameController.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.blue.shade300
                          : Colors.blue.shade500,
                    ),
                    child: Text(
                      "Save",
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (playerName != null && mounted) {
        ref
            .read(prefsNotifierProvider.notifier)
            .setHighScore(score, playerName);
      }
    }

    // Schedule the main Game Over dialog to run on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) SystemNavigator.pop();
            },
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      generateGameCode(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Icon(
                      isNewRecord
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied,
                      size: 54,
                      color: isNewRecord
                          ? Colors.amberAccent.shade400
                          : isDark
                          ? Colors.red[400]
                          : Colors.redAccent,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isNewRecord ? 'New High Score!' : 'Game Over',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your Score: $score',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                                : [
                                    Colors.green.shade400,
                                    Colors.green.shade800,
                                  ],
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
                              isAdLoading
                                  ? 'Loading...'
                                  : 'Watch Ad to Continue',
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
                        label: const Text(
                          'Restart',
                          style: TextStyle(fontSize: 16),
                        ),
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
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
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
                    prefsState.highScore == 0
                        ? 'No High Score'
                        : 'High Score: $highScore | ${prefsState.highScoreName}',
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
                const SizedBox(height: 10),
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
                        Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Animated ring layer
                                RingLayer(
                                  size: size,
                                  safeStart: safeStart,
                                  safeSweep: safeSweep,
                                  isGameOver: isGameOver,
                                  isDark: isDark,
                                  strokeWidth: 40,
                                ),

                                // Ball — cheap repaint every tick
                                SizedBox(
                                  width: size,
                                  height: size,
                                  child: CustomPaint(
                                    painter: BallPainter(
                                      ballAngle: ballAngle,
                                      isDark: isDark,
                                      strokeWidth: 40,
                                    ),
                                  ),
                                ),

                                // Score + instructions
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$score',
                                      style: TextStyle(
                                        fontSize: 50,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Tap when it's green",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
