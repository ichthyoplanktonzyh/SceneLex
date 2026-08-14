/// Learning preferences — strongly typed, persisted learner settings
/// (docs/product-v1-app.md §15).
///
/// These settings are real knobs: anything the Runtime can honor is wired to
/// it. The L1 scaffold level is a stored preference, but the current content
/// pack only ships a single learner-visible surface; [ScaffoldPolicy] is the
/// seam that decides what is actually applied, capability-aware, so future
/// content upgrades never require rewriting pages or the session state
/// machine.
library;

/// When the delayed symbol retrieval (experience → L2 symbol) is tested.
enum TransferTiming { endOfDay, endOfFirstLearning, firstReview }

/// L1 scaffold levels for narrative presentation.
enum ScaffoldLevel { zh, zhEn, en }

/// Pronunciation accent for TTS.
enum Accent { us, uk }

/// When TTS auto-pronounces the L2 word.
enum AutoPronounce { onReveal, revealAndExamples, off }

/// Learning reminder mode (mapped onto the existing notifications system).
enum ReminderMode { smart, fixed, off }

/// Strongly typed learning preferences with canonical JSON persistence.
class LearningPreferences {
  const LearningPreferences({
    this.transferTiming = TransferTiming.endOfDay,
    this.boundaryPerturbationEnabled = true,
    this.symbolRecallEnabled = true,
    this.scaffoldLevel = ScaffoldLevel.zh,
    this.autoScaffoldRemoval = true,
    this.zhLabelBeforeReveal = false,
    this.newGroupSize = 4,
    this.reviewGroupSize = 20,
    this.accent = Accent.us,
    this.autoPronounce = AutoPronounce.onReveal,
    this.reminderMode = ReminderMode.smart,
  });

  static const supportedNewGroupSizes = [4, 6, 8, 12];
  static const supportedReviewGroupSizes = [20, 10, 30];

  /// 符号检索验收时机.
  final TransferTiming transferTiming;

  /// 边界扰动题.
  final bool boundaryPerturbationEnabled;

  /// 符号回指 (reveal 后的场景→词检索).
  final bool symbolRecallEnabled;

  /// 叙事语言档位 (stored; applied via [ScaffoldPolicy]).
  final ScaffoldLevel scaffoldLevel;

  /// 自动撤除脚手架.
  final bool autoScaffoldRemoval;

  /// 揭示前显示中文标签 (default off: first L1 label is the reveal).
  final bool zhLabelBeforeReveal;

  /// 新学节奏 (senses per group).
  final int newGroupSize;

  /// 复习节奏 (reviews per group).
  final int reviewGroupSize;

  /// 美式/英式发音.
  final Accent accent;

  /// 自动发音时机.
  final AutoPronounce autoPronounce;

  /// 学习提醒.
  final ReminderMode reminderMode;

  LearningPreferences copyWith({
    TransferTiming? transferTiming,
    bool? boundaryPerturbationEnabled,
    bool? symbolRecallEnabled,
    ScaffoldLevel? scaffoldLevel,
    bool? autoScaffoldRemoval,
    bool? zhLabelBeforeReveal,
    int? newGroupSize,
    int? reviewGroupSize,
    Accent? accent,
    AutoPronounce? autoPronounce,
    ReminderMode? reminderMode,
  }) => LearningPreferences(
    transferTiming: transferTiming ?? this.transferTiming,
    boundaryPerturbationEnabled:
        boundaryPerturbationEnabled ?? this.boundaryPerturbationEnabled,
    symbolRecallEnabled: symbolRecallEnabled ?? this.symbolRecallEnabled,
    scaffoldLevel: scaffoldLevel ?? this.scaffoldLevel,
    autoScaffoldRemoval: autoScaffoldRemoval ?? this.autoScaffoldRemoval,
    zhLabelBeforeReveal: zhLabelBeforeReveal ?? this.zhLabelBeforeReveal,
    newGroupSize: newGroupSize ?? this.newGroupSize,
    reviewGroupSize: reviewGroupSize ?? this.reviewGroupSize,
    accent: accent ?? this.accent,
    autoPronounce: autoPronounce ?? this.autoPronounce,
    reminderMode: reminderMode ?? this.reminderMode,
  );

