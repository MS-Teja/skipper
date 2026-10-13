/// A subject (or lab) the student attends.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.colorIndex,
    this.targetOverride,
    this.baselineAttended = 0,
    this.baselineConducted = 0,
  });

  final String id;
  final String name;

  /// Short label shown big on cards, e.g. "DBMS" (max 6 characters).
  final String code;

  /// Index into the subject palette in `theme/tokens.dart`.
  final int colorIndex;

  /// Per-subject target %, only used when the rule is "each subject".
  final int? targetOverride;

  /// Numbers copied from the college portal when starting mid-semester.
  final int baselineAttended;
  final int baselineConducted;

  Subject copyWith({
    String? name,
    String? code,
    int? colorIndex,
    int? Function()? targetOverride,
    int? baselineAttended,
    int? baselineConducted,
  }) => Subject(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    colorIndex: colorIndex ?? this.colorIndex,
    targetOverride: targetOverride != null
        ? targetOverride()
        : this.targetOverride,
    baselineAttended: baselineAttended ?? this.baselineAttended,
    baselineConducted: baselineConducted ?? this.baselineConducted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'colorIndex': colorIndex,
    'targetOverride': targetOverride,
    'baselineAttended': baselineAttended,
    'baselineConducted': baselineConducted,
  };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    colorIndex: json['colorIndex'] as int,
    targetOverride: json['targetOverride'] as int?,
    baselineAttended: json['baselineAttended'] as int? ?? 0,
    baselineConducted: json['baselineConducted'] as int? ?? 0,
  );
}
