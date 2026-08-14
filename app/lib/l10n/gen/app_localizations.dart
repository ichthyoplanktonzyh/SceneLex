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

  /// No description provided for @loginCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit code from your email. If you don\'t see it, check your spam folder.'**
  String get loginCodePrompt;

  /// No description provided for @loginResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get loginResendCode;

  /// No description provided for @loginResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code ({seconds}s)'**
  String loginResendIn(int seconds);

  /// No description provided for @loginChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get loginChangeEmail;

  /// No description provided for @loginErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again later.'**
  String get loginErrorRateLimited;

  /// No description provided for @loginErrorAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'This account has been deleted.'**
  String get loginErrorAccountDeleted;

  /// No description provided for @loginErrorCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code expired. Request a new code.'**
  String get loginErrorCodeExpired;

  /// No description provided for @loginErrorCodeAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This code was already used. Request a new code.'**
  String get loginErrorCodeAlreadyUsed;

  /// No description provided for @loginErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many invalid attempts. Request a new code.'**
  String get loginErrorTooManyAttempts;

  /// No description provided for @loginErrorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code.'**
  String get loginErrorInvalidCode;

  /// No description provided for @loginErrorInternalError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get loginErrorInternalError;

  /// No description provided for @loginErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get loginErrorUnknown;

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

  /// No description provided for @cardMetaDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get cardMetaDue;

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

  /// No description provided for @reviewTagSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get reviewTagSummaryNone;

  /// No description provided for @reviewRepetitionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get reviewRepetitionNew;

  /// No description provided for @reviewRepetitionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reps'**
  String reviewRepetitionCount(int count);

  /// No description provided for @reviewQueueBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} words due'**
  String reviewQueueBadgeTooltip(int count);

  /// No description provided for @reviewEmptyBrowseCards.
  ///
  /// In en, this message translates to:
  /// **'Browse words'**
  String get reviewEmptyBrowseCards;

  /// No description provided for @cardsFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by tags'**
  String get cardsFilterTitle;

  /// No description provided for @cardsFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get cardsFilterClear;

  /// No description provided for @cardsFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get cardsFilterApply;

  /// No description provided for @cardsFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No words match the selected tags'**
  String get cardsFilterEmpty;

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

  /// No description provided for @reviewIntervalLessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'in less than a minute'**
  String get reviewIntervalLessThanMinute;

  /// No description provided for @reviewIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in {count} minute} other{in {count} minutes}}'**
  String reviewIntervalMinutes(int count);

  /// No description provided for @reviewIntervalHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in {count} hour} other{in {count} hours}}'**
  String reviewIntervalHours(int count);

  /// No description provided for @reviewIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in {count} day} other{in {count} days}}'**
  String reviewIntervalDays(int count);

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

  /// No description provided for @settingsAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get settingsAccountStatus;

  /// No description provided for @settingsAccountStatusLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get settingsAccountStatusLinked;

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

  /// No description provided for @settingsLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get settingsLastSync;

  /// No description provided for @settingsLastSyncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsLastSyncNever;

  /// No description provided for @settingsLastSyncValue.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String settingsLastSyncValue(String time);

  /// No description provided for @settingsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsSyncNow;

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

  /// No description provided for @settingsDeletePreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete {learningStates} word states, {reviewEvents} review records, and {lists} lists.'**
  String settingsDeletePreviewBody(
    int learningStates,
    int reviewEvents,
    int lists,
  );

  /// No description provided for @settingsResetProgressPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear {learningStates} word states and delete {reviewEvents} review records.'**
  String settingsResetProgressPreviewBody(int learningStates, int reviewEvents);

  /// No description provided for @settingsPreviewLearningStates.
  ///
  /// In en, this message translates to:
  /// **'Word states'**
  String get settingsPreviewLearningStates;

  /// No description provided for @settingsPreviewReviewEvents.
  ///
  /// In en, this message translates to:
  /// **'Review records'**
  String get settingsPreviewReviewEvents;

  /// No description provided for @settingsPreviewLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get settingsPreviewLists;

  /// No description provided for @settingsDangerLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking what will be affected…'**
  String get settingsDangerLoading;

  /// No description provided for @settingsDangerRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get settingsDangerRetry;

  /// No description provided for @settingsWorkspaceNotSoleMember.
  ///
  /// In en, this message translates to:
  /// **'This workspace has other members, so it cannot be {action}.'**
  String settingsWorkspaceNotSoleMember(String action);

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

  /// No description provided for @settingsWorkspaceTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get settingsWorkspaceTags;

  /// No description provided for @settingsWorkspaceTagsBody.
  ///
  /// In en, this message translates to:
  /// **'Browse read-only tags derived from word metadata'**
  String get settingsWorkspaceTagsBody;

  /// No description provided for @tagsScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tags are read-only labels derived from each word\'s metadata (type and part of speech). Tap a tag to review the words that carry it.'**
  String get tagsScreenSubtitle;

  /// No description provided for @tagsScreenCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String tagsScreenCountLabel(int count);

  /// No description provided for @tagsScreenEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Tags appear once words are added to study.'**
  String get tagsScreenEmpty;

  /// No description provided for @tagsScreenLearnedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String tagsScreenLearnedCount(int count);

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

  /// No description provided for @reviewHardReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick reminder'**
  String get reviewHardReminderTitle;

  /// No description provided for @reviewHardReminderBody.
  ///
  /// In en, this message translates to:
  /// **'If you did not know the answer, choose \"Again\". \"Hard\" is only for answers you knew but it was difficult to recall.'**
  String get reviewHardReminderBody;

  /// No description provided for @reviewHardReminderDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get reviewHardReminderDismiss;

  /// No description provided for @reviewSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Review wasn\'t saved'**
  String get reviewSubmitError;

  /// No description provided for @reviewBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Review streak {days} days. Not reviewed today.'**
  String reviewBadgeTooltip(int days);

  /// No description provided for @reviewBadgeTooltipReviewed.
  ///
  /// In en, this message translates to:
  /// **'Review streak {days} days. Reviewed today.'**
  String reviewBadgeTooltipReviewed(int days);

  /// No description provided for @experienceRuntimeRoleAnchor.
  ///
  /// In en, this message translates to:
  /// **'First look'**
  String get experienceRuntimeRoleAnchor;

  /// No description provided for @experienceRuntimeRoleVariation.
  ///
  /// In en, this message translates to:
  /// **'What stays the same'**
  String get experienceRuntimeRoleVariation;

  /// No description provided for @experienceRuntimeRolePerturbation.
  ///
  /// In en, this message translates to:
  /// **'Change one thing'**
  String get experienceRuntimeRolePerturbation;

  /// No description provided for @experienceRuntimeRoleDiscrimination.
  ///
  /// In en, this message translates to:
  /// **'Choose the right one'**
  String get experienceRuntimeRoleDiscrimination;

  /// No description provided for @experienceRuntimeRoleTransfer.
  ///
  /// In en, this message translates to:
  /// **'Take it further'**
  String get experienceRuntimeRoleTransfer;

  /// No description provided for @experienceRuntimeProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String experienceRuntimeProgress(int current, int total);

  /// No description provided for @experienceRuntimeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get experienceRuntimeContinue;

  /// No description provided for @experienceRuntimeBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get experienceRuntimeBack;

  /// No description provided for @experienceRuntimeEvidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'What you can see'**
  String get experienceRuntimeEvidenceLabel;

  /// No description provided for @experienceRuntimeCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get experienceRuntimeCorrect;

  /// No description provided for @experienceRuntimeIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get experienceRuntimeIncorrect;

  /// No description provided for @experienceRuntimePronunciation.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get experienceRuntimePronunciation;

  /// No description provided for @experienceRuntimeGroundingBackToExperience.
  ///
  /// In en, this message translates to:
  /// **'The moment you just saw'**
  String get experienceRuntimeGroundingBackToExperience;

  /// No description provided for @experienceRuntimeConstructions.
  ///
  /// In en, this message translates to:
  /// **'Structures'**
  String get experienceRuntimeConstructions;

  /// No description provided for @experienceRuntimeCollocations.
  ///
  /// In en, this message translates to:
  /// **'Word partners'**
  String get experienceRuntimeCollocations;

  /// No description provided for @experienceRuntimeCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get experienceRuntimeCompleteTitle;

  /// No description provided for @experienceRuntimeCompleteExperiences.
  ///
  /// In en, this message translates to:
  /// **'experiences completed'**
  String get experienceRuntimeCompleteExperiences;

  /// No description provided for @experienceRuntimeCompleteFirstAttempt.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct on the first try'**
  String experienceRuntimeCompleteFirstAttempt(int correct, int total);

  /// No description provided for @experienceRuntimeReplay.
  ///
  /// In en, this message translates to:
  /// **'Re-experience'**
  String get experienceRuntimeReplay;

  /// No description provided for @experienceRuntimeLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load this experience'**
  String get experienceRuntimeLoadErrorTitle;

  /// No description provided for @experienceRuntimeRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get experienceRuntimeRetry;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Concept map'**
  String get tabMap;

  /// No description provided for @tabContent.
  ///
  /// In en, this message translates to:
  /// **'My content'**
  String get tabContent;

  /// No description provided for @tabStudy.
  ///
  /// In en, this message translates to:
  /// **'My study'**
  String get tabStudy;

  /// No description provided for @homeLearnCta.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get homeLearnCta;

  /// No description provided for @homeReviewCta.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get homeReviewCta;

  /// No description provided for @homeNewSensesLabel.
  ///
  /// In en, this message translates to:
  /// **'new senses to learn'**
  String get homeNewSensesLabel;

  /// No description provided for @homeDueLabel.
  ///
  /// In en, this message translates to:
  /// **'senses due for review'**
  String get homeDueLabel;

  /// No description provided for @homeCheckin.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get homeCheckin;

  /// No description provided for @homeCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get homeCheckedIn;

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// No description provided for @homeCheckinDone.
  ///
  /// In en, this message translates to:
  /// **'Daily check-in recorded'**
  String get homeCheckinDone;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SceneLex · product v1'**
  String get homeSubtitle;

  /// No description provided for @homeSkyAlt.
  ///
  /// In en, this message translates to:
  /// **'SceneLex night sky'**
  String get homeSkyAlt;

  /// No description provided for @homeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load content'**
  String get homeLoadError;

  /// No description provided for @learnExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit this learning session?'**
  String get learnExitTitle;

  /// No description provided for @learnExitBody.
  ///
  /// In en, this message translates to:
  /// **'Progress is saved and you can resume later.'**
  String get learnExitBody;

  /// No description provided for @learnResume.
  ///
  /// In en, this message translates to:
  /// **'Resume learning'**
  String get learnResume;

  /// No description provided for @learnQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get learnQuit;

  /// No description provided for @learnRemovedFavorite.
  ///
  /// In en, this message translates to:
  /// **'Removed from experience favorites'**
  String get learnRemovedFavorite;

  /// No description provided for @learnAddedFavorite.
  ///
  /// In en, this message translates to:
  /// **'Added to experience favorites'**
  String get learnAddedFavorite;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Write something…'**
  String get noteHint;

  /// No description provided for @noteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get noteDelete;

  /// No description provided for @noteSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get noteSave;

  /// No description provided for @phaseSymbolReveal.
  ///
  /// In en, this message translates to:
  /// **'Symbol reveal'**
  String get phaseSymbolReveal;

  /// No description provided for @phaseSymbolRevealSub.
  ///
  /// In en, this message translates to:
  /// **'From experience to L2'**
  String get phaseSymbolRevealSub;

  /// No description provided for @phaseSymbolBinding.
  ///
  /// In en, this message translates to:
  /// **'Bind L2 symbol'**
  String get phaseSymbolBinding;

  /// No description provided for @phaseL2Usage.
  ///
  /// In en, this message translates to:
  /// **'L2 usage'**
  String get phaseL2Usage;

  /// No description provided for @phaseTransfer.
  ///
  /// In en, this message translates to:
  /// **'L1 transfer'**
  String get phaseTransfer;

  /// No description provided for @phaseFormation.
  ///
  /// In en, this message translates to:
  /// **'L1 formation'**
  String get phaseFormation;

  /// No description provided for @learnFinishGroup.
  ///
  /// In en, this message translates to:
  /// **'Finish group'**
  String get learnFinishGroup;

  /// No description provided for @learnNextWord.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get learnNextWord;

  /// No description provided for @learnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get learnContinue;

  /// No description provided for @learnAnswerFirst.
  ///
  /// In en, this message translates to:
  /// **'Answer first'**
  String get learnAnswerFirst;

  /// No description provided for @learnWriteNote.
  ///
  /// In en, this message translates to:
  /// **'Write note'**
  String get learnWriteNote;

  /// No description provided for @learnPreferences.
  ///
  /// In en, this message translates to:
  /// **'Learning preferences'**
  String get learnPreferences;

  /// No description provided for @learnRetreat.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get learnRetreat;

  /// No description provided for @learnFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite this experience'**
  String get learnFavorite;

  /// No description provided for @learnKnown.
  ///
  /// In en, this message translates to:
  /// **'Known'**
  String get learnKnown;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get learnMore;

  /// No description provided for @knownCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No transfer check for this sense'**
  String get knownCheckUnavailable;

  /// No description provided for @knownCheckFailHint.
  ///
  /// In en, this message translates to:
  /// **'Fail: return to the normal anchor flow.'**
  String get knownCheckFailHint;

  /// No description provided for @knownCheckSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip remaining concept formation'**
  String get knownCheckSkip;

  /// No description provided for @knownCheckAnchor.
  ///
  /// In en, this message translates to:
  /// **'Back to anchor flow'**
  String get knownCheckAnchor;

  /// No description provided for @learnEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The catalog is fully studied'**
  String get learnEmptyTitle;

  /// No description provided for @learnEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New content appears here when published.'**
  String get learnEmptyBody;

  /// No description provided for @learnBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get learnBackHome;

  /// No description provided for @reviewQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get reviewQuit;

  /// No description provided for @reviewTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Symbol recall check'**
  String get reviewTransferTitle;

  /// No description provided for @reviewLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get reviewLoadError;

  /// No description provided for @recallDelayedRetrieval.
  ///
  /// In en, this message translates to:
  /// **'Delayed retrieval · new experience'**
  String get recallDelayedRetrieval;

  /// No description provided for @recallRevisit.
  ///
  /// In en, this message translates to:
  /// **'Revisit · a passage you have not seen'**
  String get recallRevisit;

  /// No description provided for @recallPrompt.
  ///
  /// In en, this message translates to:
  /// **'Which word fits this situation?'**
  String get recallPrompt;

  /// No description provided for @recallHint.
  ///
  /// In en, this message translates to:
  /// **'Recall it yourself first, then look at the answer'**
  String get recallHint;

  /// No description provided for @revealShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get revealShowAnswer;

  /// No description provided for @reviewTransferDone.
  ///
  /// In en, this message translates to:
  /// **'Symbol recall check complete'**
  String get reviewTransferDone;

  /// No description provided for @reviewDone.
  ///
  /// In en, this message translates to:
  /// **'This round of review complete'**
  String get reviewDone;

  /// No description provided for @reviewRetrieved.
  ///
  /// In en, this message translates to:
  /// **'Recalled'**
  String get reviewRetrieved;

  /// No description provided for @reviewReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewReviewed;

  /// No description provided for @reviewBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get reviewBackHome;

  /// No description provided for @groupNoneInProgress.
  ///
  /// In en, this message translates to:
  /// **'No group session in progress'**
  String get groupNoneInProgress;

  /// No description provided for @groupBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get groupBackHome;

  /// No description provided for @groupDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Group understanding complete'**
  String get groupDoneTitle;

  /// No description provided for @groupNewExperiences.
  ///
  /// In en, this message translates to:
  /// **'New experiences'**
  String get groupNewExperiences;

  /// No description provided for @groupBoundaryDiscrimination.
  ///
  /// In en, this message translates to:
  /// **'Boundary discrimination'**
  String get groupBoundaryDiscrimination;

  /// No description provided for @groupMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get groupMinutes;

  /// No description provided for @groupRest.
  ///
  /// In en, this message translates to:
  /// **'Back home and rest'**
  String get groupRest;

  /// No description provided for @groupStartRecall.
  ///
  /// In en, this message translates to:
  /// **'Start symbol recall check'**
  String get groupStartRecall;

  /// No description provided for @groupGoReview.
  ///
  /// In en, this message translates to:
  /// **'Go to review'**
  String get groupGoReview;

  /// No description provided for @mapTitle.
  ///
  /// In en, this message translates to:
  /// **'Concept map'**
  String get mapTitle;

  /// No description provided for @mapAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mapAll;

  /// No description provided for @mapLearned.
  ///
  /// In en, this message translates to:
  /// **'Learned'**
  String get mapLearned;

  /// No description provided for @mapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter'**
  String get mapEmpty;

  /// No description provided for @mapDiffDim.
  ///
  /// In en, this message translates to:
  /// **'Different dimension'**
  String get mapDiffDim;

  /// No description provided for @mapOverlap.
  ///
  /// In en, this message translates to:
  /// **'Overlap'**
  String get mapOverlap;

  /// No description provided for @libNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get libNone;

  /// No description provided for @libTitle.
  ///
  /// In en, this message translates to:
  /// **'My content'**
  String get libTitle;

  /// No description provided for @libReplay.
  ///
  /// In en, this message translates to:
  /// **'Experience replay'**
  String get libReplay;

  /// No description provided for @libPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get libPreview;

  /// No description provided for @libTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer check'**
  String get libTransfer;

  /// No description provided for @libTransferBody.
  ///
  /// In en, this message translates to:
  /// **'Learned senses'**
  String get libTransferBody;

  /// No description provided for @libStudyLists.
  ///
  /// In en, this message translates to:
  /// **'Study lists'**
  String get libStudyLists;

  /// No description provided for @libRecentLearned.
  ///
  /// In en, this message translates to:
  /// **'Recently learned'**
  String get libRecentLearned;

  /// No description provided for @libAllLearned.
  ///
  /// In en, this message translates to:
  /// **'All learned'**
  String get libAllLearned;

  /// No description provided for @libConceptMap.
  ///
  /// In en, this message translates to:
  /// **'My concept map'**
  String get libConceptMap;

  /// No description provided for @libFavorites.
  ///
  /// In en, this message translates to:
  /// **'Experience favorites'**
  String get libFavorites;

  /// No description provided for @libNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get libNotes;

  /// No description provided for @libReplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get libReplayLabel;

  /// No description provided for @libReviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get libReviewLabel;

  /// No description provided for @libPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get libPreviewLabel;

  /// No description provided for @libLookFirst.
  ///
  /// In en, this message translates to:
  /// **'Look first'**
  String get libLookFirst;

  /// No description provided for @libToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get libToday;

  /// No description provided for @replayTitle.
  ///
  /// In en, this message translates to:
  /// **'Experience replay'**
  String get replayTitle;

  /// No description provided for @replayEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No learned experiences yet'**
  String get replayEmptyTitle;

  /// No description provided for @replayEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Finish a first-learn group, then replay.'**
  String get replayEmptyBody;

  /// No description provided for @replayNoExperience.
  ///
  /// In en, this message translates to:
  /// **'No experience'**
  String get replayNoExperience;

  /// No description provided for @replayUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get replayUnfavorite;

  /// No description provided for @replayFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get replayFavorite;

  /// No description provided for @replayPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get replayPrev;

  /// No description provided for @replayNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get replayNext;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewTitle;

  /// No description provided for @previewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview'**
  String get previewEmpty;

  /// No description provided for @previewEnterLearn.
  ///
  /// In en, this message translates to:
  /// **'Start first learn (next group)'**
  String get previewEnterLearn;

  /// No description provided for @previewNewSense.
  ///
  /// In en, this message translates to:
  /// **'New sense · watch the anchor experience first'**
  String get previewNewSense;

  /// No description provided for @previewFromExperience.
  ///
  /// In en, this message translates to:
  /// **'From experience into first learn'**
  String get previewFromExperience;

  /// No description provided for @learnedRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently learned'**
  String get learnedRecent;

  /// No description provided for @learnedAll.
  ///
  /// In en, this message translates to:
  /// **'All learned'**
  String get learnedAll;

  /// No description provided for @learnedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No learned senses yet'**
  String get learnedEmpty;

  /// No description provided for @learnedDue.
  ///
  /// In en, this message translates to:
  /// **'Due for review'**
  String get learnedDue;

  /// No description provided for @favTitle.
  ///
  /// In en, this message translates to:
  /// **'Experience favorites'**
  String get favTitle;

  /// No description provided for @favUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get favUnfavorite;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @studyTitle.
  ///
  /// In en, this message translates to:
  /// **'My study'**
  String get studyTitle;

  /// No description provided for @studyPreferences.
  ///
  /// In en, this message translates to:
  /// **'Learning preferences'**
  String get studyPreferences;

  /// No description provided for @studyPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get studyPlan;

  /// No description provided for @studyLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get studyLists;

  /// No description provided for @studyScope.
  ///
  /// In en, this message translates to:
  /// **'Current learning scope'**
  String get studyScope;

  /// No description provided for @studyBySense.
  ///
  /// In en, this message translates to:
  /// **'Organized by sense, not by headword'**
  String get studyBySense;

  /// No description provided for @studyDailyNew.
  ///
  /// In en, this message translates to:
  /// **'New senses per day'**
  String get studyDailyNew;

  /// No description provided for @studyStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get studyStats;

  /// No description provided for @studyTodayLearnReview.
  ///
  /// In en, this message translates to:
  /// **'Learned & reviewed today'**
  String get studyTodayLearnReview;

  /// No description provided for @studySenses.
  ///
  /// In en, this message translates to:
  /// **'senses'**
  String get studySenses;

  /// No description provided for @studyCumulativeLearned.
  ///
  /// In en, this message translates to:
  /// **'Cumulative learned'**
  String get studyCumulativeLearned;

  /// No description provided for @studyTodayMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes today'**
  String get studyTodayMinutes;

  /// No description provided for @studyMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get studyMinutes;

  /// No description provided for @studyCumulativeMinutes.
  ///
  /// In en, this message translates to:
  /// **'Cumulative minutes'**
  String get studyCumulativeMinutes;

  /// No description provided for @studyCheckinCalendar.
  ///
  /// In en, this message translates to:
  /// **'Check-in calendar'**
  String get studyCheckinCalendar;

  /// No description provided for @studyTodayCol.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get studyTodayCol;

  /// No description provided for @profileLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get profileLearning;

  /// No description provided for @profileReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get profileReviewing;

  /// No description provided for @profileRelearning.
  ///
  /// In en, this message translates to:
  /// **'Re-learning'**
  String get profileRelearning;

  /// No description provided for @profileNewCards.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get profileNewCards;

  /// No description provided for @profileBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get profileBack;

  /// No description provided for @profileLearner.
  ///
  /// In en, this message translates to:
  /// **'SceneLex learner'**
  String get profileLearner;

  /// No description provided for @profileNoMember.
  ///
  /// In en, this message translates to:
  /// **'No membership'**
  String get profileNoMember;

  /// No description provided for @profileLearnedSenses.
  ///
  /// In en, this message translates to:
  /// **'Learned senses'**
  String get profileLearnedSenses;

  /// No description provided for @profileExperiencesLoading.
  ///
  /// In en, this message translates to:
  /// **'Counting experiences…'**
  String get profileExperiencesLoading;

  /// No description provided for @profileMastery.
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get profileMastery;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profilePreferences.
  ///
  /// In en, this message translates to:
  /// **'Learning preferences'**
  String get profilePreferences;

  /// No description provided for @profileMoreSettings.
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get profileMoreSettings;

  /// No description provided for @profileNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No study records yet'**
  String get profileNoRecords;

  /// No description provided for @prefSectionUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding flow'**
  String get prefSectionUnderstanding;

  /// No description provided for @prefTransferTiming.
  ///
  /// In en, this message translates to:
  /// **'Symbol recall timing'**
  String get prefTransferTiming;

  /// No description provided for @prefBoundaryPerturbation.
  ///
  /// In en, this message translates to:
  /// **'Boundary perturbation'**
  String get prefBoundaryPerturbation;

  /// No description provided for @prefSymbolRecall.
  ///
  /// In en, this message translates to:
  /// **'Symbol recall'**
  String get prefSymbolRecall;

  /// No description provided for @prefScaffold.
  ///
  /// In en, this message translates to:
  /// **'L1 scaffolding'**
  String get prefScaffold;

  /// No description provided for @prefScaffoldLevel.
  ///
  /// In en, this message translates to:
  /// **'Narrative language level'**
  String get prefScaffoldLevel;

  /// No description provided for @prefScaffoldCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current level'**
  String get prefScaffoldCurrent;

  /// No description provided for @prefAutoScaffoldRemoval.
  ///
  /// In en, this message translates to:
  /// **'Auto removal'**
  String get prefAutoScaffoldRemoval;

  /// No description provided for @prefZhLabelBeforeReveal.
  ///
  /// In en, this message translates to:
  /// **'Chinese label before reveal'**
  String get prefZhLabelBeforeReveal;

  /// No description provided for @prefSectionRhythm.
  ///
  /// In en, this message translates to:
  /// **'Rhythm'**
  String get prefSectionRhythm;

  /// No description provided for @prefNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New learn group'**
  String get prefNewGroup;

  /// No description provided for @prefNewGroupHint.
  ///
  /// In en, this message translates to:
  /// **'About 90 seconds per sense'**
  String get prefNewGroupHint;

  /// No description provided for @prefReviewGroup.
  ///
  /// In en, this message translates to:
  /// **'Review group'**
  String get prefReviewGroup;

  /// No description provided for @prefSectionVoice.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation & reminders'**
  String get prefSectionVoice;

  /// No description provided for @prefAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get prefAccent;

  /// No description provided for @prefAccentUs.
  ///
  /// In en, this message translates to:
  /// **'American'**
  String get prefAccentUs;

  /// No description provided for @prefAccentUk.
  ///
  /// In en, this message translates to:
  /// **'British'**
  String get prefAccentUk;

  /// No description provided for @prefAutoPronounce.
  ///
  /// In en, this message translates to:
  /// **'Auto pronounce'**
  String get prefAutoPronounce;

  /// No description provided for @prefReminder.
  ///
  /// In en, this message translates to:
  /// **'Study reminder'**
  String get prefReminder;

  /// No description provided for @prefReminderHint.
  ///
  /// In en, this message translates to:
  /// **'Maps to notification settings'**
  String get prefReminderHint;

  /// No description provided for @prefTransferEndOfDay.
  ///
  /// In en, this message translates to:
  /// **'End of day'**
  String get prefTransferEndOfDay;

  /// No description provided for @prefTransferEndOfFirstLearning.
  ///
  /// In en, this message translates to:
  /// **'End of first learn'**
  String get prefTransferEndOfFirstLearning;

  /// No description provided for @prefTransferFirstReview.
  ///
  /// In en, this message translates to:
  /// **'First review'**
  String get prefTransferFirstReview;

  /// No description provided for @prefScaffoldZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get prefScaffoldZh;

  /// No description provided for @prefScaffoldMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get prefScaffoldMixed;

  /// No description provided for @prefScaffoldEn.
  ///
  /// In en, this message translates to:
  /// **'Pure English'**
  String get prefScaffoldEn;

  /// No description provided for @prefReminderReveal.
  ///
  /// In en, this message translates to:
  /// **'At symbol reveal'**
  String get prefReminderReveal;

  /// No description provided for @prefReminderRevealExample.
  ///
  /// In en, this message translates to:
  /// **'Reveal + example'**
  String get prefReminderRevealExample;

  /// No description provided for @prefReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get prefReminderOff;

  /// No description provided for @prefReminderSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart reminder'**
  String get prefReminderSmart;

  /// No description provided for @prefReminderFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed time'**
  String get prefReminderFixed;

  /// No description provided for @prefTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning preferences'**
  String get prefTitle;

  /// No description provided for @homeProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get homeProfile;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Meaning is experience; micro-worlds are experience.'**
  String get brandTagline;

  /// No description provided for @knownCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Known · transfer check · will not mark as learned'**
  String get knownCheckTitle;

  /// No description provided for @knownCheckPassHint.
  ///
  /// In en, this message translates to:
  /// **'Pass: recognize the concept → skip the rest of concept formation.'**
  String get knownCheckPassHint;

  /// No description provided for @recallNewExperience.
  ///
  /// In en, this message translates to:
  /// **'New experience · you have not seen this one'**
  String get recallNewExperience;

  /// No description provided for @gradeNextUsesNewExperience.
  ///
  /// In en, this message translates to:
  /// **'FSRS-6 · next review uses an unseen experience'**
  String get gradeNextUsesNewExperience;

  /// No description provided for @reviewTransferDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Completed the delayed experience-to-symbol recall with brand-new experiences'**
  String get reviewTransferDoneBody;

  /// No description provided for @transferIntro.
  ///
  /// In en, this message translates to:
  /// **'Transfer was completed before each reveal. What follows is delayed symbol recall:'**
  String get transferIntro;

  /// No description provided for @transferIntro2.
  ///
  /// In en, this message translates to:
  /// **'Watch a new experience — can you recall the L2 symbol you just bound?'**
  String get transferIntro2;

  /// No description provided for @transferDeferred.
  ///
  /// In en, this message translates to:
  /// **'Transfer testing is deferred to the first review (current preference: first review).'**
  String get transferDeferred;

  /// No description provided for @transferAtEnd.
  ///
  /// In en, this message translates to:
  /// **'Transfer testing already completed at the end of each first learn (current preference: end of first learn).'**
  String get transferAtEnd;

  /// No description provided for @mapBoundariesNotCollected.
  ///
  /// In en, this message translates to:
  /// **'Boundary relations (relations.boundaries) not yet collected — content debt, pending the compiler output.'**
  String get mapBoundariesNotCollected;

  /// No description provided for @replayOnlyScene.
  ///
  /// In en, this message translates to:
  /// **'Only the scene replays — recalling the word is for review'**
  String get replayOnlyScene;

  /// No description provided for @favEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Star an experience while learning or replaying.'**
  String get favEmpty;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Use the More menu in a first-learn session to note the current sense.'**
  String get notesEmpty;

  /// No description provided for @prefTransferTimingHint.
  ///
  /// In en, this message translates to:
  /// **'Transfer is fixed before the reveal; this controls when experience-to-symbol is tested'**
  String get prefTransferTimingHint;

  /// No description provided for @prefBoundaryPerturbationHint.
  ///
  /// In en, this message translates to:
  /// **'Contrast / counter-example scenes crush wrong generalizations'**
  String get prefBoundaryPerturbationHint;

  /// No description provided for @prefSymbolRecallHint.
  ///
  /// In en, this message translates to:
  /// **'One scene-to-word retrieval after the reveal'**
  String get prefSymbolRecallHint;

  /// No description provided for @prefAutoScaffoldRemovalHint.
  ///
  /// In en, this message translates to:
  /// **'Steps down to pure English as reviews accumulate'**
  String get prefAutoScaffoldRemovalHint;

  /// No description provided for @prefZhLabelBeforeRevealHint.
  ///
  /// In en, this message translates to:
  /// **'On = back to give-the-translation-first; off by default'**
  String get prefZhLabelBeforeRevealHint;

  /// No description provided for @noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note · {senseId}'**
  String noteTitle(Object senseId);

  /// No description provided for @learnLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {errorMessage}'**
  String learnLoadError(Object errorMessage);

  /// No description provided for @learnWordProgress.
  ///
  /// In en, this message translates to:
  /// **'Word {index} / {count}'**
  String learnWordProgress(Object index, Object count);

  /// No description provided for @reviewDoneBody.
  ///
  /// In en, this message translates to:
  /// **'{gradedCount} review events written locally'**
  String reviewDoneBody(Object gradedCount);

  /// No description provided for @groupDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Experiences for {senseCount} senses have been built'**
  String groupDoneBody(Object senseCount);

  /// No description provided for @mapLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String mapLoadError(Object error);

  /// No description provided for @mapBoundaryCriterion.
  ///
  /// In en, this message translates to:
  /// **'Criterion: {diagnostic}'**
  String mapBoundaryCriterion(Object diagnostic);

  /// No description provided for @libRecent7d.
  ///
  /// In en, this message translates to:
  /// **'Past 7 days · {recentCount} senses'**
  String libRecent7d(Object recentCount);

  /// No description provided for @libReplayBody.
  ///
  /// In en, this message translates to:
  /// **'{learnedCount} sense experiences'**
  String libReplayBody(Object learnedCount);

  /// No description provided for @libPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'{clamped} scenes'**
  String libPreviewBody(Object clamped);

  /// No description provided for @libStudyListsBody.
  ///
  /// In en, this message translates to:
  /// **'{learnedCount} senses'**
  String libStudyListsBody(Object learnedCount);

  /// No description provided for @libAllLearnedBody.
  ///
  /// In en, this message translates to:
  /// **'{learnedCount} senses'**
  String libAllLearnedBody(Object learnedCount);

  /// No description provided for @libConceptMapBody.
  ///
  /// In en, this message translates to:
  /// **'{catalogSize} senses'**
  String libConceptMapBody(Object catalogSize);

  /// No description provided for @libFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'{favoritesCount} items'**
  String libFavoritesBody(Object favoritesCount);

  /// No description provided for @libNotesBody.
  ///
  /// In en, this message translates to:
  /// **'{notesCount} notes'**
  String libNotesBody(Object notesCount);

  /// No description provided for @replayLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String replayLoadError(Object error);

  /// No description provided for @replayCounter.
  ///
  /// In en, this message translates to:
  /// **'Experience {index} / {total}'**
  String replayCounter(Object index, Object total);

  /// No description provided for @previewLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String previewLoadError(Object error);

  /// No description provided for @learnedLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String learnedLoadError(Object error);

  /// No description provided for @learnedReviewedN.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {reps} times'**
  String learnedReviewedN(Object reps);

  /// No description provided for @favLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String favLoadError(Object error);

  /// No description provided for @notesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String notesLoadError(Object error);

  /// No description provided for @studyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String studyLoadError(Object error);

  /// No description provided for @studyLearned.
  ///
  /// In en, this message translates to:
  /// **'Learned {learnedCount}'**
  String studyLearned(Object learnedCount);

  /// No description provided for @studyCatalogSize.
  ///
  /// In en, this message translates to:
  /// **'Total senses {catalogSize}'**
  String studyCatalogSize(Object catalogSize);

  /// No description provided for @studyDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'{dailyGoal} / day'**
  String studyDailyGoal(Object dailyGoal);

  /// No description provided for @studyStreak.
  ///
  /// In en, this message translates to:
  /// **'{streakDays}-day streak'**
  String studyStreak(Object streakDays);

  /// No description provided for @profileExperienceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} experience scenes'**
  String profileExperienceCount(Object count);

  /// No description provided for @profileFsrsSummary.
  ///
  /// In en, this message translates to:
  /// **'FSRS state distribution · {total} senses'**
  String profileFsrsSummary(Object total);

  /// No description provided for @prefNewGroupSize.
  ///
  /// In en, this message translates to:
  /// **'{groupSize} senses / group'**
  String prefNewGroupSize(Object groupSize);

  /// No description provided for @prefReviewGroupSize.
  ///
  /// In en, this message translates to:
  /// **'{groupSize} senses / group'**
  String prefReviewGroupSize(Object groupSize);
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
