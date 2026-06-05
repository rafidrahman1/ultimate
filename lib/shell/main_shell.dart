import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analyze/analyze_screen.dart';
import '../features/home/analyze_options_dialog.dart';
import '../features/home/home_screen.dart';
import '../features/results/analysis_service.dart';
import '../features/results/weekly_checklists_screen.dart';
import '../widgets/app_screen_app_bar.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import '../widgets/weekly_checklist_picker_button.dart';
import 'app_drawer.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  GlassNavItem _selected = GlassNavItem.home;
  int _slideDirection = 0;
  bool _drawerOpen = false;

  static const _transitionDuration = Duration(milliseconds: 220);
  static const _drawerDuration = Duration(milliseconds: 250);

  void _openDrawer() => setState(() => _drawerOpen = true);

  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _onTabSelected(GlassNavItem item) {
    if (item == _selected) return;
    setState(() {
      _slideDirection = item.index.compareTo(_selected.index);
      _selected = item;
    });
  }

  PreferredSizeWidget _appBarForTab(GlassNavItem item) {
    return switch (item) {
      GlassNavItem.home => AppScreenAppBar.build(
          context,
          ref,
          title: 'Home',
          onMenuPressed: _openDrawer,
          extraActions: [
            AppBarCircularAction(
              icon: Icons.analytics_outlined,
              onPressed: ref.watch(analysisRunProvider).isRunning
                  ? null
                  : () => showAnalyzeOptionsDialog(context: context, ref: ref),
            ),
          ],
        ),
      GlassNavItem.weeklyChecklist => AppScreenAppBar.build(
          context,
          ref,
          title: 'Weekly checklists',
          onMenuPressed: _openDrawer,
          extraWidgets: const [WeeklyChecklistPickerButton()],
        ),
      GlassNavItem.analyze => AppScreenAppBar.build(
          context,
          ref,
          title: 'Analyze',
          onMenuPressed: _openDrawer,
          extraActions: [
            AppBarCircularAction(
              icon: Icons.delete_sweep_outlined,
              onPressed: () => confirmClearAllAnalysisResults(context, ref),
            ),
          ],
        ),
    };
  }

  Widget _pageFor(GlassNavItem item) {
    return switch (item) {
      GlassNavItem.home => const HomeScreen(),
      GlassNavItem.weeklyChecklist => const WeeklyChecklistsScreen(),
      GlassNavItem.analyze => const AnalyzeScreen(),
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
              duration: _transitionDuration,
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
