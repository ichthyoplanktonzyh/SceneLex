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
  String get settingsSyncStatus => '同步状态';

  @override
  String get syncStatusSynced => '已同步';

  @override
  String get syncStatusSyncing => '同步中…';

  @override
  String get syncStatusOffline => '离线';

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
  String get settingsWorkspaceSection => '工作区';

  @override
  String get settingsWorkspaceLists => '词单';

  @override
  String get settingsWorkspaceListsBody => '创建智能词单,筛选复习内容';

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
}
