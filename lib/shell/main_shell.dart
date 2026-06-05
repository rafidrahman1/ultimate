import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analyze/analyze_screen.dart';
import '../features/home/home_screen.dart';
import '../features/results/weekly_checklists_screen.dart';
import '../widgets/app_screen_app_bar.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import 'app_drawer.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GlassNavItem _selected = GlassNavItem.home;
  int _slideDirection = 0;

  static const _transitionDuration = Duration(milliseconds: 220);

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

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
          showThemeToggle: true,
        ),
      GlassNavItem.weeklyChecklist => AppScreenAppBar.build(
          context,
          ref,
          title: 'Weekly checklists',
          onMenuPressed: _openDrawer,
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
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
    );
  }
}
