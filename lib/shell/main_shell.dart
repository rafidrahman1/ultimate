import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/home/analyze_options_dialog.dart';
import 'package:personal/features/home/home_screen.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shell/widgets/animated_ai_analyze_button.dart';
import 'package:personal/shell/app_drawer.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _drawerOpen = false;

  static const _drawerDuration = Duration(milliseconds: 250);

  void _openDrawer() => setState(() => _drawerOpen = true);

  void _closeDrawer() => setState(() => _drawerOpen = false);

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
            appBar: AppScreenAppBar.build(
              context,
              ref,
              title: 'Home',
              onMenuPressed: _openDrawer,
              extraWidgets: [
                AnimatedAiAnalyzeButton(
                  isAnalyzing: ref.watch(
                    analysisRunProvider.select((state) => state.isRunning),
                  ),
                  onPressed: (buttonContext) => showAnalyzeOptionsDialog(
                    context: context,
                    ref: ref,
                    buttonContext: buttonContext,
                  ),
                ),
              ],
            ),
            body: const HomeScreen(),
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
