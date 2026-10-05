import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/settings/settings_status.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';

const _onboardingSeenKey = 'onboarding_seen_v1';

/// True once the walkthrough has been finished or skipped.
Future<bool> onboardingSeen() async =>
    (await safePrefs())?.getBool(_onboardingSeenKey) ?? false;

Future<void> markOnboardingSeen() async {
  await (await safePrefs())?.setBool(_onboardingSeenKey, true);
}

/// Four-step first-run walkthrough: what the app does, then folder, profile
/// and AI key. Each step reflects live status, so finishing a step elsewhere
/// ticks it here.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (mounted) await Navigator.of(context).maybePop();
  }

  void _go(int page) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(settingsStatusProvider);
    final theme = Theme.of(context);
    final palette = context.palette;
    final last = _page == _pageCount - 1;

    final pages = <_StepPage>[
      const _StepPage(
        icon: Icons.lock_outline_rounded,
        title: 'Your data stays yours',
        body:
            'Personal turns your health, spending, location, gaming and '
            'calendar data into monthly insights and weekly checklists. '
            'Everything stays on this device unless you turn on a cloud AI '
            'provider.',
      ),
      _StepPage(
        icon: Icons.folder_outlined,
        title: 'Pick your data folder',
        body:
            'Reports, exports and backups live in one folder you choose, so '
            'they survive a reinstall.',
        done: status.storage.tone == StatusTone.ok,
        statusText: status.storage.text,
        actionLabel: 'Choose folder',
        onAction: () => Navigator.pushNamed(
          context,
          AppRoutes.generalSettings,
          arguments: 'storage',
        ),
      ),
      _StepPage(
        icon: Icons.person_outline_rounded,
        title: 'Tell it about you',
        body:
            'Income, schedule and goals make the analysis specific to your '
            'life. Analysis stays off until the required fields are filled in.',
        done: status.profile.tone == StatusTone.ok,
        statusText: status.profile.text,
        actionLabel: 'Fill in profile',
        onAction: () =>
            Navigator.pushNamed(context, AppRoutes.personalInformation),
      ),
      _StepPage(
        icon: Icons.auto_awesome_outlined,
        title: 'Add an AI key (optional)',
        body:
            'Use OpenAI, Gemini or Claude for full reports. Without a key '
            'you still get simpler local insights.',
        done: status.ai.tone == StatusTone.ok,
        statusText: status.ai.text,
        actionLabel: 'Set up AI',
        onAction: () => Navigator.pushNamed(
          context,
          AppRoutes.generalSettings,
          arguments: 'ai',
        ),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Step ${_page + 1} of $_pageCount',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pageCount; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? palette.accent
                                    : palette.border,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (_page > 0)
                          OutlinedButton(
                            onPressed: () => _go(_page - 1),
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: last ? _finish : () => _go(_page + 1),
                          child: Text(last ? 'Done' : 'Next'),
                        ),
                      ],
                    ),
                    if (!last)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'You can change all of this later in Settings.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.icon,
    required this.title,
    required this.body,
    this.done = false,
    this.statusText,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool done;
  final String? statusText;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: AppOpacity.medium),
              borderRadius: BorderRadius.circular(AppRadii.cardLarge),
            ),
            child: Icon(icon, size: 40, color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              tier: AppCardTier.flat,
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: done ? palette.accent : palette.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      statusText ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(done ? 'Change' : actionLabel!),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
