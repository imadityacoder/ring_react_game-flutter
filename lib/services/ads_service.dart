import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  AdsService._private();
  static final AdsService instance = AdsService._private();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _isLoading = false;

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1128782780487258/8532632457'; // test ID
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1128782780487258/9607725186'; // test ID
    }
    return '';
  }

  String get rewardedAdUnitId {
    // Use test ID for Android
    if (Platform.isAndroid) {
      return 'ca-app-pub-1128782780487258/7219550781'; // test ID
    }
    return ''; // No ads for iOS or other platforms
  }

  void loadRewardedAd() {
    if (!Platform.isAndroid) return; // Only load on Android
    if (_rewardedAd != null || _isLoading) return;

    _isLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (err) {
          _isLoading = false;
          _rewardedAd = null;
          print("Failed to load rewarded ad: ${err.message}");
        },
      ),
    );
  }

  Future<bool> showRewardedAd({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    if (!Platform.isAndroid) return false; // No ads for iOS or other

    int attempt = 0;
    while (attempt < maxRetries) {
      if (_rewardedAd == null) {
        loadRewardedAd();
        await Future.delayed(retryDelay);
        attempt++;
        continue;
      }

      final completer = Completer<bool>();

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          if (!completer.isCompleted) completer.complete(false);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem r) {
          if (!completer.isCompleted) completer.complete(true);
        },
      );

      // Wait for ad result or timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
      if (result) return true;
      // If ad failed, retry
      attempt++;
      await Future.delayed(retryDelay);
    }
    return false;
  }

  // Banner Ad Methods
  void loadBannerAd() {
    if (!Platform.isAndroid) return;
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {},
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _bannerAd = null;
          print("Failed to load banner ad: ${err.message}");
        },
      ),
    )..load();
  }

  Widget getBannerAd() {
    if (_bannerAd == null || !Platform.isAndroid) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  // Interstitial Ad Methods
  void loadInterstitialAd({VoidCallback? onLoaded}) {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint("Interstitial not ready yet");
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
  }
}
