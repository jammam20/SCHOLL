import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_settings.dart';

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
    Icons.location_on_outlined,
    S("Follow your child's bus, live", 'تابع أتوبيس ابنك لحظة بلحظة'),
    S(
      'See exactly where the bus is and how many minutes until it reaches '
          "your child's pickup point.",
      'شوف بالظبط الأتوبيس فين وهيوصل نقطة استلام ابنك بعد كام دقيقة.',
    ),
  ),
  _Slide(
    Icons.check_circle_outline,
    S('Know the moment they board', 'اعرف اللحظة اللي بيركب فيها'),
    S(
      'The app tells you the instant your child boards the bus — no need '
          'to call the driver or wait and wonder.',
      'التطبيق بيقولك أول ما ابنك يركب الأتوبيس — من غير ما تكلم السواق '
          'أو تستنى قلقان.',
    ),
  ),
  _Slide(
    Icons.event_busy_outlined,
    S("Not riding today? One tap.", 'مش هيركب النهاردة؟ ضغطة واحدة'),
    S(
      "Mark your child absent and the driver's route skips their stop "
          'automatically — no wasted trip to an empty house.',
      'حدد إن ابنك غايب وخط سير السواق هيتخطى محطته تلقائي — من غير لف '
          'على بيت فاضي.',
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
    final colors = Theme.of(context).colorScheme;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'العربية / English',
                      onPressed: AppSettings.toggleLocale,
                      icon: const Icon(Icons.translate),
                    ),
                    const SizedBox(width: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 32),
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
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(slide.icon, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title.of(context),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.subtitle.of(context),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
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
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? colors.primary : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: isLast
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  isLast
                      ? const S('Get started', 'يلا نبدأ').of(context)
                      : const S('Next', 'التالي').of(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
