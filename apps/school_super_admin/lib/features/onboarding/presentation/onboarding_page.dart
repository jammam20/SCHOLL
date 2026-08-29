import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'onboarding_seen';

/// True once this device has swiped through (or skipped) the walkthrough.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenKey) ?? false;
}

/// Wraps [child] with a one-time walkthrough: shows [OnboardingPage] until
/// the flag is set, then shows [child] on every launch after. Kept as a
/// gate around the existing widget tree (rather than a route pushed from
/// main.dart) so sign-in state, deep links, etc. are untouched — this is
/// purely a first-launch overlay.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    hasSeenOnboarding().then((seen) {
      if (mounted) setState(() => _seen = seen);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) return const SizedBox.shrink();
    if (_seen == true) return widget.child;
    return OnboardingPage(onDone: () => setState(() => _seen = true));
  }
}

class _Slide {
  const _Slide(this.icon, this.title, this.subtitle);
  final IconData icon;
  final S title;
  final S subtitle;
}

const _slides = [
  _Slide(
    Icons.school_outlined,
    S('Bring a new school on board', 'ضيف مدرسة جديدة للمنصة'),
    S(
      'Create a school and hand its owner a join code — they use it to '
          'register themselves as that school\'s first admin, no Firebase '
          'Console needed.',
      'اعمل مدرسة وادّي صاحبها كود انضمام — هيستخدمه يسجل نفسه كأول أدمن '
          'للمدرسة دي، من غير ما يلمس Firebase Console خالص.',
    ),
  ),
  _Slide(
    Icons.pending_actions_outlined,
    S("Approve each school's first admin", 'وافق على أول أدمن لكل مدرسة'),
    S(
      "Every new school's first admin request lands here for you to "
          'approve or reject before they can access anything.',
      'أول طلب أدمن لأي مدرسة جديدة بيوصلك هنا عشان توافق عليه أو ترفضه '
          'قبل ما يقدر يدخل أي حاجة.',
    ),
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    widget.onDone();
  }

  void _next() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _controller.nextPage(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = context.appColors;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'العربية / English',
                      onPressed: AppSettings.toggleLocale,
                      icon: const Icon(Icons.translate),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _finish,
                      child: Text(const S('Skip', 'تخطي').of(context)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl3,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.tertiary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: Icon(slide.icon, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: AppSpacing.xl3),
                        Text(
                          slide.title.of(context),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: appColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.subtitle.of(context),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: appColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? colors.primary : appColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl2),
              child: SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: isLast
                      ? const S('Get started', 'يلا نبدأ').of(context)
                      : const S('Next', 'التالي').of(context),
                  onPressed: isLast ? _finish : _next,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
