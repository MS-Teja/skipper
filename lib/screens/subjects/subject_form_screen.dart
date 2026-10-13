import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/settings.dart';
import '../../models/subject.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/chunky.dart';
import '../../widgets/inputs.dart';
import '../../widgets/motion.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/target_slider.dart';

/// Validators, kept pure so they can be unit tested.
abstract final class SubjectValidators {
  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter the subject name';
    if (t.length < 2) return 'That’s a bit short';
    if (t.length > 40) return 'Keep it under 40 characters';
    return null;
  }

  static final _code = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 &+-]{0,5}$');

  static String? code(String? v, {required bool Function(String) isTaken}) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter a short code, e.g. DBMS';
    if (t.length > 6) return 'Up to 6 characters';
    if (!_code.hasMatch(t)) return 'Letters and numbers only';
    if (isTaken(t)) return 'Another subject already uses $t';
    return null;
  }

  static String? count(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null; // treated as 0
    final n = int.tryParse(t);
    if (n == null || n < 0) return 'Whole number';
    if (n > 999) return 'That’s a lot of classes';
    return null;
  }

  static String? attendedVsConducted(String? attended, String? conducted) {
    final a = int.tryParse(attended?.trim() ?? '') ?? 0;
    final c = int.tryParse(conducted?.trim() ?? '') ?? 0;
    if (a > c) return 'Can’t attend more than were held';
    return null;
  }

  /// "Database Management Systems" → "DMS"; "Operating Systems Lab" → "OSL".
  static String suggestCode(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    const skip = {'and', 'of', 'the', '&', 'to', 'in', 'for'};
    final initials = words
        .where((w) => !skip.contains(w.toLowerCase()))
        .map((w) => w[0].toUpperCase())
        .join();
    if (initials.length >= 2) {
      return initials.length > 6 ? initials.substring(0, 6) : initials;
    }
    final w = words.isEmpty ? '' : words.first.toUpperCase();
    return w.length > 4 ? w.substring(0, 4) : w;
  }
}

