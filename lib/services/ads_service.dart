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

  // // test ads unit IDs
  //   String get bannerAdUnitId {
  //     if (Platform.isAndroid) {
  //       return 'ca-app-pub-3940256099942544/9214589741'; // test ID
  //     }
  //     return '';
  //   }

  //   String get interstitialAdUnitId {
  //     if (Platform.isAndroid) {
  //       return 'ca-app-pub-3940256099942544/1033173712'; // test ID
  //     }
  //     return '';
  //   }

  //   String get rewardedAdUnitId {
  //     // Use test ID for Android
  //     if (Platform.isAndroid) {
  //       return 'ca-app-pub-3940256099942544/5224354917'; // test ID
  //     }
  //     return ''; // No ads for iOS or other platforms
  //   }

  // Real ads unit IDs (uncomment when ready for production)
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1128782780487258/1472060113'; // real ID
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1128782780487258/8592728581'; // real ID
    }
    return '';
  }

  String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1128782780487258/7955090872'; // real ID
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
        },
      ),
    );
  }

  Future<bool> showRewardedAd({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    if (!Platform.isAndroid) return false;

    int attempt = 0;

    while (attempt < maxRetries) {
      if (_rewardedAd == null) {
        debugPrint("[Ads] Rewarded Ad not ready, loading...");
        loadRewardedAd();
        await Future.delayed(retryDelay);
        attempt++;
        continue;
      }

      final completer = Completer<bool>();
      bool earnedReward = false; // track reward status

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint("[Ads] Rewarded Ad shown");
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint("[Ads] Rewarded Ad dismissed");
          // Delay slightly to allow onUserEarnedReward to arrive in case the
          // SDK fires dismissal before reward callback on some devices/versions.
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!completer.isCompleted) {
              debugPrint(
                "[Ads] Completing on dismiss with earnedReward=$earnedReward",
              );
              completer.complete(earnedReward);
            }
          });

          _rewardedAd = null;
          ad.dispose();
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          debugPrint("[Ads] Rewarded Ad failed to show: ${err.message}");
          if (!completer.isCompleted) completer.complete(false);

          _rewardedAd = null;
          ad.dispose();
          loadRewardedAd();
        },
        onAdImpression: (ad) {
          debugPrint("[Ads] Rewarded Ad impression recorded");
        },
        onAdClicked: (ad) {
          debugPrint("[Ads] Rewarded Ad clicked");
        },
      );

      try {
        _rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            debugPrint(
              "[Ads] User earned reward: ${reward.amount} ${reward.type}",
            );
            earnedReward = true;
            if (!completer.isCompleted) completer.complete(true);
          },
        );

        // Wait for reward or dismissal
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint("[Ads] Rewarded Ad timeout");
            return false;
          },
        );

        if (result) return true;
      } catch (e) {
        debugPrint("[Ads] Exception showing Rewarded Ad: $e");
      }

      attempt++;
      await Future.delayed(retryDelay);
    }

    debugPrint("[Ads] Rewarded Ad failed after $maxRetries attempts");
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
          debugPrint("Failed to load banner ad: ${err.message}");
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
      adUnitId: interstitialAdUnitId,
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
