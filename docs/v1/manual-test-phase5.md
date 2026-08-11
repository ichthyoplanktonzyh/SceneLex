# Phase 5 手动验证指引(进度 / 设置 / 多语言 / 通知 / 词表)

目标:验证 P5 功能完整化——进度界面(Streak/柱状图/日程环形图,本地聚合)、
设置界面(FSRS 调度设置走 outbox)、多语言(en + zh-Hans)、本地通知(移动端)、
词表增强(搜索/行内统计)。

## 前置

```bash
docker compose -f docker/docker-compose.yml up -d
cargo run -p scenelex-server                # :8081
.venv/bin/python scripts/import_content.py  # 首次
cd app && flutter run -d chrome --web-port 8090   # web
# 移动端:flutter run(模拟器/真机,通知仅在 iOS/Android/macOS 有效)
```

## 验证步骤

### 1. 建立数据
- 登录 → 词表添加 3-4 个词 → Review 学习并评分
  (多次评分制造不同 rating / 不同日期的复习事件)。

### 2. 进度界面
- 进入 Progress tab:
  - **Streak 卡**:连续天数徽章(今天复习过高亮)+ 冻结额度 chip
    (初始 2/2)+ 5 周周历网格(复习日火焰/今天描边)。点 chip 上的
    "i" 查看冻结规则说明。
  - **Reviews 卡**:按天堆叠柱状图(Again/Hard/Good/Easy 四色)。
    - 点柱 → 图例数字变为该日统计;再点取消。
    - 点图例 → 只显示该 rating;再点取消。
    - 左右箭头切换周(多周数据时)。
  - **Review Schedule 卡**:环形图分桶(新词/今天/1-7 天/…/更久);
    点扇区或图例行选中(中心显示该桶数量)。
  - 下拉刷新:触发同步后重新聚合。
- 跨天验证(可选):把系统时间改到昨天/前天再评一次分,再改回,
  Streak 应把历史复习日计入,且 today 尚未复习时显示 pending。

### 3. 设置界面
- Settings tab:
  - 账号:显示邮箱;退出登录弹确认框(取消/确认)。
  - 调度设置:进入后修改 desired retention(如 0.95)→ 保存 →
    确认弹窗("仅影响未来的复习")→ 保存成功。重启 app 后值保留。
  - 验证 outbox 同步:保存后触发同步,server 端:
    ```bash
    docker exec scenelex-postgres psql -U scenelex -d scenelex -c \
      "SELECT desired_retention FROM org.workspace_scheduler_settings;"
    ```
    应为新值。再次同步不报错(幂等)。
  - 重置默认:值恢复 0.90 / [1,10] / [10] / 36500 / fuzz on。
  - 危险操作区:两项显示为"即将上线"占位(禁用)。
- **语言(web)**:Settings → 语言切换 English / 中文 / Auto,立即生效并持久化
  (刷新页面保留)。
- **语言(移动端)**:显示"跟随系统语言";切换系统语言后 app 跟随。

### 4. 词表增强
- 搜索框:输入 lemma / senseKey / pos 子串过滤;无匹配显示空态。
- 行内统计:已添加的词显示状态 chip(新词/学习中/复习)+ 到期数 +
  复习次数 + 失误次数(有 lapses 时)。
- 点击已添加的词 → 底部弹出详情(下次复习 / 状态 / reps / lapses)。

