import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../providers/attendance_provider.dart';
import '../providers/holiday_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/dates.dart';
import 'attendance/attendance_screen.dart';
import 'planner/planner_screen.dart';
import 'settings/settings_screen.dart';
import 'today/today_screen.dart';

/// Bottom navigation: Today | Attendance | Planner | Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

/// Dev flag: `--dart-define=SCREEN=attendance|planner|detail|settings|…`
/// opens a screen on launch (handy for demos and screenshots).
const _startScreen = String.fromEnvironment('SCREEN');

class HomeShellState extends State<HomeShell> {
  int _tab = switch (_startScreen) {
    'attendance' || 'detail' || 'overall' => 1,
    'planner' => 2,
    'settings' => 3,
    _ => 0,
  };
  // One per tab, so a re-tap scrolls that tab (and only it) to the top.
  final _scrollers = List.generate(4, (_) => ScrollController());
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 900),
  );
  late final AttendanceProvider _attendance;
  Timer? _reminderDebounce;

  void goTo(int tab) {
    if (tab == _tab) {
      // iOS convention: tapping the current tab scrolls it to the top.
      final s = _scrollers[tab];
      if (s.hasClients && s.offset > 0) {
        s.animateTo(
          0,
          duration: Motion.d(context, const Duration(milliseconds: 420)),
          curve: Motion.spring,
        );
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  @override
  void initState() {
    super.initState();
    _attendance = context.read<AttendanceProvider>();
    _attendance.addListener(_onAttendance);
    context.read<NotificationService>().onOpen = () {
      if (mounted) setState(() => _tab = 0);
    };
    _scheduleReminders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The feed needs no key, so fetch quietly the first time.
      final holidays = context.read<HolidayProvider>();
      if (holidays.apiHolidays.isEmpty &&
          holidays.fetchState == FetchState.idle) {
        holidays.fetch();
      }
      _openStartScreen();
    });
  }

  void _openStartScreen() {
    final nav = Navigator.of(context);
    final first = _attendance.subjects.isEmpty
        ? null
        : _attendance.subjects[1 % _attendance.subjects.length].id;
    switch (_startScreen) {
      case 'detail':
        nav.pushNamed(Routes.detail, arguments: first);
      case 'overall':
        nav.pushNamed(Routes.detail);
      case 'timetable':
        nav.pushNamed(Routes.timetable);
      case 'holidays':
        nav.pushNamed(Routes.holidays);
      case 'breaks':
        nav.pushNamed(Routes.holidays, arguments: 1);
      case 'pending':
        nav.pushNamed(Routes.pending);
      case 'form':
        nav.pushNamed(Routes.subjectForm, arguments: first);
    }
  }

  void _onAttendance() {
    final recovered = _attendance.consumeRecovery();
    if (recovered != null && mounted) _celebrate(recovered);
    _scheduleReminders();
  }

  void _celebrate(String label) {
    if (!Motion.reduced(context)) _confetti.play();
    HapticFeedback.heavyImpact();
    final target = context.read<SettingsProvider>().target;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Moment.lime,
          content: Text(
            '$label is back above $target%. Legend.',
            style: display(18, color: Moment.ink),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.m),
            side: const BorderSide(color: Moment.ink, width: 2),
          ),
        ),
      );
  }

  /// Keep the next 7 day-end reminders in sync with what's marked.
  void _scheduleReminders() {
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final s = context.read<SettingsProvider>().settings;
      final a = _attendance;
      context.read<NotificationService>().reschedule(
        enabled: s.reminderEnabled,
        minutesAfterMidnight: s.reminderMinutes,
        unmarkedOn: (d) => a.classesOn(d).fold(0, (n, e) => n + e.unmarked),
        periodsOn: (d) => a.classesOn(d).fold(0, (n, e) => n + e.periods),
      );
    });
  }

  @override
  void dispose() {
    _attendance.removeListener(_onAttendance);
    _reminderDebounce?.cancel();
    _confetti.dispose();
    for (final s in _scrollers) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const pages = [
      TodayScreen(),
      AttendanceScreen(),
      PlannerScreen(),
      SettingsScreen(asTab: true),
    ];
    return Scaffold(
      extendBody: true,
      // Tabs have no text fields; sheets pad for the keyboard themselves.
      // Without this, the screen behind a sheet relayouts on every keyboard
      // animation frame.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Like a UITabBarController: tabs switch instantly and keep their
          // state and scroll position. Hidden tabs don't tick.
          IndexedStack(
            index: _tab,
            children: [
              for (var i = 0; i < pages.length; i++)
                TickerMode(
                  enabled: i == _tab,
                  child: PrimaryScrollController(
                    controller: _scrollers[i],
                    child: pages[i],
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              maxBlastForce: 28,
              minBlastForce: 10,
              gravity: 0.25,
              colors: [Moment.lime, Moment.coral, Moment.sun, c.accent],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _NavBar(index: _tab, onTap: goTo),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.event_available_outlined, Icons.event_available_rounded, 'Today'),
    (Icons.donut_large_outlined, Icons.donut_large_rounded, 'Attendance'),
    (Icons.wb_twilight_outlined, Icons.wb_twilight_rounded, 'Planner'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pending = context.select<AttendanceProvider, int>(
      (a) => a.pendingCount,
    );
    // Solid, not frosted: a full-width blur cost ~15 ms of GPU time per frame
    // on a mid-range Android phone.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(
          top: BorderSide(
            color: c.line,
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    key: ValueKey('tab-$i'),
                    icon: i == index ? _items[i].$2 : _items[i].$1,
                    label: _items[i].$3,
                    selected: i == index,
                    dot: i == 0 && pending > 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.dot,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pill = selected ? Moment.lime : c.navBg;
    return Semantics(
      selected: selected,
      button: true,
      label: dot ? '$label, classes not marked' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.d(context, Motion.medium),
              curve: Motion.spring,
              width: selected ? 56 : 44,
              height: 30,
              decoration: BoxDecoration(
                color: pill,
                borderRadius: BorderRadius.circular(15),
              ),
              // The dot sits on the icon's corner but always inside the
              // pill, ringed in the pill's colour so it reads as cut-out.
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 26,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          icon,
                          size: 22,
                          color: selected ? Moment.ink : c.muted,
                        ),
                      ),
                      if (dot)
                        Positioned(
                          top: 1,
                          right: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Moment.coral,
                              shape: BoxShape.circle,
                              border: Border.all(color: pill, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(
                11.5,
                color: selected ? c.text : c.muted,
                weight: selected ? 600 : 500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Short date label, e.g. "Tue 6 Oct".
String shortDate(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

String relativeDay(DateTime d) {
  final t = today();
  if (isSameDay(d, t)) return 'Today';
  if (isSameDay(d, addDays(t, -1))) return 'Yesterday';
  if (isSameDay(d, addDays(t, 1))) return 'Tomorrow';
  return shortDate(d);
}