class SubjectFormScreen extends StatefulWidget {
  const SubjectFormScreen({super.key, this.subjectId});
  final String? subjectId;

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  final _form = GlobalKey<FormState>();
  final _shake = ShakeController();
  late final TextEditingController _name, _code, _attended, _conducted;
  late int _color;
  int? _target;
  bool _codeEdited = false;
  Subject? _existing;
  final _nameFocus = FocusNode();
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // New subject: focus the name once the sheet has finished rising.
    // Autofocus would bring the keyboard up mid-slide and resize the whole
    // form on every frame of the transition.
    if (_existing == null && _routeAnimation == null) {
      final a = ModalRoute.of(context)?.animation;
      _routeAnimation = a;
      if (a == null || a.isCompleted) {
        _nameFocus.requestFocus();
      } else {
        a.addStatusListener(_focusWhenOpen);
      }
    }
  }

  void _focusWhenOpen(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _routeAnimation?.removeStatusListener(_focusWhenOpen);
      _nameFocus.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    final timetable = context.read<TimetableProvider>();
    _existing = widget.subjectId == null
        ? null
        : timetable.subjectById(widget.subjectId!);
    final s = _existing;
    _name = TextEditingController(text: s?.name ?? '');
    _code = TextEditingController(text: s?.code ?? '');
    _attended = TextEditingController(
      text: s == null || s.baselineConducted == 0
          ? ''
          : '${s.baselineAttended}',
    );
    _conducted = TextEditingController(
      text: s == null || s.baselineConducted == 0
          ? ''
          : '${s.baselineConducted}',
    );
    _color = s?.colorIndex ?? timetable.nextColorIndex(subjectPalette.length);
    _target = s?.targetOverride;
    _codeEdited = s != null;
    _name.addListener(() {
      if (!_codeEdited) _code.text = SubjectValidators.suggestCode(_name.text);
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_focusWhenOpen);
    _nameFocus.dispose();
    for (final c in [_name, _code, _attended, _conducted]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      _shake.shake();
      return;
    }
    final timetable = context.read<TimetableProvider>();
    final subject = Subject(
      id: _existing?.id ?? TimetableProvider.newId(),
      name: _name.text.trim(),
      code: _code.text.trim().toUpperCase(),
      colorIndex: _color,
      targetOverride: _target,
      baselineAttended: int.tryParse(_attended.text.trim()) ?? 0,
      baselineConducted: int.tryParse(_conducted.text.trim()) ?? 0,
    );
    HapticFeedback.mediumImpact();
    await timetable.saveSubject(subject);
    if (mounted) Navigator.pop(context, subject);
  }

  Future<void> _delete() async {
    final s = _existing!;
    final ok = await confirm(
      context,
      title: 'Delete ${s.code}?',
      message:
          'It’s removed from your timetable and its attendance stops counting.',
      cancelLabel: 'Keep',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<TimetableProvider>().deleteSubject(s.id);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    final settings = context.watch<SettingsProvider>();
    final timetable = context.read<TimetableProvider>();
    final editing = _existing != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(editing ? 'Edit subject' : 'New subject'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline_rounded, color: c.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 8, Space.gutter, 32),
          children: [
            // Live preview of the card this subject will get.
            AnimatedContainer(
              duration: Motion.d(context, Motion.medium),
              padding: const EdgeInsets.all(18),
              decoration: ShapeDecoration(
                color: subjectColor(_color).fill(b),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(Radii.l),
                  side: BorderSide(color: subjectColor(_color).border(b)),
                ),
              ),
              child: ListenableBuilder(
                listenable: Listenable.merge([_name, _code]),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _code.text.trim().isEmpty
                          ? 'CODE'
                          : _code.text.trim().toUpperCase(),
                      style: display(30, color: c.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _name.text.trim().isEmpty
                          ? 'Subject name'
                          : _name.text.trim(),
                      style: body(15, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Shake(
              controller: _shake,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    focusNode: _nameFocus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Subject name',
                      hintText: 'Operating Systems',
                    ),
                    validator: SubjectValidators.name,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    onChanged: (_) => _codeEdited = true,
                    decoration: const InputDecoration(
                      labelText: 'Short code',
                      hintText: 'OS',
                      helperText: 'Shown big on your cards',
                    ),
                    validator: (v) => SubjectValidators.code(
                      v,
                      isTaken: (t) =>
                          timetable.isCodeTaken(t, exceptId: _existing?.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionLabel('COLOUR'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < subjectPalette.length; i++)
                  Semantics(
                    label: subjectPalette[i].name,
                    selected: i == _color,
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _color = i);
                      },
                      child: AnimatedScale(
                        scale: i == _color ? 1.12 : 1,
                        duration: Motion.d(context, Motion.medium),
                        curve: Motion.pop,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: subjectPalette[i].hue(b),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _color ? c.text : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: i == _color
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (settings.rule == AttendanceRule.eachSubject) ...[
              const SizedBox(height: 24),
              const SectionLabel('TARGET'),
              Group(
                children: [
                  SwitchRow(
                    title: const Text('Different target for this subject'),
                    subtitle: Text(
                      _target == null
                          ? 'Uses your ${settings.target}%'
                          : 'This subject needs $_target%',
                    ),
                    value: _target != null,
                    onChanged: (v) =>
                        setState(() => _target = v ? settings.target : null),
                  ),
                  if (_target != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TargetSlider(
                              value: _target!,
                              onChanged: (v) => setState(() => _target = v),
                              onChangeEnd: (v) => setState(() => _target = v),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '$_target%',
                              textAlign: TextAlign.end,
                              style: display(20, color: c.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const SectionLabel('STARTING MID-SEMESTER?'),
            Text(
              'Copy the numbers from your college portal. Leave blank if the semester just started.',
              style: body(14, color: c.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _attended,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Attended'),
                    validator: (v) =>
                        SubjectValidators.count(v) ??
                        SubjectValidators.attendedVsConducted(
                          v,
                          _conducted.text,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _conducted,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Held'),
                    validator: SubjectValidators.count,
                    onChanged: (_) => _form.currentState?.validate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Chunky(
              color: Moment.lime,
              onTap: _save,
              semanticLabel: editing ? 'Save changes' : 'Add subject',
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Text(
                  editing ? 'Save changes' : 'Add subject',
                  style: display(19, color: Moment.ink, weight: 700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
