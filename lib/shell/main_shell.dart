import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/storage/data_folder_settings_service.dart';
import 'package:personal/features/app_update/app_update_dialog.dart';
import 'package:personal/features/app_update/app_update_service.dart';
import 'package:personal/features/dashboard/predictions/predictions_screen.dart';
import 'package:personal/features/dashboard/ui/dashboard_screen.dart';
import 'package:personal/features/home/home_screen.dart';
import 'package:personal/features/onboarding/onboarding_screen.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shell/app_drawer.dart';
import 'package:personal/shell/widgets/glass_bottom_nav_bar.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  GlassNavItem _selected = GlassNavItem.home;
  int _slideDirection = 0;
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowOnboarding();
      await _checkForAppUpdate();
    });
  }

  /// Silent on failure (offline, rate-limited): updates are best-effort.
  Future<void> _checkForAppUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      final service = AppUpdateService();
      final update = await service.checkForUpdate();
      if (update == null || !mounted) return;
      await showAppUpdateDialog(context, service, update);
    } catch (_) {}
  }

  /// First run only, and only while setup is actually incomplete.
  Future<void> _maybeShowOnboarding() async {
    if (await onboardingSeen() || !mounted) return;
    final folder = await ref.read(dataFolderSettingsProvider.future);
    final config = await ref.read(promptConfigProvider.future);
    if (!mounted) return;
    if (folder.hasFolder && config.isPersonalInfoComplete) {
      await markOnboardingSeen();
      return;
    }
    await Navigator.of(
      context,
    ).push(FadeScalePageRoute<void>(page: const OnboardingScreen()));
  }

  static const _transitionDuration = Duration(milliseconds: 220);
  static const _drawerDuration = Duration(milliseconds: 250);

  void _openDrawer() => setState(() => _drawerOpen = true);

  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _onTabSelected(GlassNavItem item) {
    if (item == _selected) return;
    HapticFeedback.selectionClick();
    setState(() {
      _slideDirection = item.index.compareTo(_selected.index);
      _selected = item;
    });
  }

  PreferredSizeWidget _appBarForTab(GlassNavItem item) {
    return AppScreenAppBar.build(
      context,
      ref,
      title: switch (item) {
        GlassNavItem.home => 'Home',
        GlassNavItem.dashboard => 'Dashboard',
        GlassNavItem.predictions => 'Predictions',
      },
      onMenuPressed: _openDrawer,
    );
  }

  Widget _pageFor(GlassNavItem item) {
    return switch (item) {
      GlassNavItem.home => const HomeScreen(),
      GlassNavItem.dashboard => const DashboardScreen(),
      GlassNavItem.predictions => const PredictionsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _drawerOpen) _closeDrawer();
      },
      child: Stack(
        children: [
          Scaffold(
            extendBody: true,
            appBar: _appBarForTab(_selected),
            body: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : _transitionDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: Offset(0.05 * _slideDirection, 0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_selected),
                child: _pageFor(_selected),
              ),
            ),
            bottomNavigationBar: GlassBottomNavBar(
              selected: _selected,
              onSelected: _onTabSelected,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_drawerOpen,
              child: AnimatedOpacity(
                opacity: _drawerOpen ? 1 : 0,
                duration: _drawerDuration,
                curve: Curves.easeOut,
                child: GestureDetector(
                  onTap: _closeDrawer,
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: IgnorePointer(
              ignoring: !_drawerOpen,
              child: AnimatedSlide(
                offset: _drawerOpen ? Offset.zero : const Offset(-1, 0),
                duration: _drawerDuration,
                curve: Curves.easeOutCubic,
                child: AppDrawerPanel(onClose: _closeDrawer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
