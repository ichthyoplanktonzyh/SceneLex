// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SceneLex';

  @override
  String get appTagline => '经验即词义,微世界即体验';

  @override
  String get tabReview => '今日学习';

  @override
  String get tabProgress => '进度';

  @override
  String get tabCards => '词表';

  @override
  String get tabSettings => '设置';

  @override
  String loadingFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginOtpLabel => '8 位验证码';

  @override
  String get loginSendCode => '发送验证码';

  @override
  String get loginSignIn => '登录';

  @override
  String get loginCodePrompt => '请输入邮件中的 8 位验证码。没看到?检查一下垃圾邮件文件夹。';

  @override
  String get loginResendCode => '重新发送验证码';

  @override
  String loginResendIn(int seconds) {
    return '重新发送($seconds 秒)';
  }

  @override
  String get loginChangeEmail => '换个邮箱';

  @override
  String get loginErrorRateLimited => '请求过于频繁,请稍后再试。';

  @override
  String get loginErrorAccountDeleted => '该账户已被删除。';

  @override
  String get loginErrorCodeExpired => '验证码已过期,请重新获取。';

  @override
  String get loginErrorCodeAlreadyUsed => '验证码已被使用,请重新获取。';

  @override
  String get loginErrorTooManyAttempts => '尝试次数过多,请重新获取验证码。';

  @override
  String get loginErrorInvalidCode => '验证码不正确。';

  @override
  String get loginErrorInternalError => '出了点问题,请重试。';

  @override
  String get loginErrorUnknown => '登录失败,请重试。';

  @override
  String get cardsTitle => '词表';

  @override
  String get cardsSearchHint => '搜索词义';

  @override
  String get cardsEmptyLibrary => '词义库为空,先运行 import_content.py';

  @override
  String get cardsEmptySearch => '没有匹配的词义';

  @override
  String get cardsStudy => '学习';

  @override
  String get cardsAdded => '已添加';

  @override
  String get cardStateNotAdded => '未添加';

  @override
  String get cardStateNew => '新词';

  @override
  String get cardStateLearning => '学习中';

  @override
  String get cardStateRelearning => '复习中';

  @override
  String get cardStateReview => '复习';

  @override
  String cardStateNext(String date) {
    return '下一步 $date';
  }

  @override
  String get cardMetaDue => '到期';

  @override
  String cardStatDue(int count) {
    return '$count 张到期';
  }

  @override
  String cardStatReps(int count) {
    return '复习 $count 次';
  }

  @override
  String cardStatLapses(int count) {
    return '失误 $count 次';
  }

  @override
  String get reviewTitle => '今日学习';

  @override
  String get reviewEmptyNoSenses => '还没有学习中的词义';

  @override
  String get reviewEmptyNoDue => '今天没有到期内容';

  @override
  String get reviewEmptyGoAdd => '去「词表」添加要学的词义';

  @override
  String get reviewEmptyAllDone => '全部完成,明天再来';

  @override
  String get reviewEmptySwitchToAll => '切换到全部词义';

  @override
  String get reviewFilterTitle => '筛选';

  @override
  String get reviewFilterLists => '词单';

  @override
  String get reviewFilterTags => '标签';

  @override
  String get reviewFilterManage => '管理词单';

  @override
  String get reviewFilterDone => '完成';

  @override
  String get listsTitle => '词单';

  @override
  String get listsAllCards => '全部词义';

  @override
  String listsAllCardsBody(int count) {
    return '$count 个词义';
  }

  @override
  String get listsCreate => '新建词单';

  @override
  String get listsEdit => '编辑词单';

  @override
  String get listsDelete => '删除';

  @override
  String get listsDeleteTitle => '删除这个词单?';

  @override
  String get listsDeleteBody => '词单及其规则将从本设备和下次同步中移除,不会删除任何学习进度。';

  @override
  String get listsEmpty => '还没有词单。创建一个词单来筛选要复习的词义。';

  @override
  String get listsNameLabel => '名称';

  @override
  String get listsTagsLabel => '标签(至少选一个)';

  @override
  String get listsSaveHint => '词单的规则:词义只要带有任一选中标签即匹配。';

  @override
  String get listsNoTags => '暂无可用标签。';

  @override
  String listsMatchedCount(int count) {
    return '$count 个匹配词义';
  }

  @override
  String get listsDetailRules => '规则';

  @override
  String get listsDetailStats => '统计';

  @override
  String get listsDetailMatched => '匹配词义';

  @override
  String get listsMatchedEmpty => '还没有学习中的词义匹配这个词单。';

  @override
  String get listsStatMatched => '已匹配';

  @override
  String get listsStatDue => '当前到期';

  @override
  String get listsReviewThisDeck => '复习这个词单';

  @override
  String get cardRemove => '移除';

  @override
  String get cardRemoveTitle => '移出学习?';

  @override
  String get cardRemoveBody => '该词将从本地列表和下次同步中移除。之后可以随时重新添加。';

  @override
  String get stageAnchor => '经验原型';

  @override
  String get stageVariation => '变式';

  @override
  String get stagePerturbation => '边界扰动';

  @override
  String get stageDiscrimination => '区分';

  @override
  String get stageSymbolBinding => '词义揭示';

  @override
  String get stageL2Grounding => '语言用法';

  @override
  String get stageTransfer => '迁移判断';

  @override
  String get hintAnchor => '先经历:这是这个词生长的典型经验。';

  @override
  String get hintVariation => '情境变了,经验结构不变——找到不变的东西。';

  @override
  String get hintPerturbation => '只改变一个变量:它还是同一个词吗?';

  @override
  String get hintDiscrimination => '两种心理状态,是同一种吗?';

  @override
  String get hintSymbolBinding => '你反复识别的这种经验,英语里这样说。';

  @override
  String get hintL2Grounding => '这个词在真实语言里怎么用。';

  @override
  String get hintTransfer => '一个全新的经验:这个词成立吗?';

  @override
  String playerLoadFailed(String error) {
    return 'Program 加载失败: $error';
  }

  @override
  String get speechListen => '朗读';

  @override
  String get speechStop => '停止';

  @override
  String get speechUnavailable => '无法朗读';

  @override
  String get playerNoUnits => '这个词义还没有可播放的经验。';

  @override
  String get playerNoSynopsis => '(无叙事内容)';

  @override
  String get reviewTagSummaryNone => '无标签';

  @override
  String get reviewRepetitionNew => '新卡';

  @override
  String reviewRepetitionCount(int count) {
    return '$count 次';
  }

  @override
  String reviewQueueBadgeTooltip(int count) {
    return '$count 个词待复习';
  }

  @override
  String get reviewEmptyBrowseCards => '浏览词库';

  @override
  String get cardsFilterTitle => '按标签筛选';

  @override
  String get cardsFilterClear => '清除';

  @override
  String get cardsFilterApply => '应用';

  @override
  String get cardsFilterEmpty => '没有词匹配所选标签';

  @override
  String get playerTaskJudge => '判断';

  @override
  String get playerTaskPlaceholder => '(任务)';

  @override
  String get playerFinish => '完成经验之旅';

  @override
  String get playerContinue => '继续';

  @override
  String get playerRatingQuestion => '刚才的经历,你记得多牢?';

  @override
  String get ratingAgain => '忘记';

  @override
  String get ratingHard => '困难';

  @override
  String get ratingGood => '良好';

  @override
  String get ratingEasy => '轻松';

  @override
  String get reviewIntervalLessThanMinute => '不到 1 分钟后';

  @override
  String reviewIntervalMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟后',
    );
    return '$_temp0';
  }

  @override
  String reviewIntervalHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时后',
    );
    return '$_temp0';
  }

  @override
  String reviewIntervalDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
    );
    return '$_temp0';
  }

  @override
  String get progressTitle => '进度';

  @override
  String get progressNoData => '还没有复习数据';

  @override
  String get streakCardTitle => '连续学习';

  @override
  String streakDaysLabel(int count) {
    return '$count 天';
  }

  @override
  String streakLongest(int count) {
    return '最长:$count 天';
  }

  @override
  String get streakFreezeLabel => '冻结额度';

  @override
  String streakFreezeCount(int credits, int capacity) {
    return '$credits/$capacity';
  }

  @override
  String streakFreezeInfo(int needed) {
    return '每复习 $needed 天获得 1 个冻结额度;冻结可保住一天未复习的连续记录。';
  }

  @override
  String get streakFreezeFull => '冻结额度已满';

  @override
  String get reviewsCardTitle => '复习';

  @override
  String reviewsDayTotal(int count) {
    return '$count 次复习';
  }

  @override
  String get reviewScheduleTitle => '复习日程';

  @override
  String get bucketNew => '新词';

  @override
  String get bucketToday => '今天';

  @override
  String get bucket1to7 => '1-7 天';

  @override
  String get bucket8to30 => '8-30 天';

  @override
  String get bucket31to90 => '31-90 天';

  @override
  String get bucket91to360 => '91-360 天';

  @override
  String get bucket1to2y => '1-2 年';

  @override
  String get bucketLater => '更久';

  @override
  String get scheduleEmpty => '日程里还没有卡片';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAccountSection => '账号';

  @override
  String get settingsAccountEmail => '邮箱';

  @override
  String get settingsAccountStatus => '账号状态';

  @override
  String get settingsAccountStatusLinked => '已关联';

  @override
  String get settingsSyncStatus => '同步状态';

  @override
  String get syncStatusSynced => '已同步';

  @override
  String get syncStatusSyncing => '同步中…';

  @override
  String get syncStatusOffline => '离线';

  @override
  String get settingsLastSync => '上次同步';

  @override
  String get settingsLastSyncNever => '从未';

  @override
  String settingsLastSyncValue(String time) {
    return '上次同步 $time';
  }

  @override
  String get settingsSyncNow => '立即同步';

  @override
  String get settingsSignOut => '退出登录';

  @override
  String get signOutTitle => '退出登录?';

  @override
  String get signOutBody => '本设备上的本地数据将被清除。';

  @override
  String get signOutConfirm => '退出';

  @override
  String get signOutCancel => '取消';

  @override
  String get settingsSchedulingSection => '调度设置';

  @override
  String get settingsDesiredRetention => '期望保留率';

  @override
  String get settingsLearningSteps => '学习步骤(分钟)';

  @override
  String get settingsRelearningSteps => '再学习步骤(分钟)';

  @override
  String get settingsMaxInterval => '最大间隔(天)';

  @override
  String get settingsEnableFuzz => '启用 fuzz';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get settingsSaveHint => '仅影响未来的复习';

  @override
  String get settingsResetDefaults => '重置默认';

  @override
  String get settingsInvalidValue => '请检查输入的值';

  @override
  String get settingsNotificationsSection => '通知';

  @override
  String get settingsEnableNotifications => '启用每日提醒';

  @override
  String get settingsNotificationTime => '提醒时间';

  @override
  String get settingsPickTime => '选择时间';

  @override
  String get settingsNotificationsUnsupported => '当前平台不支持通知';

  @override
  String get settingsNotificationsDenied => '通知权限被拒绝';

  @override
  String get settingsNotificationsMode => '模式';

  @override
  String get settingsNotificationsModeDaily => '每天一次';

  @override
  String get settingsNotificationsModeInactivity => '不活动时';

  @override
  String get settingsNotificationsInactivityBody =>
      '在该时间窗内,超过设定间隔未学习后收到第一次提醒,之后按间隔重复提醒。';

  @override
  String get settingsNotificationsFrom => '从';

  @override
  String get settingsNotificationsTo => '至';

  @override
  String get settingsNotificationsRepeatEvery => '重复间隔';

  @override
  String get settingsNotificationsOneHour => '1 小时';

  @override
  String settingsNotificationsHours(int count) {
    return '$count 小时';
  }

  @override
  String settingsNotificationsMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get settingsNotificationsBadge => '显示应用角标';

  @override
  String get settingsNotificationsBadgeBody => '提醒发出时,如果今天还没学习,应用图标显示红色 1。';

  @override
  String get settingsNotificationsStrict => '启用连续学习提醒';

  @override
  String get settingsNotificationsStrictBody =>
      '如果今天还没学习,SceneLex 会在午夜前 4、3、2 小时提醒你,帮你保住连续记录。';

  @override
  String get settingsNotificationsFooter => '学习提醒仅保存在本设备。';

  @override
  String get settingsNotificationsOff => '已关闭';

  @override
  String get settingsReviewSection => '复习';

  @override
  String get settingsReviewAnimations => '复习动画';

  @override
  String get settingsReviewAnimationsBody => '评分后显示动画';

  @override
  String get settingsReviewAnimationsLowPowerHint => '低电量模式会临时禁用复习动画,不改变此设置。';

  @override
  String get settingsLanguageSection => '语言';

  @override
  String get settingsLanguageAuto => '自动(跟随系统)';

  @override
  String get settingsLanguageFollowsSystem => '跟随系统语言';

  @override
  String get settingsDangerSection => '危险操作';

  @override
  String get settingsResetProgress => '重置学习进度';

  @override
  String get settingsResetProgressBody => '将清除本设备与服务端的所有学习进度,不可恢复。';

  @override
  String get settingsDeleteWorkspace => '删除当前工作区';

  @override
  String get settingsDeleteWorkspaceBody =>
      '输入 \"delete workspace\" 确认。工作区及其全部学习进度将被删除。';

  @override
  String settingsDeletePreviewBody(
    int learningStates,
    int reviewEvents,
    int lists,
  ) {
    return '将删除 $learningStates 个学习状态、$reviewEvents 条复习记录和 $lists 个词表。';
  }

  @override
  String settingsResetProgressPreviewBody(
    int learningStates,
    int reviewEvents,
  ) {
    return '将清零 $learningStates 个学习状态并删除 $reviewEvents 条复习记录。';
  }

  @override
  String get settingsPreviewLearningStates => '学习状态';

  @override
  String get settingsPreviewReviewEvents => '复习记录';

  @override
  String get settingsPreviewLists => '词表';

  @override
  String get settingsDangerLoading => '正在统计受影响的数据…';

  @override
  String get settingsDangerRetry => '重试';

  @override
  String settingsWorkspaceNotSoleMember(String action) {
    return '此工作区还有其他成员,无法$action。';
  }

  @override
  String get settingsDeleteAccount => '删除账号';

  @override
  String get settingsDeleteAccountBody => '永久删除账号与全部数据';

  @override
  String get settingsDeleteAccountPhrase =>
      '输入 \"delete my account\" 确认。此操作不可恢复。';

  @override
  String get settingsDeleteAccountConfirm => '删除账号';

  @override
  String settingsTypeToConfirm(String phrase) {
    return '输入 $phrase 以确认';
  }

  @override
  String get settingsAboutSection => '关于';

  @override
  String get settingsOpenSource => '开源';

  @override
  String get settingsOpenSourceBody =>
      'SceneLex 是开源项目,行为基线参考 flashcards-open-source-app(MIT);复习反应动画使用同项目的 Lottie 资产(MIT)。';

  @override
  String get settingsLegal => '法律信息';

  @override
  String get settingsLegalBody => 'SceneLex 是本地优先的学习工具,学习数据同步到自己的服务器。详见项目许可证。';

  @override
  String get settingsSupport => '支持';

  @override
  String get settingsSupportBody => '如有问题或建议,请在项目仓库提交 issue,帮助我们改进下一个版本。';

  @override
  String get settingsServerInfo => '服务器信息';

  @override
  String get settingsServerInfoApi => 'API 地址';

  @override
  String get settingsServerInfoAccount => '账号';

  @override
  String get settingsDeviceInfo => '设备信息';

  @override
  String get settingsDevicePlatform => '平台';

  @override
  String get settingsShareApp => '分享应用';

  @override
  String get settingsWorkspaceSection => '工作区';

  @override
  String get settingsWorkspaceCurrent => '工作区';

  @override
  String get settingsWorkspaceSwitch => '切换或创建工作区';

  @override
  String get settingsWorkspaceRename => '重命名';

  @override
  String get settingsWorkspaceCreate => '新建工作区';

  @override
  String get settingsWorkspaceSelected => '当前使用';

  @override
  String settingsWorkspaceCreated(String name) {
    return '已创建工作区:$name';
  }

  @override
  String get settingsWorkspaceLists => '词单';

  @override
  String get settingsWorkspaceListsBody => '创建智能词单,筛选复习内容';

  @override
  String get settingsWorkspaceTags => '标签';

  @override
  String get settingsWorkspaceTagsBody => '浏览从词义元数据派生的只读标签';

  @override
  String get tagsScreenSubtitle => '标签是由每个词的元数据(类型与词性)派生的只读标签。点按标签即可复习带有该标签的词。';

  @override
  String tagsScreenCountLabel(int count) {
    return '$count 个标签';
  }

  @override
  String get tagsScreenEmpty => '暂无标签。词加入学习后会出现标签。';

  @override
  String tagsScreenLearnedCount(int count) {
    return '$count 个词';
  }

  @override
  String get settingsReset => '重置';

  @override
  String get settingsDelete => '删除';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsComingSoon => '即将上线';

  @override
  String get notificationDailyBody => '该进行今天的 SceneLex 复习了。';

  @override
  String get notificationChannelName => '每日复习提醒';

  @override
  String get reviewHardReminderTitle => '快速提醒';

  @override
  String get reviewHardReminderBody =>
      '如果您不知道答案,请选择「重来」。「困难」只适用于您知道答案但回忆起来较困难的情况。';

  @override
  String get reviewHardReminderDismiss => '知道了';

  @override
  String get reviewSubmitError => '复习记录未能保存';

  @override
  String reviewBadgeTooltip(int days) {
    return '连续复习 $days 天。今天还没复习。';
  }

  @override
  String reviewBadgeTooltipReviewed(int days) {
    return '连续复习 $days 天。今天已复习。';
  }

  @override
  String get experienceRuntimeRoleAnchor => '初次遇见';

  @override
  String get experienceRuntimeRoleVariation => '什么没变';

  @override
  String get experienceRuntimeRolePerturbation => '只改一点';

  @override
  String get experienceRuntimeRoleDiscrimination => '分辨选择';

  @override
  String get experienceRuntimeRoleTransfer => '进一步迁移';

  @override
  String experienceRuntimeProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get experienceRuntimeContinue => '继续';

  @override
  String get experienceRuntimeBack => '返回';

  @override
  String get experienceRuntimeEvidenceLabel => '你能看到的证据';

  @override
  String get experienceRuntimeCorrect => '正确';

  @override
  String get experienceRuntimeIncorrect => '不太对';

  @override
  String get experienceRuntimePronunciation => '听发音';

  @override
  String get experienceRuntimeGroundingBackToExperience => '你刚才看到的场景';

  @override
  String get experienceRuntimeConstructions => '句式';

  @override
  String get experienceRuntimeCollocations => '搭配';

  @override
  String get experienceRuntimeCompleteTitle => '本次学习完成';

  @override
  String get experienceRuntimeCompleteExperiences => '个经验已完成';

  @override
  String experienceRuntimeCompleteFirstAttempt(int correct, int total) {
    return '首次作答正确 $correct/$total';
  }

  @override
  String get experienceRuntimeReplay => '重新体验';

  @override
  String get experienceRuntimeLoadErrorTitle => '无法加载这个经验';

  @override
  String get experienceRuntimeRetry => '重试';

  @override
  String get tabHome => '首页';

  @override
  String get tabMap => '概念地图';

  @override
  String get tabContent => '我的内容';

  @override
  String get tabStudy => '我的学习';

  @override
  String get homeLearnCta => '开始学习';

  @override
  String get homeReviewCta => '复习';

  @override
  String get homeNewSensesLabel => '个新义项待学';

  @override
  String get homeDueLabel => '个义项待复习';

  @override
  String get homeCheckin => '签到';

  @override
  String get homeCheckedIn => '已签到';

  @override
  String get homeToday => '今日';

  @override
  String get homeCheckinDone => '今日签到已记录';

  @override
  String get homeSubtitle => 'SceneLex · 产品 v1';

  @override
  String get homeSkyAlt => 'SceneLex 夜空';

  @override
  String get homeLoadError => '内容加载失败';

  @override
  String get learnExitTitle => '退出本次学习？';

  @override
  String get learnExitBody => '进度会保存，下次可以继续。';

  @override
  String get learnResume => '继续学习';

  @override
  String get learnQuit => '退出';

  @override
  String get learnRemovedFavorite => '已移出场景收藏';

  @override
  String get learnAddedFavorite => '已加入场景收藏';

  @override
  String get noteHint => '写点什么…';

  @override
  String get noteDelete => '删除';

  @override
  String get noteSave => '保存';

  @override
  String get phaseSymbolReveal => '符号揭示';

  @override
  String get phaseSymbolRevealSub => '从经验落到 L2';

  @override
  String get phaseSymbolBinding => '绑定 L2 符号';

  @override
  String get phaseL2Usage => 'L2 使用';

  @override
  String get phaseTransfer => 'L1 概念迁移';

  @override
  String get phaseFormation => 'L1 概念形成';

  @override
  String get learnFinishGroup => '完成本组';

  @override
  String get learnNextWord => '下一词';

  @override
  String get learnContinue => '继续';

  @override
  String get learnAnswerFirst => '先作答';

  @override
  String get learnWriteNote => '写笔记';

  @override
  String get learnPreferences => '学习偏好';

  @override
  String get learnRetreat => '撤回';

  @override
  String get learnFavorite => '收藏当前经验';

  @override
  String get learnKnown => '熟';

  @override
  String get learnMore => '更多';

  @override
  String get knownCheckUnavailable => '当前义项没有迁移检查';

  @override
  String get knownCheckFailHint => '未通过：回到正常锚点流程。';

  @override
  String get knownCheckSkip => '跳过剩余概念形成';

  @override
  String get knownCheckAnchor => '回到锚点流程';

  @override
  String get learnEmptyTitle => '当前内容目录已全部在学';

  @override
  String get learnEmptyBody => '新内容发布后会出现在这里。';

  @override
  String get learnBackHome => '回首页';

  @override
  String get reviewQuit => '退出';

  @override
  String get reviewTransferTitle => '符号检索验收';

  @override
  String get reviewLoadError => '加载失败';

  @override
  String get recallDelayedRetrieval => '延迟检索 · 新经验';

  @override
  String get recallRevisit => '经验回访 · 换一段没见过的';

  @override
  String get recallPrompt => '这种状态，你会用哪个词？';

  @override
  String get recallHint => '先自己想出来，再看答案';

  @override
  String get revealShowAnswer => '显示答案';

  @override
  String get reviewTransferDone => '符号检索验收完成';

  @override
  String get reviewDone => '本轮复习完成';

  @override
  String get reviewRetrieved => '已检索';

  @override
  String get reviewReviewed => '已复习';

  @override
  String get reviewBackHome => '回首页';

  @override
  String get groupNoneInProgress => '没有进行中的组会话';

  @override
  String get groupBackHome => '回首页';

  @override
  String get groupDoneTitle => '本组理解完成';

  @override
  String get groupNewExperiences => '新建经验';

  @override
  String get groupBoundaryDiscrimination => '边界判别';

  @override
  String get groupMinutes => '分钟';

  @override
  String get groupRest => '回首页休息一下';

  @override
  String get groupStartRecall => '开始符号检索验收';

  @override
  String get groupGoReview => '去复习';

  @override
  String get mapTitle => '概念地图';

  @override
  String get mapAll => '全部';

  @override
  String get mapLearned => '已学习';

  @override
  String get mapEmpty => '当前筛选下没有内容';

  @override
  String get mapDiffDim => '不同维度';

  @override
  String get mapOverlap => '重叠';

  @override
  String get libNone => '暂无';

  @override
  String get libTitle => '我的内容';

  @override
  String get libReplay => '经验回放';

  @override
  String get libPreview => '预习';

  @override
  String get libTransfer => '迁移验收';

  @override
  String get libTransferBody => '已学义项数';

  @override
  String get libStudyLists => '在学词单';

  @override
  String get libRecentLearned => '近日已理解';

  @override
  String get libAllLearned => '全部已理解';

  @override
  String get libConceptMap => '我的概念地图';

  @override
  String get libFavorites => '场景收藏';

  @override
  String get libNotes => '笔记';

  @override
  String get libReplayLabel => '经验回放';

  @override
  String get libReviewLabel => '回顾';

  @override
  String get libPreviewLabel => '预习';

  @override
  String get libLookFirst => '先看';

  @override
  String get libToday => '今日';

  @override
  String get replayTitle => '经验回放';

  @override
  String get replayEmptyTitle => '还没有已学习的经验';

  @override
  String get replayEmptyBody => '先完成一组首学，再来回放。';

  @override
  String get replayNoExperience => '暂无经验';

  @override
  String get replayUnfavorite => '取消收藏';

  @override
  String get replayFavorite => '收藏';

  @override
  String get replayPrev => '上一个';

  @override
  String get replayNext => '下一个';

  @override
  String get previewTitle => '预习';

  @override
  String get previewEmpty => '没有待预习的内容';

  @override
  String get previewEnterLearn => '进入首学（下一组）';

  @override
  String get previewNewSense => '新义项 · 先看锚点经验';

  @override
  String get previewFromExperience => '从经验进入首学';

  @override
  String get learnedRecent => '近日已理解';

  @override
  String get learnedAll => '全部已理解';

  @override
  String get learnedEmpty => '还没有已理解的义项';

  @override
  String get learnedDue => '待复习';

  @override
  String get favTitle => '场景收藏';

  @override
  String get favUnfavorite => '取消收藏';

  @override
  String get notesTitle => '笔记';

  @override
  String get studyTitle => '我的学习';

  @override
  String get studyPreferences => '学习偏好';

  @override
  String get studyPlan => '计划';

  @override
  String get studyLists => '词单';

  @override
  String get studyScope => '当前学习范围';

  @override
  String get studyBySense => '按义项组织，不按词头';

  @override
  String get studyDailyNew => '每日新理解义项';

  @override
  String get studyStats => '统计';

  @override
  String get studyTodayLearnReview => '今日理解&复习';

  @override
  String get studySenses => '义项';

  @override
  String get studyCumulativeLearned => '累计理解';

  @override
  String get studyTodayMinutes => '今日总时长';

  @override
  String get studyMinutes => '分钟';

  @override
  String get studyCumulativeMinutes => '累计时长';

  @override
  String get studyCheckinCalendar => '签到日历';

  @override
  String get studyTodayCol => '今';

  @override
  String get profileLearning => '学习中';

  @override
  String get profileReviewing => '复习中';

  @override
  String get profileRelearning => '再学中';

  @override
  String get profileNewCards => '新卡';

  @override
  String get profileBack => '返回';

  @override
  String get profileLearner => 'SceneLex 学习者';

  @override
  String get profileNoMember => '未开通会员';

  @override
  String get profileLearnedSenses => '已理解义项';

  @override
  String get profileExperiencesLoading => '经验场景统计中…';

  @override
  String get profileMastery => '掌握度';

  @override
  String get profileAppearance => '外观';

  @override
  String get profilePreferences => '学习偏好';

  @override
  String get profileMoreSettings => '更多设置';

  @override
  String get profileNoRecords => '暂无学习记录';

  @override
  String get prefSectionUnderstanding => '理解流程';

  @override
  String get prefTransferTiming => '符号检索验收时机';

  @override
  String get prefBoundaryPerturbation => '边界扰动题';

  @override
  String get prefSymbolRecall => '符号回指';

  @override
  String get prefScaffold => 'L1 脚手架';

  @override
  String get prefScaffoldLevel => '叙事语言档位';

  @override
  String get prefScaffoldCurrent => '当前档位';

  @override
  String get prefAutoScaffoldRemoval => '自动撤除';

  @override
  String get prefZhLabelBeforeReveal => '揭示前显示中文标签';

  @override
  String get prefSectionRhythm => '节奏';

  @override
  String get prefNewGroup => '新学节奏';

  @override
  String get prefNewGroupHint => '一个义项约 90 秒';

  @override
  String get prefReviewGroup => '复习节奏';

  @override
  String get prefSectionVoice => '发音与提醒';

  @override
  String get prefAccent => '发音类型';

  @override
  String get prefAccentUs => '美式';

  @override
  String get prefAccentUk => '英式';

  @override
  String get prefAutoPronounce => '自动发音';

  @override
  String get prefReminder => '学习提醒';

  @override
  String get prefReminderHint => '映射到通知设置';

  @override
  String get prefTransferEndOfDay => '当天收尾';

  @override
  String get prefTransferEndOfFirstLearning => '首学末尾';

  @override
  String get prefTransferFirstReview => '首次复习';

  @override
  String get prefScaffoldZh => '中文';

  @override
  String get prefScaffoldMixed => '中英混排';

  @override
  String get prefScaffoldEn => '纯英文';

  @override
  String get prefReminderReveal => '符号揭示时';

  @override
  String get prefReminderRevealExample => '揭示 + 例句';

  @override
  String get prefReminderOff => '关闭';

  @override
  String get prefReminderSmart => '智能提醒';

  @override
  String get prefReminderFixed => '固定时间';

  @override
  String get prefTitle => '学习偏好';

  @override
  String get homeProfile => '个人中心';

  @override
  String get brandTagline => '意义即经验；微世界即经验。';

  @override
  String get knownCheckTitle => '熟 · 概念迁移检查 · 不会直接标为已会';

  @override
  String get knownCheckPassHint => '通过：已能识别该概念 → 跳过剩余概念形成。';

  @override
  String get recallNewExperience => '新经验 · 之前没见过这一个';

  @override
  String get gradeNextUsesNewExperience => 'FSRS-6 · 下次复习会换一段没见过的经验';

  @override
  String get reviewTransferDoneBody => '用全新经验完成了延迟的「经验 → 符号」检索';

  @override
  String get transferIntro => '概念迁移已经在每个词的符号揭示前完成。这里开始的是延迟符号检索：';

  @override
  String get transferIntro2 => '看一个新经验，能不能重新想起刚绑定的 L2 符号。';

  @override
  String get transferDeferred => '迁移测试已推迟到第一次复习时进行（当前偏好：首次复习）。';

  @override
  String get transferAtEnd => '迁移测试已在每个义项的首学末尾完成（当前偏好：首学末尾）。';

  @override
  String get mapBoundariesNotCollected =>
      '边界关系（relations.boundaries）尚未收录 — 内容欠账，待编译器输出。';

  @override
  String get replayOnlyScene => '只重看场景，不重看词——回忆词是复习的事';

  @override
  String get favEmpty => '还没有收藏。首学或回放时点星标即可收藏经验。';

  @override
  String get notesEmpty => '还没有写过笔记。首学「更多」菜单里可以为当前义项写笔记。';

  @override
  String get prefTransferTimingHint => '概念迁移已固定在揭示前；这里控制何时测试「经验 → L2 符号」';

  @override
  String get prefBoundaryPerturbationHint => '用对比 / 反例场景压掉错误泛化';

  @override
  String get prefSymbolRecallHint => '揭示后补一次「场景 → 词」的检索';

  @override
  String get prefAutoScaffoldRemovalHint => '复习次数增加后逐档切到纯英文';

  @override
  String get prefZhLabelBeforeRevealHint => '打开等于回到「先给翻译」，默认关闭';

  @override
  String noteTitle(Object senseId) {
    return '笔记 · $senseId';
  }

  @override
  String learnLoadError(Object errorMessage) {
    return '加载失败：$errorMessage';
  }

  @override
  String learnWordProgress(Object index, Object count) {
    return '第 $index / $count 词';
  }

  @override
  String reviewDoneBody(Object gradedCount) {
    return '$gradedCount 条复习记录已写入本地 review events';
  }

  @override
  String groupDoneBody(Object senseCount) {
    return '$senseCount 个义项的经验已经建立';
  }

  @override
  String mapLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String mapBoundaryCriterion(Object diagnostic) {
    return '判据：$diagnostic';
  }

  @override
  String libRecent7d(Object recentCount) {
    return '近 7 天 $recentCount 义项';
  }

  @override
  String libReplayBody(Object learnedCount) {
    return '$learnedCount 义项经验';
  }

  @override
  String libPreviewBody(Object clamped) {
    return '$clamped 场景';
  }

  @override
  String libStudyListsBody(Object learnedCount) {
    return '$learnedCount 义项';
  }

  @override
  String libAllLearnedBody(Object learnedCount) {
    return '$learnedCount 义项';
  }

  @override
  String libConceptMapBody(Object catalogSize) {
    return '$catalogSize 义项';
  }

  @override
  String libFavoritesBody(Object favoritesCount) {
    return '$favoritesCount 个';
  }

  @override
  String libNotesBody(Object notesCount) {
    return '$notesCount 条';
  }

  @override
  String replayLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String replayCounter(Object index, Object total) {
    return '经验 $index / $total';
  }

  @override
  String previewLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String learnedLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String learnedReviewedN(Object reps) {
    return '已复习 $reps 次';
  }

  @override
  String favLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String notesLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String studyLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String studyLearned(Object learnedCount) {
    return '已理解 $learnedCount';
  }

  @override
  String studyCatalogSize(Object catalogSize) {
    return '总义项 $catalogSize';
  }

  @override
  String studyDailyGoal(Object dailyGoal) {
    return '$dailyGoal / 天';
  }

  @override
  String studyStreak(Object streakDays) {
    return '连续签到 $streakDays 天';
  }

  @override
  String profileExperienceCount(Object count) {
    return '$count 个经验场景';
  }

  @override
  String profileFsrsSummary(Object total) {
    return 'FSRS 状态分布 · $total 义项';
  }

  @override
  String prefNewGroupSize(Object groupSize) {
    return '$groupSize 义项/组';
  }

  @override
  String prefReviewGroupSize(Object groupSize) {
    return '$groupSize 义项/组';
  }
}
