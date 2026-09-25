import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/services/onboarding_gate_service.dart';
import '../widgets/first_habit_illustration.dart';
import '../widgets/onboarding_progress_dots.dart';
import '../widgets/reason_prompt_illustration.dart';
import '../widgets/streak_gap_illustration.dart';

/// First-launch introduction — three swipeable pages establishing why
/// Tracely exists (the missed-day "gap"), how it responds (one gentle
/// question), and what to do first (one habit). Shown once ever, gated by
/// [OnboardingGateService].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage == _pageCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: AppDurations.pageTransition,
      curve: AppCurves.pageTransition,
    );
  }

  // Always lands on Dashboard, never directly on Add Habit: AddHabitScreen
  // expects to pop back onto an existing route, and go() here replaces the
  // whole stack, leaving nothing to pop to. The Dashboard empty state already
  // has its own "Add First Habit" CTA (context.push, poppable) for a
  // zero-habit account, so routing there first is both safer and reuses an
  // already-correct path instead of inventing a second one.
  Future<void> _finish() async {
    await OnboardingGateService.markCompleted();
    if (!mounted) return;
    context.go(AppRouter.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentPage = index),
          children: [
            _OnboardingPage(
              pageIndex: 0,
              pageCount: _pageCount,
              illustration: const StreakGapIllustration(),
              headline: AppStrings.onboarding1Headline,
              body: AppStrings.onboarding1Body,
              primaryLabel: AppStrings.onboardingNext,
              onPrimaryPressed: _goToNextPage,
              onSkip: _finish,
            ),
            _OnboardingPage(
              pageIndex: 1,
              pageCount: _pageCount,
              illustration: const ReasonPromptIllustration(),
              headline: AppStrings.onboarding2Headline,
              body: AppStrings.onboarding2Body,
              primaryLabel: AppStrings.onboardingNext,
              onPrimaryPressed: _goToNextPage,
              onSkip: _finish,
            ),
            _OnboardingPage(
              pageIndex: 2,
              pageCount: _pageCount,
              illustration: const FirstHabitIllustration(),
              headline: AppStrings.onboarding3Headline,
              body: AppStrings.onboarding3Body,
              primaryLabel: AppStrings.onboardingCreateFirstHabit,
              onPrimaryPressed: _goToNextPage,
              onSkip: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.pageIndex,
    required this.pageCount,
    required this.illustration,
    required this.headline,
    required this.body,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.onSkip,
  });

  final int pageIndex;
  final int pageCount;
  final Widget illustration;
  final String headline;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + ConstrainedBox(minHeight) + IntrinsicHeight lets the
    // Spacer below size itself normally on a typical device, but degrades to
    // a scrollable column instead of a RenderFlex overflow when large system
    // font scaling (common on Android, a frequent Play Store complaint)
    // pushes total content past the available height.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: _buildContent(context)),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.massive,
        bottom: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          Column(
            children: [
              // Stitch reserves a fixed 240px band for the art on all three
              // pages, so the headline below starts at the same height even
              // though each illustration is a different size.
              SizedBox(
                height: 240,
                child: Center(child: illustration),
              ),
              const SizedBox(height: AppSpacing.huge - AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6, // leading-relaxed
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          OnboardingProgressDots(pageCount: pageCount, activeIndex: pageIndex),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                textStyle: AppTypography.textTheme.titleMedium?.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The last page has no Skip, but keeps its height so the primary
          // button sits at the same place on all three — Stitch does this
          // with an explicit spacer.
          SizedBox(
            height: AppSizes.buttonSmallHeight + AppSpacing.sm,
            child: onSkip == null
                ? null
                : TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      // Stitch renders Skip in text-disabled, but this is a
                      // real, tappable action, not an inert control — that
                      // color measures 3.01:1, below WCAG AA's 4.5:1 for
                      // normal text. textSecondary (6.34:1) reads the same
                      // "quiet, secondary" way and passes.
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      textStyle: AppTypography.textTheme.titleSmall,
                    ),
                    child: Text(AppStrings.onboardingSkip),
                  ),
          ),
        ],
      ),
    );
  }
}
