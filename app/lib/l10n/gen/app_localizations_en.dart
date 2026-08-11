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
  String get loginCodePrompt =>
      'Enter the 8-digit code from your email. If you don\'t see it, check your spam folder.';

  @override
  String get loginResendCode => 'Resend code';

  @override
  String loginResendIn(int seconds) {
    return 'Resend code (${seconds}s)';
  }

  @override
  String get loginChangeEmail => 'Use a different email';

  @override
  String get loginErrorRateLimited => 'Too many requests. Try again later.';

  @override
  String get loginErrorAccountDeleted => 'This account has been deleted.';

  @override
  String get loginErrorCodeExpired => 'This code expired. Request a new code.';

  @override
  String get loginErrorCodeAlreadyUsed =>
      'This code was already used. Request a new code.';

  @override
  String get loginErrorTooManyAttempts =>
      'Too many invalid attempts. Request a new code.';

  @override
  String get loginErrorInvalidCode => 'Invalid code.';

  @override
  String get loginErrorInternalError =>
      'Something went wrong. Please try again.';

  @override
  String get loginErrorUnknown => 'Sign-in failed. Please try again.';

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
  String get cardMetaDue => 'Due';

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
  String get reviewIntervalLessThanMinute => 'in less than a minute';

  @override
  String reviewIntervalMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count minutes',
      one: 'in $count minute',
    );
    return '$_temp0';
  }

  @override
  String reviewIntervalHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count hours',
      one: 'in $count hour',
    );
    return '$_temp0';
  }

  @override
  String reviewIntervalDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in $count day',
    );
    return '$_temp0';
  }

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
  String get settingsAccountStatus => 'Account status';

  @override
  String get settingsAccountStatusLinked => 'Linked';

  @override
  String get settingsSyncStatus => 'Sync status';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get settingsLastSync => 'Last sync';

  @override
  String get settingsLastSyncNever => 'Never';

  @override
  String settingsLastSyncValue(String time) {
    return 'Last synced $time';
  }

  @override
  String get settingsSyncNow => 'Sync now';

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
  String get settingsNotificationsMode => 'Mode';

  @override
  String get settingsNotificationsModeDaily => 'Once daily';

  @override
  String get settingsNotificationsModeInactivity => 'Inactivity';

  @override
  String get settingsNotificationsInactivityBody =>
      'The first reminder arrives after inactivity during this window. Later reminders repeat at the chosen interval.';

  @override
  String get settingsNotificationsFrom => 'From';

  @override
  String get settingsNotificationsTo => 'To';

  @override
  String get settingsNotificationsRepeatEvery => 'Repeat every';

  @override
  String get settingsNotificationsOneHour => '1 hour';

  @override
  String settingsNotificationsHours(int count) {
    return '$count hours';
  }

  @override
  String settingsNotificationsMinutes(int count) {
    return '$count minutes';
  }

  @override
  String get settingsNotificationsBadge => 'Show app icon badge';

  @override
  String get settingsNotificationsBadgeBody =>
      'Show a red 1 on the app icon when a reminder fires and you have not reviewed today.';

  @override
  String get settingsNotificationsStrict => 'Enable streak reminders';

  @override
  String get settingsNotificationsStrictBody =>
      'If you have not reviewed today, SceneLex reminds you 4, 3, and 2 hours before midnight so you can keep your streak.';

  @override
  String get settingsNotificationsFooter =>
      'Study reminders stay on this device.';

  @override
  String get settingsNotificationsOff => 'Off';

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
  String get settingsDeleteWorkspaceBody =>
      'Type \"delete workspace\" to confirm. The workspace and all its study progress are deleted.';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountBody =>
      'Permanently delete your account and all data';

  @override
  String get settingsDeleteAccountPhrase =>
      'Type \"delete my account\" to confirm. This cannot be undone.';

  @override
  String get settingsDeleteAccountConfirm => 'Delete account';

  @override
  String settingsTypeToConfirm(String phrase) {
    return 'Type $phrase to confirm';
  }

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsOpenSource => 'Open Source';

  @override
  String get settingsOpenSourceBody =>
      'SceneLex is open source and builds on flashcards-open-source-app (MIT). Review reaction animations use Lottie assets from the same project (MIT).';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsLegalBody =>
      'SceneLex is a local-first study tool. Study data syncs to your own server. See the project license for details.';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsSupportBody =>
      'For help and bug reports, open an issue in the project repository. Feedback helps shape the next version.';

  @override
  String get settingsServerInfo => 'Server info';

  @override
  String get settingsServerInfoApi => 'API endpoint';

  @override
  String get settingsServerInfoAccount => 'Account';

  @override
  String get settingsDeviceInfo => 'Device info';

  @override
  String get settingsDevicePlatform => 'Platform';

  @override
  String get settingsShareApp => 'Share app';

  @override
  String get settingsWorkspaceSection => 'Workspace';

  @override
  String get settingsWorkspaceCurrent => 'Workspace';

  @override
  String get settingsWorkspaceSwitch => 'Switch or create a workspace';

  @override
  String get settingsWorkspaceRename => 'Rename';

  @override
  String get settingsWorkspaceCreate => 'Create workspace';

  @override
  String get settingsWorkspaceSelected => 'Selected';

  @override
  String settingsWorkspaceCreated(String name) {
    return 'Workspace created: $name';
  }

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

  @override
  String get reviewHardReminderTitle => 'Quick reminder';

  @override
  String get reviewHardReminderBody =>
      'If you did not know the answer, choose \"Again\". \"Hard\" is only for answers you knew but it was difficult to recall.';

  @override
  String get reviewHardReminderDismiss => 'Got it';

  @override
  String get reviewSubmitError => 'Review wasn\'t saved';

  @override
  String reviewBadgeTooltip(int days) {
    return 'Review streak $days days. Not reviewed today.';
  }

  @override
  String reviewBadgeTooltipReviewed(int days) {
    return 'Review streak $days days. Reviewed today.';
  }
}
