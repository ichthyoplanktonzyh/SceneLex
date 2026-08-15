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
  String get reviewTagSummaryNone => 'No tags';

  @override
  String get reviewRepetitionNew => 'New';

  @override
  String reviewRepetitionCount(int count) {
    return '$count reps';
  }

  @override
  String reviewQueueBadgeTooltip(int count) {
    return '$count words due';
  }

  @override
  String get reviewEmptyBrowseCards => 'Browse words';

  @override
  String get cardsFilterTitle => 'Filter by tags';

  @override
  String get cardsFilterClear => 'Clear';

  @override
  String get cardsFilterApply => 'Apply';

  @override
  String get cardsFilterEmpty => 'No words match the selected tags';

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
  String settingsDeletePreviewBody(
    int learningStates,
    int reviewEvents,
    int lists,
  ) {
    return 'This will delete $learningStates word states, $reviewEvents review records, and $lists lists.';
  }

  @override
  String settingsResetProgressPreviewBody(
    int learningStates,
    int reviewEvents,
  ) {
    return 'This will clear $learningStates word states and delete $reviewEvents review records.';
  }

  @override
  String get settingsPreviewLearningStates => 'Word states';

  @override
  String get settingsPreviewReviewEvents => 'Review records';

  @override
  String get settingsPreviewLists => 'Lists';

  @override
  String get settingsDangerLoading => 'Checking what will be affected…';

  @override
  String get settingsDangerRetry => 'Retry';

  @override
  String settingsWorkspaceNotSoleMember(String action) {
    return 'This workspace has other members, so it cannot be $action.';
  }

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
  String get settingsWorkspaceTags => 'Tags';

  @override
  String get settingsWorkspaceTagsBody =>
      'Browse read-only tags derived from word metadata';

  @override
  String get tagsScreenSubtitle =>
      'Tags are read-only labels derived from each word\'s metadata (type and part of speech). Tap a tag to review the words that carry it.';

  @override
  String tagsScreenCountLabel(int count) {
    return '$count tags';
  }

  @override
  String get tagsScreenEmpty =>
      'No tags yet. Tags appear once words are added to study.';

  @override
  String tagsScreenLearnedCount(int count) {
    return '$count words';
  }

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

  @override
  String get experienceRuntimeRoleAnchor => 'First look';

  @override
  String get experienceRuntimeRoleVariation => 'What stays the same';

  @override
  String get experienceRuntimeRolePerturbation => 'Change one thing';

  @override
  String get experienceRuntimeRoleDiscrimination => 'Choose the right one';

  @override
  String get experienceRuntimeRoleTransfer => 'Take it further';

  @override
  String experienceRuntimeProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get experienceRuntimeContinue => 'Continue';

  @override
  String get experienceRuntimeBack => 'Back';

  @override
  String get experienceRuntimeEvidenceLabel => 'What you can see';

  @override
  String get experienceRuntimeCorrect => 'Correct';

  @override
  String get experienceRuntimeIncorrect => 'Not quite';

  @override
  String get experienceRuntimePronunciation => 'Listen';

  @override
  String get experienceRuntimeGroundingBackToExperience =>
      'The moment you just saw';

  @override
  String get experienceRuntimeConstructions => 'Structures';

  @override
  String get experienceRuntimeCollocations => 'Word partners';

  @override
  String get experienceRuntimeCompleteTitle => 'Session complete';

  @override
  String get experienceRuntimeCompleteExperiences => 'experiences completed';

  @override
  String experienceRuntimeCompleteFirstAttempt(int correct, int total) {
    return '$correct of $total correct on the first try';
  }

  @override
  String get experienceRuntimeReplay => 'Re-experience';

  @override
  String get experienceRuntimeLoadErrorTitle =>
      'Could not load this experience';

  @override
  String get experienceRuntimeRetry => 'Try again';

  @override
  String get tabHome => 'Home';

  @override
  String get tabMap => 'Concept map';

  @override
  String get tabContent => 'My content';

  @override
  String get tabStudy => 'My study';

  @override
  String get homeLearnCta => 'Learn';

  @override
  String get homeReviewCta => 'Review';

  @override
  String get homeNewSensesLabel => 'new senses to learn';

  @override
  String get homeDueLabel => 'senses due for review';

  @override
  String get homeCheckin => 'Check in';

  @override
  String get homeCheckedIn => 'Checked in';

  @override
  String get homeToday => 'Today';

  @override
  String get homeCheckinDone => 'Daily check-in recorded';

  @override
  String get homeSubtitle => 'SceneLex · product v1';

  @override
  String get homeSkyAlt => 'SceneLex night sky';

  @override
  String get homeLoadError => 'Could not load content';

  @override
  String get learnExitTitle => 'Exit this learning session?';

  @override
  String get learnExitBody => 'Progress is saved and you can resume later.';

  @override
  String get learnResume => 'Resume learning';

  @override
  String get learnQuit => 'Quit';

  @override
  String get learnRemovedFavorite => 'Removed from experience favorites';

  @override
  String get learnAddedFavorite => 'Added to experience favorites';

  @override
  String get noteHint => 'Write something…';

  @override
  String get noteDelete => 'Delete';

  @override
  String get noteSave => 'Save';

  @override
  String get phaseSymbolReveal => 'Symbol reveal';

  @override
  String get phaseSymbolRevealSub => 'From experience to L2';

  @override
  String get phaseSymbolBinding => 'Bind L2 symbol';

  @override
  String get phaseL2Usage => 'L2 usage';

  @override
  String get phaseTransfer => 'L1 transfer';

  @override
  String get phaseFormation => 'L1 formation';

  @override
  String get learnFinishGroup => 'Finish group';

  @override
  String get learnNextWord => 'Next word';

  @override
  String get learnContinue => 'Continue';

  @override
  String get learnAnswerFirst => 'Answer first';

  @override
  String get learnWriteNote => 'Write note';

  @override
  String get learnPreferences => 'Learning preferences';

  @override
  String get learnRetreat => 'Back';

  @override
  String get learnFavorite => 'Favorite this experience';

  @override
  String get learnKnown => 'Known';

  @override
  String get learnMore => 'More';

  @override
  String get knownCheckUnavailable => 'No transfer check for this sense';

  @override
  String get knownCheckFailHint => 'Fail: return to the normal anchor flow.';

  @override
  String get knownCheckSkip => 'Skip remaining concept formation';

  @override
  String get knownCheckAnchor => 'Back to anchor flow';

  @override
  String get learnEmptyTitle => 'The catalog is fully studied';

  @override
  String get learnEmptyBody => 'New content appears here when published.';

  @override
  String get learnBackHome => 'Back to home';

  @override
  String get reviewQuit => 'Quit';

  @override
  String get reviewTransferTitle => 'Symbol recall check';

  @override
  String get reviewLoadError => 'Failed to load';

  @override
  String get recallDelayedRetrieval => 'Delayed retrieval · new experience';

  @override
  String get recallRevisit => 'Revisit · a passage you have not seen';

  @override
  String get recallPrompt => 'Which word fits this situation?';

  @override
  String get recallHint => 'Recall it yourself first, then look at the answer';

  @override
  String get revealShowAnswer => 'Show answer';

  @override
  String get reviewTransferDone => 'Symbol recall check complete';

  @override
  String get reviewDone => 'This round of review complete';

  @override
  String get reviewRetrieved => 'Recalled';

  @override
  String get reviewReviewed => 'Reviewed';

  @override
  String get reviewBackHome => 'Back to home';

  @override
  String get groupNoneInProgress => 'No group session in progress';

  @override
  String get groupBackHome => 'Back to home';

  @override
  String get groupDoneTitle => 'Group understanding complete';

  @override
  String get groupNewExperiences => 'New experiences';

  @override
  String get groupBoundaryDiscrimination => 'Boundary discrimination';

  @override
  String get groupMinutes => 'min';

  @override
  String get groupRest => 'Back home and rest';

  @override
  String get groupStartRecall => 'Start symbol recall check';

  @override
  String get groupGoReview => 'Go to review';

  @override
  String get mapTitle => 'Concept map';

  @override
  String get mapAll => 'All';

  @override
  String get mapLearned => 'Learned';

  @override
  String get mapEmpty => 'Nothing matches this filter';

  @override
  String get mapDiffDim => 'Different dimension';

  @override
  String get mapOverlap => 'Overlap';

  @override
  String get libNone => 'None';

  @override
  String get libTitle => 'My content';

  @override
  String get libReplay => 'Experience replay';

  @override
  String get libPreview => 'Preview';

  @override
  String get libTransfer => 'Transfer check';

  @override
  String get libTransferBody => 'Learned senses';

  @override
  String get libStudyLists => 'Study lists';

  @override
  String get libRecentLearned => 'Recently learned';

  @override
  String get libAllLearned => 'All learned';

  @override
  String get libConceptMap => 'My concept map';

  @override
  String get libFavorites => 'Experience favorites';

  @override
  String get libNotes => 'Notes';

  @override
  String get libReplayLabel => 'Replay';

  @override
  String get libReviewLabel => 'Review';

  @override
  String get libPreviewLabel => 'Preview';

  @override
  String get libLookFirst => 'Look first';

  @override
  String get libToday => 'Today';

  @override
  String get replayTitle => 'Experience replay';

  @override
  String get replayEmptyTitle => 'No learned experiences yet';

  @override
  String get replayEmptyBody => 'Finish a first-learn group, then replay.';

  @override
  String get replayNoExperience => 'No experience';

  @override
  String get replayUnfavorite => 'Unfavorite';

  @override
  String get replayFavorite => 'Favorite';

  @override
  String get replayPrev => 'Previous';

  @override
  String get replayNext => 'Next';

  @override
  String get previewTitle => 'Preview';

  @override
  String get previewEmpty => 'Nothing to preview';

  @override
  String get previewEnterLearn => 'Start first learn (next group)';

  @override
  String get previewNewSense => 'New sense · watch the anchor experience first';

  @override
  String get previewFromExperience => 'From experience into first learn';

  @override
  String get learnedRecent => 'Recently learned';

  @override
  String get learnedAll => 'All learned';

  @override
  String get learnedEmpty => 'No learned senses yet';

  @override
  String get learnedDue => 'Due for review';

  @override
  String get favTitle => 'Experience favorites';

  @override
  String get favUnfavorite => 'Unfavorite';

  @override
  String get notesTitle => 'Notes';

  @override
  String get studyTitle => 'My study';

  @override
  String get studyPreferences => 'Learning preferences';

  @override
  String get studyPlan => 'Plan';

  @override
  String get studyLists => 'Lists';

  @override
  String get studyScope => 'Current learning scope';

  @override
  String get studyBySense => 'Organized by sense, not by headword';

  @override
  String get studyDailyNew => 'New senses per day';

  @override
  String get studyStats => 'Stats';

  @override
  String get studyTodayLearnReview => 'Learned & reviewed today';

  @override
  String get studySenses => 'senses';

  @override
  String get studyCumulativeLearned => 'Cumulative learned';

  @override
  String get studyTodayMinutes => 'Minutes today';

  @override
  String get studyMinutes => 'min';

  @override
  String get studyCumulativeMinutes => 'Cumulative minutes';

  @override
  String get studyCheckinCalendar => 'Check-in calendar';

  @override
  String get studyTodayCol => 'T';

  @override
  String get profileLearning => 'Learning';

  @override
  String get profileReviewing => 'Reviewing';

  @override
  String get profileRelearning => 'Re-learning';

  @override
  String get profileNewCards => 'New';

  @override
  String get profileBack => 'Back';

  @override
  String get profileLearner => 'SceneLex learner';

  @override
  String get profileNoMember => 'No membership';

  @override
  String get profileLearnedSenses => 'Learned senses';

  @override
  String get profileExperiencesLoading => 'Counting experiences…';

  @override
  String get profileMastery => 'Mastery';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profilePreferences => 'Learning preferences';

  @override
  String get profileMoreSettings => 'More settings';

  @override
  String get profileNoRecords => 'No study records yet';

  @override
  String get prefSectionUnderstanding => 'Understanding flow';

  @override
  String get prefTransferTiming => 'Symbol recall timing';

  @override
  String get prefBoundaryPerturbation => 'Boundary perturbation';

  @override
  String get prefSymbolRecall => 'Symbol recall';

  @override
  String get prefScaffold => 'L1 scaffolding';

  @override
  String get prefScaffoldLevel => 'Narrative language level';

  @override
  String get prefScaffoldCurrent => 'Current level';

  @override
  String get prefAutoScaffoldRemoval => 'Auto removal';

  @override
  String get prefZhLabelBeforeReveal => 'Chinese label before reveal';

  @override
  String get prefSectionRhythm => 'Rhythm';

  @override
  String get prefNewGroup => 'New learn group';

  @override
  String get prefNewGroupHint => 'About 90 seconds per sense';

  @override
  String get prefReviewGroup => 'Review group';

  @override
  String get prefSectionVoice => 'Pronunciation & reminders';

  @override
  String get prefAccent => 'Accent';

  @override
  String get prefAccentUs => 'American';

  @override
  String get prefAccentUk => 'British';

  @override
  String get prefAutoPronounce => 'Auto pronounce';

  @override
  String get prefReminder => 'Study reminder';

  @override
  String get prefReminderHint => 'Maps to notification settings';

  @override
  String get prefTransferEndOfDay => 'End of day';

  @override
  String get prefTransferEndOfFirstLearning => 'End of first learn';

  @override
  String get prefTransferFirstReview => 'First review';

  @override
  String get prefScaffoldZh => 'Chinese';

  @override
  String get prefScaffoldMixed => 'Mixed';

  @override
  String get prefScaffoldEn => 'Pure English';

  @override
  String get prefReminderReveal => 'At symbol reveal';

  @override
  String get prefReminderRevealExample => 'Reveal + example';

  @override
  String get prefReminderOff => 'Off';

  @override
  String get prefReminderSmart => 'Smart reminder';

  @override
  String get prefReminderFixed => 'Fixed time';

  @override
  String get prefTitle => 'Learning preferences';

  @override
  String get homeProfile => 'Profile';

  @override
  String get brandTagline =>
      'Meaning is experience; micro-worlds are experience.';

  @override
  String get knownCheckTitle =>
      'Known · transfer check · will not mark as learned';

  @override
  String get knownCheckPassHint =>
      'Pass: recognize the concept → skip the rest of concept formation.';

  @override
  String get recallNewExperience =>
      'New experience · you have not seen this one';

  @override
  String get gradeNextUsesNewExperience =>
      'FSRS-6 · next review uses an unseen experience';

  @override
  String get reviewTransferDoneBody =>
      'Completed the delayed experience-to-symbol recall with brand-new experiences';

  @override
  String get transferIntro =>
      'Transfer was completed before each reveal. What follows is delayed symbol recall:';

  @override
  String get transferIntro2 =>
      'Watch a new experience — can you recall the L2 symbol you just bound?';

  @override
  String get transferDeferred =>
      'Transfer testing is deferred to the first review (current preference: first review).';

  @override
  String get transferAtEnd =>
      'Transfer testing already completed at the end of each first learn (current preference: end of first learn).';

  @override
  String get mapBoundariesNotCollected =>
      'Boundary relations (relations.boundaries) not yet collected — content debt, pending the compiler output.';

  @override
  String get replayOnlyScene =>
      'Only the scene replays — recalling the word is for review';

  @override
  String get favEmpty =>
      'Nothing yet. Star an experience while learning or replaying.';

  @override
  String get notesEmpty =>
      'No notes yet. Use the More menu in a first-learn session to note the current sense.';

  @override
  String get prefTransferTimingHint =>
      'Transfer is fixed before the reveal; this controls when experience-to-symbol is tested';

  @override
  String get prefBoundaryPerturbationHint =>
      'Contrast / counter-example scenes crush wrong generalizations';

  @override
  String get prefSymbolRecallHint =>
      'One scene-to-word retrieval after the reveal';

  @override
  String get prefAutoScaffoldRemovalHint =>
      'Steps down to pure English as reviews accumulate';

  @override
  String get prefZhLabelBeforeRevealHint =>
      'On = back to give-the-translation-first; off by default';

  @override
  String noteTitle(Object senseId) {
    return 'Note · $senseId';
  }

  @override
  String learnLoadError(Object errorMessage) {
    return 'Failed to load: $errorMessage';
  }

  @override
  String learnWordProgress(Object index, Object count) {
    return 'Word $index / $count';
  }

  @override
  String reviewDoneBody(Object gradedCount) {
    return '$gradedCount review events written locally';
  }

  @override
  String groupDoneBody(Object senseCount) {
    return 'Experiences for $senseCount senses have been built';
  }

  @override
  String mapLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String mapBoundaryCriterion(Object diagnostic) {
    return 'Criterion: $diagnostic';
  }

  @override
  String libRecent7d(Object recentCount) {
    return 'Past 7 days · $recentCount senses';
  }

  @override
  String libReplayBody(Object learnedCount) {
    return '$learnedCount sense experiences';
  }

  @override
  String libPreviewBody(Object clamped) {
    return '$clamped scenes';
  }

  @override
  String libStudyListsBody(Object learnedCount) {
    return '$learnedCount senses';
  }

  @override
  String libAllLearnedBody(Object learnedCount) {
    return '$learnedCount senses';
  }

  @override
  String libConceptMapBody(Object catalogSize) {
    return '$catalogSize senses';
  }

  @override
  String libFavoritesBody(Object favoritesCount) {
    return '$favoritesCount items';
  }

  @override
  String libNotesBody(Object notesCount) {
    return '$notesCount notes';
  }

  @override
  String replayLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String replayCounter(Object index, Object total) {
    return 'Experience $index / $total';
  }

  @override
  String previewLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String learnedLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String learnedReviewedN(Object reps) {
    return 'Reviewed $reps times';
  }

  @override
  String favLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String notesLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String studyLoadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String studyLearned(Object learnedCount) {
    return 'Learned $learnedCount';
  }

  @override
  String studyCatalogSize(Object catalogSize) {
    return 'Total senses $catalogSize';
  }

  @override
  String studyDailyGoal(Object dailyGoal) {
    return '$dailyGoal / day';
  }

  @override
  String studyStreak(Object streakDays) {
    return '$streakDays-day streak';
  }

  @override
  String profileExperienceCount(Object count) {
    return '$count experience scenes';
  }

  @override
  String profileFsrsSummary(Object total) {
    return 'FSRS state distribution · $total senses';
  }

  @override
  String prefNewGroupSize(Object groupSize) {
    return '$groupSize senses / group';
  }

  @override
  String prefReviewGroupSize(Object groupSize) {
    return '$groupSize senses / group';
  }

  @override
  String get journeyHomeGreeting => 'Good morning';

  @override
  String get journeyHomeJourneyTitle => 'Today\'s Journey';

  @override
  String journeyHomeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String journeyHomeTaskSummary(
    int recall,
    int newConcepts,
    int boundary,
    int transfer,
  ) {
    return '$recall recall · $newConcepts new concepts · $boundary boundary · $transfer transfer';
  }

  @override
  String get journeyHomeExplanation =>
      'Wake up an old concept, build two new ones, then check where they meet.';

  @override
  String get journeyHomeContinue => 'Continue Journey';

  @override
  String get journeyHomeContinueAgain => 'Continue Journey Again';

  @override
  String get journeyHomeDone => 'Journey complete';

  @override
  String get journeyHomeSemanticMap => 'Semantic Map';

  @override
  String get journeyHomeExplore => 'Explore';

  @override
  String get journeyHomeSecondaryHint =>
      'System-guided learning · free exploration is one tap away';

  @override
  String get journeySessionTitle => 'Today\'s Journey';

  @override
  String get journeySessionQuit => 'Quit journey';

  @override
  String get journeyTaskRecall => 'Recall';

  @override
  String get journeyTaskDiscover => 'Discover';

  @override
  String get journeyTaskBoundary => 'Boundary';

  @override
  String get journeyTaskTransfer => 'Transfer';

  @override
  String get journeyRecallPrompt =>
      'Which word does this scene make you think of? Recall it in your mind.';

  @override
  String get journeyRecallHint => 'Think of the word before checking.';

  @override
  String get journeyRecallReveal => 'Reveal';

  @override
  String get journeyRecallForgot => 'Forgot';

  @override
  String get journeyRecallHard => 'Hard';

  @override
  String get journeyRecallGotIt => 'Got it';

  @override
  String get journeyBoundaryPrompt =>
      'Which concept does this scene come closer to?';

  @override
  String get journeyBoundaryCorrect => 'Yes — this scene belongs here.';

  @override
  String get journeyBoundaryIncorrect =>
      'Not quite — check the key difference.';

  @override
  String get journeyBoundaryKey => 'THE KEY DIFFERENCE';

  @override
  String get journeyTransferHint =>
      'A brand-new situation — does the concept still hold?';

  @override
  String get journeyTransferCorrect => 'Transferred';

  @override
  String get journeyTransferIncorrect => 'Not quite';

  @override
  String get journeyContinue => 'Continue';

  @override
  String get journeyNextTask => 'Next task';

  @override
  String get journeyFinishJourney => 'Finish Journey';

  @override
  String get journeySkipTask => 'Skip task';

  @override
  String get journeyTaskUnavailable =>
      'This task\'s content is not available yet.';

  @override
  String get journeyCompleteTitle => 'Today\'s Journey Complete';

  @override
  String get journeyCompleteGrew => 'Your semantic map grew.';

  @override
  String journeyLedgerRecalled(String lemma) {
    return 'Woke up $lemma';
  }

  @override
  String journeyLedgerEstablished(String lemma) {
    return 'Established $lemma';
  }

  @override
  String journeyLedgerBoundary(String a, String b) {
    return 'Distinguished $a / $b';
  }

  @override
  String journeyLedgerTransfer(String lemma) {
    return 'Transferred $lemma to a new situation';
  }

  @override
  String get journeyCompleteViewMap => 'View Semantic Map';

  @override
  String get journeyCompleteBackHome => 'Back Home';

  @override
  String get journeyCompleteNewBadge => 'NEW';

  @override
  String get journeyCompleteNewBoundary => 'New boundary';

  @override
  String get journeyMapTitle => 'Semantic Map';

  @override
  String get journeyMapHint => 'Drag to explore · tap a node for details';

  @override
  String get journeyMapStatusMastered => 'Mastered';

  @override
  String get journeyMapStatusLearning => 'Learning';

  @override
  String get journeyMapStatusNewlyLearned => 'Newly learned';

  @override
  String get journeyMapStatusUnseen => 'Unseen';

  @override
  String get journeyMapDetailStatus => 'CURRENT STATUS';

  @override
  String get journeyMapDetailSymbol => 'SYMBOL RECALL';

  @override
  String get journeyMapDetailMeaning => 'MEANING';

  @override
  String get journeyMapDetailBoundary => 'RELATED BOUNDARY';

  @override
  String journeyMapBoundaryEdge(String a, String b) {
    return '$a ↔ $b';
  }

  @override
  String get journeyExploreTitle => 'Explore';

  @override
  String get journeyExploreSubtitle =>
      'Browse the real catalog — every sense below comes from the bundled content.';
}
