// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SceneLex';

  @override
  String get appTagline =>
      'Meaning is experience; micro-worlds are experience.';

  @override
  String get tabReview => 'Review';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabCards => 'Cards';

  @override
  String get tabSettings => 'Settings';

  @override
  String loadingFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginOtpLabel => '8-digit code';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get cardsTitle => 'Cards';

  @override
  String get cardsSearchHint => 'Search senses';

  @override
  String get cardsEmptyLibrary => 'Empty library. Run import_content.py first.';

  @override
  String get cardsEmptySearch => 'No matching senses';

  @override
  String get cardsStudy => 'Study';

  @override
  String get cardsAdded => 'Added';

  @override
  String get cardStateNotAdded => 'Not added';

  @override
  String get cardStateNew => 'New';

  @override
  String get cardStateLearning => 'Learning';

  @override
  String get cardStateRelearning => 'Relearning';

  @override
  String get cardStateReview => 'Review';

  @override
  String cardStateNext(String date) {
    return 'next $date';
  }

  @override
  String cardStatDue(int count) {
    return '$count due';
  }

  @override
  String cardStatReps(int count) {
    return '$count reps';
  }

  @override
  String cardStatLapses(int count) {
    return '$count lapses';
  }

  @override
  String get reviewTitle => 'Today';

  @override
  String get reviewEmptyNoSenses => 'No senses being studied yet';

  @override
  String get reviewEmptyNoDue => 'Nothing due today';

  @override
  String get reviewEmptyGoAdd => 'Add senses from the Cards tab';

  @override
  String get reviewEmptyAllDone => 'All done. See you tomorrow.';

  @override
  String get reviewEmptySwitchToAll => 'Switch to all cards deck';

  @override
  String get reviewFilterTitle => 'Filter';

  @override
  String get reviewFilterLists => 'Lists';

  @override
  String get reviewFilterTags => 'Tags';

  @override
  String get reviewFilterManage => 'Manage lists';

  @override
  String get reviewFilterDone => 'Done';

  @override
  String get listsTitle => 'Lists';

  @override
  String get listsAllCards => 'All Cards';

  @override
  String listsAllCardsBody(int count) {
    return '$count cards';
  }

  @override
  String get listsCreate => 'New list';

  @override
  String get listsEdit => 'Edit list';

  @override
  String get listsDelete => 'Delete';

  @override
  String get listsDeleteTitle => 'Delete this list?';

  @override
  String get listsDeleteBody =>
      'The list and its rule will be removed from this device and the next sync. No study progress is deleted.';

  @override
  String get listsEmpty =>
      'No lists yet. Create a list to study a subset of words.';

  @override
  String get listsNameLabel => 'Name';

  @override
  String get listsTagsLabel => 'Tags (select at least one)';

  @override
  String get listsSaveHint =>
      'A list matches a word when the word carries at least one of the selected tags.';

  @override
  String get listsNoTags => 'No tags available yet.';

  @override
  String listsMatchedCount(int count) {
    return '$count matching cards';
  }

  @override
  String get listsDetailRules => 'Rule';

  @override
  String get listsDetailStats => 'Stats';

  @override
  String get listsDetailMatched => 'Matching cards';

  @override
  String get listsMatchedEmpty => 'No studied words match this list yet.';

  @override
  String get listsStatMatched => 'Matched';

  @override
  String get listsStatDue => 'Due now';

  @override
  String get listsReviewThisDeck => 'Review this list';

  @override
  String get cardRemove => 'Remove';

  @override
  String get cardRemoveTitle => 'Remove from study?';

  @override
  String get cardRemoveBody =>
      'This removes the word from the local list and the next sync. You can add it again any time.';

  @override
  String get stageAnchor => 'Prototype';

  @override
  String get stageVariation => 'Variation';

  @override
  String get stagePerturbation => 'Perturbation';

  @override
  String get stageDiscrimination => 'Discrimination';

  @override
  String get stageSymbolBinding => 'Symbol binding';

  @override
  String get stageL2Grounding => 'L2 grounding';

  @override
  String get stageTransfer => 'Transfer';

  @override
  String get hintAnchor =>
      'First, experience the typical experience this word grows from.';

  @override
  String get hintVariation =>
      'The situation changed, the experience structure did not — find what stayed the same.';

  @override
  String get hintPerturbation =>
      'Change one variable: is it still the same word?';

  @override
  String get hintDiscrimination => 'Two mental states — are they the same?';

  @override
  String get hintSymbolBinding =>
      'The experience you keep recognizing is expressed like this in English.';

  @override
  String get hintL2Grounding => 'How this word is used in real language.';

  @override
  String get hintTransfer => 'A brand new experience: does the word hold?';

  @override
  String playerLoadFailed(String error) {
    return 'Failed to load program: $error';
  }

  @override
  String get speechListen => 'Listen';

  @override
  String get speechStop => 'Stop';

  @override
  String get speechUnavailable => 'Speech is not available';

  @override
  String get playerNoUnits => 'No playable experience for this sense yet.';

  @override
  String get playerNoSynopsis => '(no synopsis)';

  @override
  String get playerTaskJudge => 'Judgment';

  @override
  String get playerTaskPlaceholder => '(task)';

  @override
  String get playerFinish => 'Finish the experience';

  @override
  String get playerContinue => 'Continue';

  @override
  String get playerRatingQuestion =>
      'How well do you remember this experience?';

  @override
  String get ratingAgain => 'Again';

  @override
  String get ratingHard => 'Hard';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingEasy => 'Easy';

  @override
  String get progressTitle => 'Progress';

  @override
  String get progressNoData => 'No review data yet';

  @override
  String get streakCardTitle => 'Streak';

  @override
  String streakDaysLabel(int count) {
    return '$count days';
  }

  @override
  String streakLongest(int count) {
    return 'Longest: $count days';
  }

  @override
  String get streakFreezeLabel => 'Freeze';

  @override
  String streakFreezeCount(int credits, int capacity) {
    return '$credits/$capacity';
  }

  @override
  String streakFreezeInfo(int needed) {
    return 'Review $needed days to earn a freeze credit. A freeze keeps your streak alive for one missed day.';
  }

  @override
  String get streakFreezeFull => 'Freeze credits full';

  @override
  String get reviewsCardTitle => 'Reviews';

  @override
  String reviewsDayTotal(int count) {
    return '$count reviews';
  }

  @override
  String get reviewScheduleTitle => 'Review Schedule';

  @override
  String get bucketNew => 'New';

  @override
  String get bucketToday => 'Today';

  @override
  String get bucket1to7 => '1-7 days';

  @override
  String get bucket8to30 => '8-30 days';

  @override
  String get bucket31to90 => '31-90 days';

  @override
  String get bucket91to360 => '91-360 days';

  @override
  String get bucket1to2y => '1-2 years';

  @override
  String get bucketLater => 'Later';

  @override
  String get scheduleEmpty => 'No cards in the schedule';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsAccountEmail => 'Email';

  @override
  String get settingsSyncStatus => 'Sync status';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get settingsSignOut => 'Log out';

  @override
  String get signOutTitle => 'Log out?';

  @override
  String get signOutBody => 'Local data on this device will be cleared.';

  @override
  String get signOutConfirm => 'Log out';

  @override
  String get signOutCancel => 'Cancel';

  @override
  String get settingsSchedulingSection => 'Scheduling';

  @override
  String get settingsDesiredRetention => 'Desired retention';

  @override
  String get settingsLearningSteps => 'Learning steps (minutes)';

  @override
  String get settingsRelearningSteps => 'Relearning steps (minutes)';

  @override
  String get settingsMaxInterval => 'Maximum interval (days)';

  @override
  String get settingsEnableFuzz => 'Enable fuzz';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsSaveHint => 'Changes affect future reviews only';

  @override
  String get settingsResetDefaults => 'Reset to defaults';

  @override
  String get settingsInvalidValue => 'Please check the values';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsEnableNotifications => 'Enable daily reminder';

  @override
  String get settingsNotificationTime => 'Reminder time';

  @override
  String get settingsPickTime => 'Pick time';

  @override
  String get settingsNotificationsUnsupported =>
      'Notifications are not supported on this platform';

  @override
  String get settingsNotificationsDenied => 'Notification permission denied';

  @override
  String get settingsReviewSection => 'Review';

  @override
  String get settingsReviewAnimations => 'Review Animations';

  @override
  String get settingsReviewAnimationsBody =>
      'Show animations after rating a card';

  @override
  String get settingsReviewAnimationsLowPowerHint =>
      'Low Power Mode temporarily disables review animations without changing this setting.';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageAuto => 'Auto (system)';

  @override
  String get settingsLanguageFollowsSystem => 'Follows system language';

  @override
  String get settingsDangerSection => 'Danger Zone';

  @override
  String get settingsResetProgress => 'Reset study progress';

  @override
  String get settingsResetProgressBody =>
      'This clears all study progress on this device and on the server. It cannot be undone.';

  @override
  String get settingsDeleteWorkspace => 'Delete current workspace';

  @override
  String get settingsWorkspaceSection => 'Workspace';

  @override
  String get settingsWorkspaceLists => 'Lists';

  @override
  String get settingsWorkspaceListsBody =>
      'Create smart lists to filter your reviews';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsDelete => 'Delete';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get notificationDailyBody =>
      'Time for today\'s SceneLex review session.';

  @override
  String get notificationChannelName => 'Daily review reminder';
}