### 5. 本地通知(移动端)
- Settings → 通知:启用每日提醒 → 系统权限弹窗(允许)。
- 时间选择器设为 2 分钟后 → 等待触发:
  - Android/iOS/macOS:应收到本地通知("SceneLex / 该进行今天的
    SceneLex 复习了。")。
  - web:设置页显示"当前平台不支持通知"(无开关)。
- 关闭开关 → 通知取消(不再触发)。
- 重启 app:开关状态与时间保留,已启用时自动重新调度。

### 6. 回归
- Review 全流程(Experience Player + 评分)不受影响。
- 断网评分仍可用(P4 回归)。
- `flutter test`:FSRS 黄金向量 15/15 + streak/freeze parity 9 例全过。

### 7. Web 键盘快捷键(P6)
- 在 Review 页(Experience Player 播放中),不点按钮,直接用键盘:
  - **空格**:进入下一 stage;最后一个 stage 后进入评分。
  - **1 / 2 / 3 / 4**:评分(Again / Hard / Good / Easy),仅评分界面可见时。
- 禁用场景:
  - 切到其他 tab(词表/进度/设置)后按 1-4/空格:无效果。
  - 输入框聚焦时(如词表搜索框):1-4/空格正常输入文本。
  - 弹窗打开时(如退出登录确认、时间选择器):无效果。
- 切回 Review tab:快捷键立即恢复生效。

### 8. 桌面端(macOS)
- `cd app && flutter build macos --debug` 应成功产出 `scenelex.app`。
- `flutter run -d macos`:登录/学习/进度/设置全流程可用;键盘快捷键同 web。
- Windows/Linux:需在对应平台构建验证(通知在 Linux 不可用,设置页显示降级说明)。

## 验收清单

- [ ] Streak:连续天数、冻结额度(初始 2、消费 1 后 1)、周历火焰/雪花/今天描边
- [ ] Reviews 柱状图:四色堆叠、周分页、点柱选日、图例过滤
- [ ] Review Schedule:8 桶环形图、点选扇区
- [ ] 下拉刷新触发同步后重聚合
- [ ] 调度设置保存 → 本地 + outbox → server 值更新(重启不丢)
- [ ] 语言切换(web 选择器持久化;移动端跟随系统)
- [ ] 通知开关 + 时间生效(移动端),web 降级说明
- [ ] 词表搜索 + 行内统计 + 详情弹窗
- [ ] 退出登录确认弹窗

### 9. TTS 朗读(P7-A)
- Review 页 Experience Player 每个 stage:右上角朗读按钮(🔊)。
  - 点击:朗读当前 stage 的叙事内容(自动检测语言)。
  - 再点(朗读中):停止。
  - stage 前进/评分后:自动停止。
- 评分界面:右上角朗读按钮朗读词头(lemma)。
- 内容为空(无 synopsis)时按钮不显示。
- 朗读失败(如浏览器无语音):底部瞬态 banner"无法朗读",不崩溃。
- 语言检测:含中文 → zh 语音;英文 → en 语音(取决于浏览器/系统语音)。

### 10. Markdown/LaTeX 渲染(P7-A)
- 导入含 markdown 的叙事/任务内容(标题/引用/列表/表格/代码围栏):
  对应样式渲染(标题加粗放大、引用斜体、表格有边框、代码等宽背景)。
- 公式降级:含 `$x^2$` / `$$\int$$` 的内容以等宽文本显示(不隐藏、不报错)。
- 短文本(≤4 词且 ≤48 字符):大字居中;多段文本:正文样式。
- 纯文本内容(现有 4 词义)渲染样式不变。

### 11. 评分反应动画(P7-A)
- 评分(Again/Hard/Good/Easy)后:屏幕下方约 75% 处弹出随机动画
  (如乌云/老虎/水獭/日出等变体,每次不同)。
- 连续快速评分 4 次:同屏最多 3 个动画(最早的被挤掉)。
- 动画播放完自动消失(时长随变体 1.2s~4.3s)。
- 触摸屏幕任意位置:所有动画立即消失。
- Settings → 复习 → Review Animations 关闭:评分后不再出动画;
  已显示的立即清除;重新打开恢复。
- 低电量模式(iOS 控制中心 / Android 省电模式):动画自动禁用
  (不改变开关状态),退出低电量后恢复。

### 12. 回归(P7-A)
- `flutter analyze` 0 问题;`flutter test` 25 全过。
- `flutter build web` 成功;Lottie 资产(38 个 JSON)打包进 build/web。
- 断网学习(P4)与同步(P2 协议)回归不受影响。

### 13. 词单 Lists(P7-B)
- Settings → 工作区 → 词单:默认显示内置「全部词义」(不可编辑,显示总数)。
- 新建词单:名称必填 + 至少选 1 个标签(预置标签 `type:xxx` / `pos:xxx`,
  带计数);不满足时保存按钮禁用。
- 编辑词单:改名/改标签;删除:确认弹窗后词单消失(下次同步推送墓碑)。
- 词单详情:规则标签、统计(匹配/当前到期)、匹配词义列表、
  「复习这个词单」→ 跳到 Review tab 且队列按该词单筛选。
- 刷新另一台设备(或重建本地库后 bootstrap):词单从 server 恢复。

### 14. Review 筛选菜单(P7-B)
- Review 左上角显示当前筛选(默认 All Cards),点击弹出筛选面板:
  - All Cards(带总数)/ 词单列表(带匹配数,单选)/ 标签(多选带计数)。
  - 「完成」后队列立即按筛选重建;重启 app 后筛选保持(持久化)。
- 筛选后空队列:空态出现「切换到全部词义」按钮。
- 词单被删除后:筛选回落到 All Cards 显示。

### 15. 左滑删除学习状态(P7-B)
- 词表页已添加的词义:向左滑动 → 确认弹窗
  ("该词将从本地列表和下次同步中移除")。
- 确认后:词义回到「学习」按钮状态(未添加),从 Review 队列消失。
- 同步后服务端该 learning_state 为墓碑;重新点击「学习」可再次添加。
- 取消确认:滑动不生效。

### 16. 标签系统(P7-B)
- 词义标签为预置只读:由 semanticType/pos 派生(`type:xxx` / `pos:xxx`),
  大小写已规范化;无用户自定义标签入口。
- 词单规则与筛选面板的标签均来自同一预置集合,计数一致。

### 17. 通知模式扩展(P7-C,移动端)
- Settings → 通知:进入通知页。
- 模式切换「每天一次」:时间选择器,每日固定时间提醒(原有行为)。
- 模式「不活动时」:从/至时间窗 + 重复间隔(30/60/90/120/180/240 分钟);
  当天窗口内按间隔排提醒,晚于「上次活动 + 间隔」的候选跳过
  (学习/打开 app 会更新活动时间并重排)。
- 角标开关:提醒发出且当天未学习时应用图标显示 1;打开 app 清除。
- 连续学习提醒:当天未学习时,午夜前 4/3/2 小时各一条提醒。
- web:设置页通知不可用(降级说明);iOS/Android/macOS 生效。

### 18. 工作区管理(P7-C)
- Settings → 工作区:列出所有工作区(当前选中高亮)。
- 新建工作区:自动切换;本地数据清空并按新工作区重新 bootstrap。
- 重命名:弹窗输入新名称。
- 切换:本地数据清空并按目标工作区重新 bootstrap(词单/学习状态为该
  工作区数据)。
- Settings → 危险操作:
  - 重置学习进度:输入 "reset all progress for all cards in this
    workspace" 确认 → 服务端清空学习状态与复习历史,本地同步清空。
  - 删除当前工作区:输入 "delete workspace" 确认 → 工作区删除,自动
    落到剩余工作区(或重建 Personal)。
- 错误确认文本:按钮禁用;错误短语无法提交。

### 19. 账号删除(P7-C)
- Settings → 危险操作 → 删除账号:输入 "delete my account" 确认。
- 成功后:本地学习数据清空、回到登录页(安装身份保留)。
- 旧 token 已被删除:任何请求返回 410 ACCOUNT_DELETED。
- 再次用该邮箱登录:send-code 返回 410,无法重新注册。
- server e2e:`bash scripts/sync-e2e.sh` 19 步全过(含 rename/reset/
  delete/account-delete/410)。

### 20. 信息项(P7-C)
- Settings → 关于:开源(含 flashcards MIT 与 Lottie 资产归属)、法律信息、
  支持说明、服务器信息(API 地址/账号)、设备信息(平台/版本)、
  分享应用。

### 21. 队列种子与补充(P7-D)
- 有 20+ 到期/新卡的库:进入 Review,队列只显示前 8 张(页面右上角
  有 streak 徽章;当前卡标题/词义为队列第一张)。
- 连续评分:每评一张队列前移;剩余 ≤4 张时后台静默补充回 8(不打断)。
- 本会话已评的卡不再出现(即使 Again/Hard 后仍 due);重启 app 后
  学习中的卡重新进入队列。
- 全部评完 → 空态(无"完成页")。

### 22. Hard 用法提醒(P7-D)
- 连续 8 次评分中 Hard ≥ 5(冷却期内未显示过):弹非阻塞对话框
  "Quick reminder"(中:"快速提醒")。
- 文案:en "If you did not know the answer, choose \"Again\"..." /
  zh "如果您不知道答案,请选择「重来」…";"Got it / 知道了" 关闭。
- 关闭后 3 天内不再弹出;会话重启后评分窗口重置。

### 23. Review 徽章 → Progress 联动(P7-D)
- Review AppBar 右侧火焰徽章:显示当前连续天数;今天已复习时高亮。
- 点击徽章 → 跳到 Progress tab 并自动滚动到 Streak 卡。
- 桌面 hover 显示 tooltip(连续 X 天;已/未复习)。

### 24. 词表详情元数据(P7-D)
- Cards → 点击词义行 → 详情:Due(到期)/ State / Reps / Lapses 只读
  元数据,文案与参考一致(Due/Reps/Lapses)。

### 25. 队列 rank 对齐(P7 差距修复)
- 对一张到期卡评 Again/Hard(短期步进)→ 该卡立即回到队列,且排在更
  老的逾期卡之前(最近 1h 复习过的到期卡优先)。
- 同 dueAt 时:后加入学习的卡优先(createdAt DESC 代理)。
- 其余顺序:其他到期卡(按 dueAt ASC)→ 新卡。

### 26. 登出清本地数据(P7 差距修复)
- Settings → 账号 → Log out:确认弹窗("本地数据将被清除")。
- 确认后:回登录页;本地学习状态/复习事件/outbox/游标/词单全部清空
  (安装身份保留);重新登录后从服务端重新 bootstrap。
- 验证:退出前记录某卡 reps,重新登录后服务端数据回来(不同设备)。

### 27. 账号区同步状态(P7 差距修复)
- Settings → 账号:Account status(Linked)、Sync status(Synced/Syncing…/
  Offline)、Last sync(时间或 Never)、Sync now(手动触发)。
- 断网时点 Sync now → 状态变 Offline;恢复网络再点 → Synced + 时间更新。

### 28. 提交失败文案(P7 差距修复)
- 断网时评分(或临时改坏 API 地址)→ 内联错误显示
  "Review wasn't saved"(zh:"复习记录未能保存"),按钮恢复可点;
  恢复后重试成功。
