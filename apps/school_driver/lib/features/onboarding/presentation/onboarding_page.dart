import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_shared/school_shared.dart';

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
    Icons.route_outlined,
    S("See today's route, in order", 'شوف خط سيرك النهاردة بالترتيب'),
    S(
      'Your pickup order is worked out for you automatically, stop by '
          'stop — and you can still reorder it by hand if the road tells '
          'you otherwise.',
      'ترتيب الاستلام بيتحسب لك تلقائيًا محطة محطة — وتقدر تغيّره بإيدك '
          'لو الطريق قال حاجة تانية.',
    ),
  ),
  _Slide(
    Icons.how_to_reg_outlined,
    S('Tap when a student boards', 'دوس لما الطالب يركب'),
    S(
      "One tap marks a student picked up and lets their parent know "
          'instantly — no calls, no guessing.',
      'ضغطة واحدة تحدد إن الطالب ركب وتوصل لولي أمره فورًا — من غير '
          'مكالمات ولا تخمين.',
    ),
  ),
  _Slide(
    Icons.event_busy_outlined,
    S('Absent students are skipped', 'الطلاب الغايبين يتخطوا تلقائي'),
    S(
      "If a parent marks their child absent for the day, that stop drops "
          "out of your route automatically — no wasted detour.",
      'لو ولي الأمر حدد إن ابنه غايب النهاردة، المحطة دي بتتشال من خط '
          'سيرك تلقائي — من غير لف فاضي.',
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isLast = _index == _slides.length - 1;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

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
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: Icon(slide.icon, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: AppSpacing.xl3),
                        Text(
                          slide.title.of(context),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.subtitle.of(context),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.textSecondary,
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
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? theme.colorScheme.primary : colors.border,
                      borderRadius: BorderRadius.circular(AppRadius.sm / 2),
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
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
