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
}
