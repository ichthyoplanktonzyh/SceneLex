/// LearningPreferences serialization and defaults.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/domain/learning/preferences.dart';

void main() {
  test('defaults match the product spec', () {
    const prefs = LearningPreferences();
    expect(prefs.transferTiming, TransferTiming.endOfDay);
    expect(prefs.boundaryPerturbationEnabled, isTrue);
    expect(prefs.symbolRecallEnabled, isTrue);
    expect(prefs.scaffoldLevel, ScaffoldLevel.zh);
    expect(prefs.autoScaffoldRemoval, isTrue);
    expect(prefs.zhLabelBeforeReveal, isFalse);
    expect(prefs.newGroupSize, 4);
    expect(prefs.reviewGroupSize, 20);
    expect(prefs.accent, Accent.us);
    expect(prefs.autoPronounce, AutoPronounce.onReveal);
    expect(prefs.reminderMode, ReminderMode.smart);
  });

  test('json round-trip preserves every field', () {
    const prefs = LearningPreferences(
      transferTiming: TransferTiming.firstReview,
      boundaryPerturbationEnabled: false,
      symbolRecallEnabled: false,
      scaffoldLevel: ScaffoldLevel.en,
      autoScaffoldRemoval: false,
      zhLabelBeforeReveal: true,
      newGroupSize: 8,
      reviewGroupSize: 10,
      accent: Accent.uk,
      autoPronounce: AutoPronounce.off,
      reminderMode: ReminderMode.fixed,
    );
    final restored = LearningPreferences.fromJson(prefs.toJson());
    expect(restored.transferTiming, TransferTiming.firstReview);
    expect(restored.boundaryPerturbationEnabled, isFalse);
    expect(restored.symbolRecallEnabled, isFalse);
    expect(restored.scaffoldLevel, ScaffoldLevel.en);
    expect(restored.autoScaffoldRemoval, isFalse);
    expect(restored.zhLabelBeforeReveal, isTrue);
    expect(restored.newGroupSize, 8);
    expect(restored.reviewGroupSize, 10);
    expect(restored.accent, Accent.uk);
    expect(restored.autoPronounce, AutoPronounce.off);
    expect(restored.reminderMode, ReminderMode.fixed);
  });

  test('unknown enum names fall back to the default', () {
    final prefs = LearningPreferences.fromJson({
      'transferTiming': 'not-a-timing',
      'accent': '?',
      'scaffoldLevel': 42,
      'newGroupSize': 'x',
    });
    expect(prefs.transferTiming, TransferTiming.endOfDay);
    expect(prefs.accent, Accent.us);
    expect(prefs.scaffoldLevel, ScaffoldLevel.zh);
    expect(prefs.newGroupSize, 4);
  });

  test('copyWith only changes the given fields', () {
    const base = LearningPreferences();
    final changed = base.copyWith(newGroupSize: 12, accent: Accent.uk);
    expect(changed.newGroupSize, 12);
    expect(changed.accent, Accent.uk);
    expect(changed.transferTiming, TransferTiming.endOfDay);
    expect(changed.reviewGroupSize, 20);
  });

  test('supported size lists are stable and ascending', () {
    expect(
      LearningPreferences.supportedNewGroupSizes,
      orderedEquals([4, 6, 8, 12]),
    );
    expect(
      LearningPreferences.supportedReviewGroupSizes,
      orderedEquals([20, 10, 30]),
    );
  });
}