  Map<String, dynamic> toJson() => {
    'transferTiming': transferTiming.name,
    'boundaryPerturbationEnabled': boundaryPerturbationEnabled,
    'symbolRecallEnabled': symbolRecallEnabled,
    'scaffoldLevel': scaffoldLevel.name,
    'autoScaffoldRemoval': autoScaffoldRemoval,
    'zhLabelBeforeReveal': zhLabelBeforeReveal,
    'newGroupSize': newGroupSize,
    'reviewGroupSize': reviewGroupSize,
    'accent': accent.name,
    'autoPronounce': autoPronounce.name,
    'reminderMode': reminderMode.name,
  };

  factory LearningPreferences.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(String key, List<T> values, T fallback) {
      final name = json[key];
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    final newGroupSize = json['newGroupSize'];
    final reviewGroupSize = json['reviewGroupSize'];
    return LearningPreferences(
      transferTiming: pick(
        'transferTiming',
        TransferTiming.values,
        TransferTiming.endOfDay,
      ),
      boundaryPerturbationEnabled:
          json['boundaryPerturbationEnabled'] as bool? ?? true,
      symbolRecallEnabled: json['symbolRecallEnabled'] as bool? ?? true,
      scaffoldLevel: pick(
        'scaffoldLevel',
        ScaffoldLevel.values,
        ScaffoldLevel.zh,
      ),
      autoScaffoldRemoval: json['autoScaffoldRemoval'] as bool? ?? true,
      zhLabelBeforeReveal: json['zhLabelBeforeReveal'] as bool? ?? false,
      newGroupSize:
          newGroupSize is int && supportedNewGroupSizes.contains(newGroupSize)
          ? newGroupSize
          : 4,
      reviewGroupSize:
          reviewGroupSize is int &&
              supportedReviewGroupSizes.contains(reviewGroupSize)
          ? reviewGroupSize
          : 20,
      accent: pick('accent', Accent.values, Accent.us),
      autoPronounce: pick(
        'autoPronounce',
        AutoPronounce.values,
        AutoPronounce.onReveal,
      ),
      reminderMode: pick(
        'reminderMode',
        ReminderMode.values,
        ReminderMode.smart,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LearningPreferences &&
      other.transferTiming == transferTiming &&
      other.boundaryPerturbationEnabled == boundaryPerturbationEnabled &&
      other.symbolRecallEnabled == symbolRecallEnabled &&
      other.scaffoldLevel == scaffoldLevel &&
      other.autoScaffoldRemoval == autoScaffoldRemoval &&
      other.zhLabelBeforeReveal == zhLabelBeforeReveal &&
      other.newGroupSize == newGroupSize &&
      other.reviewGroupSize == reviewGroupSize &&
      other.accent == accent &&
      other.autoPronounce == autoPronounce &&
      other.reminderMode == reminderMode;

  @override
  int get hashCode => Object.hash(
    transferTiming,
    boundaryPerturbationEnabled,
    symbolRecallEnabled,
    scaffoldLevel,
    autoScaffoldRemoval,
    zhLabelBeforeReveal,
    newGroupSize,
    reviewGroupSize,
    accent,
    autoPronounce,
    reminderMode,
  );
}

/// Content capability: what the current content pack can actually present.
/// The v1 pack ships exactly one learner-visible surface (L2 episodes), so
/// surface-language switching is NOT available yet (P0 content debt, see
/// docs/product-v1-app.md §7).
class ContentSurfaceCapability {
  const ContentSurfaceCapability({
    this.supportsSurfaceLanguageSwitch = false,
    this.availableSurface = 'en',
  });

  final bool supportsSurfaceLanguageSwitch;
  final String availableSurface;
}

/// The seam deciding what scaffold level actually applies. Preferences store
/// the learner's choice; the policy decides what the Runtime does today —
/// never pretending a switch that the content cannot honor.
class ScaffoldPolicy {
  const ScaffoldPolicy(this.capability);

  final ContentSurfaceCapability capability;

  /// Effective scaffold level for rendering decisions.
  ScaffoldLevel effectiveLevel(LearningPreferences prefs) {
    if (!capability.supportsSurfaceLanguageSwitch) return prefs.scaffoldLevel;
    return prefs.scaffoldLevel;
  }

  /// Whether the surface language switch is actually applied.
  bool isSwitchApplied() => capability.supportsSurfaceLanguageSwitch;

  /// Human-facing capability note (shown on the preferences page).
  String? capabilityNote() {
    if (capability.supportsSurfaceLanguageSwitch) return null;
    return '当前内容包仅提供英文叙事（L1 脚手架内容尚未生成）。档位会保存，'
        '待内容升级后自动生效，页面与学习流程无需重写。';
  }
}
