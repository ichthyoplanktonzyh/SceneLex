import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SceneLex'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Meaning is experience; micro-worlds are experience.'**
  String get appTagline;

  /// No description provided for @tabReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get tabReview;

  /// No description provided for @tabProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tabProgress;

  /// No description provided for @tabCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get tabCards;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @loadingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadingFailed(String error);

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'8-digit code'**
  String get loginOtpLabel;

  /// No description provided for @loginSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendCode;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @cardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cardsTitle;

  /// No description provided for @cardsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search senses'**
  String get cardsSearchHint;

  /// No description provided for @cardsEmptyLibrary.
  ///
  /// In en, this message translates to:
  /// **'Empty library. Run import_content.py first.'**
  String get cardsEmptyLibrary;

  /// No description provided for @cardsEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No matching senses'**
  String get cardsEmptySearch;

  /// No description provided for @cardsStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get cardsStudy;

  /// No description provided for @cardsAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get cardsAdded;

  /// No description provided for @cardStateNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get cardStateNotAdded;

  /// No description provided for @cardStateNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get cardStateNew;

  /// No description provided for @cardStateLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get cardStateLearning;

  /// No description provided for @cardStateRelearning.
  ///
  /// In en, this message translates to:
  /// **'Relearning'**
  String get cardStateRelearning;

  /// No description provided for @cardStateReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get cardStateReview;

  /// No description provided for @cardStateNext.
  ///
  /// In en, this message translates to:
  /// **'next {date}'**
  String cardStateNext(String date);

  /// No description provided for @cardStatDue.
  ///
  /// In en, this message translates to:
  /// **'{count} due'**
  String cardStatDue(int count);

  /// No description provided for @cardStatReps.
  ///
  /// In en, this message translates to:
  /// **'{count} reps'**
  String cardStatReps(int count);

  /// No description provided for @cardStatLapses.
  ///
  /// In en, this message translates to:
  /// **'{count} lapses'**
  String cardStatLapses(int count);

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reviewTitle;

  /// No description provided for @reviewEmptyNoSenses.
  ///
  /// In en, this message translates to:
  /// **'No senses being studied yet'**
  String get reviewEmptyNoSenses;

  /// No description provided for @reviewEmptyNoDue.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get reviewEmptyNoDue;

  /// No description provided for @reviewEmptyGoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add senses from the Cards tab'**
  String get reviewEmptyGoAdd;

  /// No description provided for @reviewEmptyAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done. See you tomorrow.'**
  String get reviewEmptyAllDone;

  /// No description provided for @reviewEmptySwitchToAll.
  ///
  /// In en, this message translates to:
  /// **'Switch to all cards deck'**
  String get reviewEmptySwitchToAll;

  /// No description provided for @reviewFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get reviewFilterTitle;

  /// No description provided for @reviewFilterLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get reviewFilterLists;

  /// No description provided for @reviewFilterTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get reviewFilterTags;

  /// No description provided for @reviewFilterManage.
  ///
  /// In en, this message translates to:
  /// **'Manage lists'**
  String get reviewFilterManage;

  /// No description provided for @reviewFilterDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reviewFilterDone;

  /// No description provided for @listsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get listsTitle;

  /// No description provided for @listsAllCards.
  ///
  /// In en, this message translates to:
  /// **'All Cards'**
  String get listsAllCards;

  /// No description provided for @listsAllCardsBody.
  ///
  /// In en, this message translates to:
  /// **'{count} cards'**
  String listsAllCardsBody(int count);

  /// No description provided for @listsCreate.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get listsCreate;

  /// No description provided for @listsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get listsEdit;

  /// No description provided for @listsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get listsDelete;

  /// No description provided for @listsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this list?'**
  String get listsDeleteTitle;

  /// No description provided for @listsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The list and its rule will be removed from this device and the next sync. No study progress is deleted.'**
  String get listsDeleteBody;

  /// No description provided for @listsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lists yet. Create a list to study a subset of words.'**
  String get listsEmpty;

  /// No description provided for @listsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get listsNameLabel;

  /// No description provided for @listsTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags (select at least one)'**
  String get listsTagsLabel;

  /// No description provided for @listsSaveHint.
  ///
  /// In en, this message translates to:
  /// **'A list matches a word when the word carries at least one of the selected tags.'**
  String get listsSaveHint;

  /// No description provided for @listsNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags available yet.'**
  String get listsNoTags;

  /// No description provided for @listsMatchedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} matching cards'**
  String listsMatchedCount(int count);

  /// No description provided for @listsDetailRules.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get listsDetailRules;

  /// No description provided for @listsDetailStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get listsDetailStats;

  /// No description provided for @listsDetailMatched.
  ///
  /// In en, this message translates to:
  /// **'Matching cards'**
  String get listsDetailMatched;

  /// No description provided for @listsMatchedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No studied words match this list yet.'**
  String get listsMatchedEmpty;

  /// No description provided for @listsStatMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get listsStatMatched;

  /// No description provided for @listsStatDue.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get listsStatDue;

  /// No description provided for @listsReviewThisDeck.
  ///
  /// In en, this message translates to:
  /// **'Review this list'**
  String get listsReviewThisDeck;

  /// No description provided for @cardRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cardRemove;

  /// No description provided for @cardRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from study?'**
  String get cardRemoveTitle;

  /// No description provided for @cardRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the word from the local list and the next sync. You can add it again any time.'**
  String get cardRemoveBody;

  /// No description provided for @stageAnchor.
  ///
  /// In en, this message translates to:
  /// **'Prototype'**
  String get stageAnchor;

  /// No description provided for @stageVariation.
  ///
  /// In en, this message translates to:
  /// **'Variation'**
  String get stageVariation;

  /// No description provided for @stagePerturbation.
  ///
  /// In en, this message translates to:
  /// **'Perturbation'**
  String get stagePerturbation;

  /// No description provided for @stageDiscrimination.
  ///
  /// In en, this message translates to:
  /// **'Discrimination'**
  String get stageDiscrimination;

  /// No description provided for @stageSymbolBinding.
  ///
  /// In en, this message translates to:
  /// **'Symbol binding'**
  String get stageSymbolBinding;

  /// No description provided for @stageL2Grounding.
  ///
  /// In en, this message translates to:
  /// **'L2 grounding'**
  String get stageL2Grounding;

  /// No description provided for @stageTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get stageTransfer;

  /// No description provided for @hintAnchor.
  ///
  /// In en, this message translates to:
  /// **'First, experience the typical experience this word grows from.'**
  String get hintAnchor;

  /// No description provided for @hintVariation.
  ///
  /// In en, this message translates to:
  /// **'The situation changed, the experience structure did not — find what stayed the same.'**
  String get hintVariation;

  /// No description provided for @hintPerturbation.
  ///
  /// In en, this message translates to:
  /// **'Change one variable: is it still the same word?'**
  String get hintPerturbation;

  /// No description provided for @hintDiscrimination.
  ///
  /// In en, this message translates to:
  /// **'Two mental states — are they the same?'**
  String get hintDiscrimination;

  /// No description provided for @hintSymbolBinding.
  ///
  /// In en, this message translates to:
  /// **'The experience you keep recognizing is expressed like this in English.'**
  String get hintSymbolBinding;

  /// No description provided for @hintL2Grounding.
  ///
  /// In en, this message translates to:
  /// **'How this word is used in real language.'**
  String get hintL2Grounding;

  /// No description provided for @hintTransfer.
  ///
  /// In en, this message translates to:
  /// **'A brand new experience: does the word hold?'**
  String get hintTransfer;

  /// No description provided for @playerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load program: {error}'**
  String playerLoadFailed(String error);

  /// No description provided for @speechListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get speechListen;

  /// No description provided for @speechStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get speechStop;

  /// No description provided for @speechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech is not available'**
  String get speechUnavailable;

  /// No description provided for @playerNoUnits.
  ///
  /// In en, this message translates to:
  /// **'No playable experience for this sense yet.'**
  String get playerNoUnits;

  /// No description provided for @playerNoSynopsis.
  ///
  /// In en, this message translates to:
  /// **'(no synopsis)'**
  String get playerNoSynopsis;

  /// No description provided for @playerTaskJudge.
  ///
  /// In en, this message translates to:
  /// **'Judgment'**
  String get playerTaskJudge;

  /// No description provided for @playerTaskPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(task)'**
  String get playerTaskPlaceholder;

  /// No description provided for @playerFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish the experience'**
  String get playerFinish;

  /// No description provided for @playerContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get playerContinue;

  /// No description provided for @playerRatingQuestion.
  ///
  /// In en, this message translates to:
  /// **'How well do you remember this experience?'**
  String get playerRatingQuestion;

  /// No description provided for @ratingAgain.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get ratingAgain;

  /// No description provided for @ratingHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get ratingHard;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get ratingEasy;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// No description provided for @progressNoData.
  ///
  /// In en, this message translates to:
  /// **'No review data yet'**
  String get progressNoData;

  /// No description provided for @streakCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakCardTitle;

  /// No description provided for @streakDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String streakDaysLabel(int count);

  /// No description provided for @streakLongest.
  ///
  /// In en, this message translates to:
  /// **'Longest: {count} days'**
  String streakLongest(int count);

  /// No description provided for @streakFreezeLabel.
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get streakFreezeLabel;

  /// No description provided for @streakFreezeCount.
  ///
  /// In en, this message translates to:
  /// **'{credits}/{capacity}'**
  String streakFreezeCount(int credits, int capacity);

  /// No description provided for @streakFreezeInfo.
  ///
  /// In en, this message translates to:
  /// **'Review {needed} days to earn a freeze credit. A freeze keeps your streak alive for one missed day.'**
  String streakFreezeInfo(int needed);

  /// No description provided for @streakFreezeFull.
  ///
  /// In en, this message translates to:
  /// **'Freeze credits full'**
  String get streakFreezeFull;

  /// No description provided for @reviewsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsCardTitle;

  /// No description provided for @reviewsDayTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsDayTotal(int count);

  /// No description provided for @reviewScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Schedule'**
  String get reviewScheduleTitle;

  /// No description provided for @bucketNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get bucketNew;

  /// No description provided for @bucketToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get bucketToday;

  /// No description provided for @bucket1to7.
  ///
  /// In en, this message translates to:
  /// **'1-7 days'**
  String get bucket1to7;

  /// No description provided for @bucket8to30.
  ///
  /// In en, this message translates to:
  /// **'8-30 days'**
  String get bucket8to30;

  /// No description provided for @bucket31to90.
  ///
  /// In en, this message translates to:
  /// **'31-90 days'**
  String get bucket31to90;

  /// No description provided for @bucket91to360.
  ///
  /// In en, this message translates to:
  /// **'91-360 days'**
  String get bucket91to360;

  /// No description provided for @bucket1to2y.
  ///
  /// In en, this message translates to:
  /// **'1-2 years'**
  String get bucket1to2y;

  /// No description provided for @bucketLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get bucketLater;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cards in the schedule'**
  String get scheduleEmpty;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsAccountEmail;

  /// No description provided for @settingsSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get settingsSyncStatus;

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncStatusOffline;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsSignOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Local data on this device will be cleared.'**
  String get signOutBody;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get signOutConfirm;

  /// No description provided for @signOutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get signOutCancel;

  /// No description provided for @settingsSchedulingSection.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get settingsSchedulingSection;

  /// No description provided for @settingsDesiredRetention.
  ///
  /// In en, this message translates to:
  /// **'Desired retention'**
  String get settingsDesiredRetention;

  /// No description provided for @settingsLearningSteps.
  ///
  /// In en, this message translates to:
  /// **'Learning steps (minutes)'**
  String get settingsLearningSteps;

  /// No description provided for @settingsRelearningSteps.
  ///
  /// In en, this message translates to:
  /// **'Relearning steps (minutes)'**
  String get settingsRelearningSteps;

  /// No description provided for @settingsMaxInterval.
  ///
  /// In en, this message translates to:
  /// **'Maximum interval (days)'**
  String get settingsMaxInterval;

  /// No description provided for @settingsEnableFuzz.
  ///
  /// In en, this message translates to:
  /// **'Enable fuzz'**
  String get settingsEnableFuzz;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Changes affect future reviews only'**
  String get settingsSaveHint;

  /// No description provided for @settingsResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsResetDefaults;

  /// No description provided for @settingsInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Please check the values'**
  String get settingsInvalidValue;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable daily reminder'**
  String get settingsEnableNotifications;

  /// No description provided for @settingsNotificationTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get settingsNotificationTime;

  /// No description provided for @settingsPickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get settingsPickTime;

  /// No description provided for @settingsNotificationsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not supported on this platform'**
  String get settingsNotificationsUnsupported;

  /// No description provided for @settingsNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission denied'**
  String get settingsNotificationsDenied;

  /// No description provided for @settingsNotificationsMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get settingsNotificationsMode;

  /// No description provided for @settingsNotificationsModeDaily.
  ///
  /// In en, this message translates to:
  /// **'Once daily'**
  String get settingsNotificationsModeDaily;

  /// No description provided for @settingsNotificationsModeInactivity.
  ///
  /// In en, this message translates to:
  /// **'Inactivity'**
  String get settingsNotificationsModeInactivity;

  /// No description provided for @settingsNotificationsInactivityBody.
  ///
  /// In en, this message translates to:
  /// **'The first reminder arrives after inactivity during this window. Later reminders repeat at the chosen interval.'**
  String get settingsNotificationsInactivityBody;

  /// No description provided for @settingsNotificationsFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get settingsNotificationsFrom;

  /// No description provided for @settingsNotificationsTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get settingsNotificationsTo;

  /// No description provided for @settingsNotificationsRepeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get settingsNotificationsRepeatEvery;

  /// No description provided for @settingsNotificationsOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get settingsNotificationsOneHour;

  /// No description provided for @settingsNotificationsHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hours'**
  String settingsNotificationsHours(int count);

  /// No description provided for @settingsNotificationsMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String settingsNotificationsMinutes(int count);

  /// No description provided for @settingsNotificationsBadge.
  ///
  /// In en, this message translates to:
  /// **'Show app icon badge'**
  String get settingsNotificationsBadge;

  /// No description provided for @settingsNotificationsBadgeBody.
  ///
  /// In en, this message translates to:
  /// **'Show a red 1 on the app icon when a reminder fires and you have not reviewed today.'**
  String get settingsNotificationsBadgeBody;

  /// No description provided for @settingsNotificationsStrict.
  ///
  /// In en, this message translates to:
  /// **'Enable streak reminders'**
  String get settingsNotificationsStrict;

  /// No description provided for @settingsNotificationsStrictBody.
  ///
  /// In en, this message translates to:
  /// **'If you have not reviewed today, SceneLex reminds you 4, 3, and 2 hours before midnight so you can keep your streak.'**
  String get settingsNotificationsStrictBody;

  /// No description provided for @settingsNotificationsFooter.
  ///
  /// In en, this message translates to:
  /// **'Study reminders stay on this device.'**
  String get settingsNotificationsFooter;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsReviewSection.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get settingsReviewSection;

  /// No description provided for @settingsReviewAnimations.
  ///
  /// In en, this message translates to:
  /// **'Review Animations'**
  String get settingsReviewAnimations;

  /// No description provided for @settingsReviewAnimationsBody.
  ///
  /// In en, this message translates to:
  /// **'Show animations after rating a card'**
  String get settingsReviewAnimationsBody;

  /// No description provided for @settingsReviewAnimationsLowPowerHint.
  ///
  /// In en, this message translates to:
  /// **'Low Power Mode temporarily disables review animations without changing this setting.'**
  String get settingsReviewAnimationsLowPowerHint;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (system)'**
  String get settingsLanguageAuto;

  /// No description provided for @settingsLanguageFollowsSystem.
  ///
  /// In en, this message translates to:
  /// **'Follows system language'**
  String get settingsLanguageFollowsSystem;

  /// No description provided for @settingsDangerSection.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsDangerSection;

  /// No description provided for @settingsResetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset study progress'**
  String get settingsResetProgress;

  /// No description provided for @settingsResetProgressBody.
  ///
  /// In en, this message translates to:
  /// **'This clears all study progress on this device and on the server. It cannot be undone.'**
  String get settingsResetProgressBody;

  /// No description provided for @settingsDeleteWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Delete current workspace'**
  String get settingsDeleteWorkspace;

  /// No description provided for @settingsDeleteWorkspaceBody.
  ///
  /// In en, this message translates to:
  /// **'Type \"delete workspace\" to confirm. The workspace and all its study progress are deleted.'**
  String get settingsDeleteWorkspaceBody;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all data'**
  String get settingsDeleteAccountBody;

  /// No description provided for @settingsDeleteAccountPhrase.
  ///
  /// In en, this message translates to:
  /// **'Type \"delete my account\" to confirm. This cannot be undone.'**
  String get settingsDeleteAccountPhrase;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountConfirm;

  /// No description provided for @settingsTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {phrase} to confirm'**
  String settingsTypeToConfirm(String phrase);

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get settingsOpenSource;

  /// No description provided for @settingsOpenSourceBody.
  ///
  /// In en, this message translates to:
  /// **'SceneLex is open source and builds on flashcards-open-source-app (MIT). Review reaction animations use Lottie assets from the same project (MIT).'**
  String get settingsOpenSourceBody;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsLegalBody.
  ///
  /// In en, this message translates to:
  /// **'SceneLex is a local-first study tool. Study data syncs to your own server. See the project license for details.'**
  String get settingsLegalBody;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// No description provided for @settingsSupportBody.
  ///
  /// In en, this message translates to:
  /// **'For help and bug reports, open an issue in the project repository. Feedback helps shape the next version.'**
  String get settingsSupportBody;

  /// No description provided for @settingsServerInfo.
  ///
  /// In en, this message translates to:
  /// **'Server info'**
  String get settingsServerInfo;

  /// No description provided for @settingsServerInfoApi.
  ///
  /// In en, this message translates to:
  /// **'API endpoint'**
  String get settingsServerInfoApi;

  /// No description provided for @settingsServerInfoAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsServerInfoAccount;

  /// No description provided for @settingsDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get settingsDeviceInfo;

  /// No description provided for @settingsDevicePlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get settingsDevicePlatform;

  /// No description provided for @settingsShareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get settingsShareApp;

  /// No description provided for @settingsWorkspaceSection.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get settingsWorkspaceSection;

  /// No description provided for @settingsWorkspaceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get settingsWorkspaceCurrent;

  /// No description provided for @settingsWorkspaceSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch or create a workspace'**
  String get settingsWorkspaceSwitch;

  /// No description provided for @settingsWorkspaceRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get settingsWorkspaceRename;

  /// No description provided for @settingsWorkspaceCreate.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get settingsWorkspaceCreate;

  /// No description provided for @settingsWorkspaceSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get settingsWorkspaceSelected;

  /// No description provided for @settingsWorkspaceCreated.
  ///
  /// In en, this message translates to:
  /// **'Workspace created: {name}'**
  String settingsWorkspaceCreated(String name);

  /// No description provided for @settingsWorkspaceLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get settingsWorkspaceLists;

  /// No description provided for @settingsWorkspaceListsBody.
  ///
  /// In en, this message translates to:
  /// **'Create smart lists to filter your reviews'**
  String get settingsWorkspaceListsBody;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @notificationDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Time for today\'s SceneLex review session.'**
  String get notificationDailyBody;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Daily review reminder'**
  String get notificationChannelName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
