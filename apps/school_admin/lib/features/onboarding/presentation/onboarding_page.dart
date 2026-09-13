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
    Icons.dashboard_customize_outlined,
    S('Run your whole school from one app', 'شغّل مدرستك كلها من تطبيق واحد'),
    S(
      'Buses, routes, trips, drivers and parents — manage everything your '
          "school's transportation needs in one place.",
      'الأتوبيسات والخطوط والرحلات والسواقين وأولياء الأمور — كل حاجة '
          'مواصلات مدرستك محتاجاها في مكان واحد.',
    ),
  ),
  _Slide(
    Icons.fact_check_outlined,
    S('Approve who joins your school', 'وافق على مين ينضم لمدرستك'),
    S(
      'Drivers and parents register themselves with your school code — '
          "you approve each one before they can see anything.",
      'السواقين وأولياء الأمور بيسجلوا نفسهم بكود مدرستك — إنت اللي '
          'بتوافق على كل واحد قبل ما يشوف أي حاجة.',
    ),
  ),
  _Slide(
    Icons.map_outlined,
    S('Watch every bus, live', 'تابع كل أتوبيس، لحظة بلحظة'),
    S(
      "See every trip on the road at once, and dig into stats on students, "
          'drivers and routes whenever you need to.',
      'شوف كل الرحلات الشغالة في نفس الوقت، وادخل على إحصائيات الطلاب '
          'والسواقين والخطوط وقت ما تحتاج.',
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
                      tooltip: const S('Language', 'اللغة', fr: 'Langue', es: 'Idioma').of(context),
                      onPressed: () => showLanguagePickerSheet(context),
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
