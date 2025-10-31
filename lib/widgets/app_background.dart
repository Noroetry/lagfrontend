import 'package:flutter/material.dart';
import 'package:lagfrontend/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:lagfrontend/config/app_config.dart';

class AppBackground extends StatefulWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  bool _assetExists = false;

  @override
  void initState() {
    super.initState();
    _checkAsset();
  }

  Future<void> _checkAsset() async {
    final path = AppConfig.backgroundImagePath;
    if (path.isEmpty) return;
    try {
      await rootBundle.load(path);
      // ignore: avoid_print
      debugPrint('✅ AppBackground: asset FOUND: $path');
      setState(() => _assetExists = true);
    } catch (e) {
      // ignore: avoid_print
      debugPrint('❌ AppBackground: asset NOT FOUND: $path -> $e');
      setState(() => _assetExists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgPath = AppConfig.backgroundImagePath;
    final fallback = Container(color: AppColors.background);

    Widget backgroundWidget;
    if (bgPath.isEmpty || !_assetExists) {
      backgroundWidget = fallback;
    } else {
      backgroundWidget = Positioned.fill(
        child: Image.asset(
          bgPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stack) {
            debugPrint('⚠️ AppBackground: failed to load $bgPath: $error');
            return fallback;
          },
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          backgroundWidget,
          // NOTE: removed the fixed dark overlay so the configured
          // AppColors.background (very-dark-gray) is visible behind
          // popups. If you want a subtle fog, consider using a
          // translucent AppColors.fog1/2 or enable this conditionally.
          widget.child,
        ],
      ),
    );
  }
}
