# flashcards-open-source-app 行为规格书(SceneLex v1 复刻依据)

> 来源:对 `/Users/shadow/flashcards-open-source-app` 的完整代码审计(2026-08-10)。
> 本文件是复刻的**行为权威**:实现时以本清单为准,不得凭记忆增删行为。
> 对应计划见 [rewrite-plan.md](rewrite-plan.md)。

## 1. 导航结构

- 5 个底部 Tab:Review(默认)/ Progress / Cards / Settings(v1 裁剪 AI Tab;web 端同名顶部导航)。
- Tab 间跳转:Review 空态 "Create card" → Cards 并打开新建;Review 徽章 → Progress 并滚动到对应区块。
- 设置 20+ 子页面(见 §7)。

## 2. Review(今日学习)界面行为

### 卡片展示
- Front 卡面可见;点 "Show answer"(web 空格)后显示 Back。
- 卡面渲染启发式:短文本大字号居中 / 段落文本 / Markdown(标题、引用、列表、表格、代码围栏)/ LaTeX($..$ 与 $$..$$)/ 图片。
- 顶部显示标签 + 复习次数徽章(reps=0 显示 "New")。
- 每卡面有 TTS 朗读按钮(自动检测语言);朗读失败瞬态 banner。
- 预取下一张卡("warm next card"),评分后立即展示下一张。

### 评分
- 2×2 网格:Again(0)/ Hard(1)/ Good(2)/ Easy(3)。
- 每按钮显示下次间隔文案(<60s → "in less than a minute")。
- 提交中禁用按钮;提交失败内联错误或 alert("Review wasn't saved")。
- 提交走 outbox:本地先写,再后台推送。

### 动画
- 评分反应动画:开关(默认开,低电量自动禁用),同屏最多 3 个,随机变体。
- 触摸即取消动画。

### 队列
- 种子 8 张,低于 4 张时后台补充。
- 队列清空回到空状态;无"完成页"。
- 无每日目标概念(streak + 通知替代)。
- 筛选菜单:All Cards / Deck 列表 / Tags 列表(多选、带计数);筛选持久化。

### 空态
- 无卡片:"No Cards Yet" → Create card。
- 无到期:"Nothing Due" → Create card;筛选视图额外提供 "Switch to all cards deck"。

### 其他
- 编辑按钮(铅笔)打开编辑;Hard 用法提醒(对已会但难的卡选 Hard 时提示 "If you did not know the answer, choose Again...")。
- web 快捷键:空格翻面;1/2/3/4 评分(仅答案可见时;编辑器/弹窗打开或输入框聚焦时禁用)。

## 3. Cards(词表)界面行为

- 列表行:正面文本 + 标签 + 到期时间;左滑删除(二次确认,文案提示"从本地列表和下次同步中移除")。
- 搜索 + 标签筛选。
- 新建/编辑:Front/Back 文本区、标签选择器(输入即筛选、显示计数、可新建、大小写规范化)、图片插入(压缩后以托管 markdown 引用插入)。
- 编辑态显示只读元数据(Due/Reps/Lapses)。

## 4. Deck 与标签

- **Deck = 智能筛选,不是文件夹**:名称 + 标签规则(匹配任一选中标签);必须至少选 1 个标签。
- "All Cards" 为内置系统项,不可编辑。
- Deck 详情:规则、统计、匹配卡片列表、"Review this deck" 直接进入对应筛选复习。

## 5. Progress(进度)界面行为

5 张卡垂直排列 + 下拉刷新 + 离线占位卡:

1. **Streak**:连续天数徽章(今天已复习高亮)、冻结额度 chip、周历网格(复习日火焰/冻结日雪花/今天描边)。
2. **Reviews**:按天堆叠柱状图(Again/Hard/Good/Easy 四色),周分页、点柱选日、点图例切换过滤。
3. **Review Schedule**:环形图分桶(new / today / 1-7d / 8-30d / 31-90d / 91-360d / 1-2y / later),点扇区选中。
4. 评分榜 / 连续榜:**v1 裁剪**(依赖社区后端)。
- 数据:本地聚合(每日复习数、streak)+ 服务器快照;按 workspace 时区分日。

## 6. 认证与账号行为

### 登录(email + OTP,无密码)
- 输入邮箱 → 发送 8 位码 → 验证。**自动注册**(无独立注册页)。
- 防枚举:响应前随机延迟 200-800ms。
- OTP:3 分钟生命周期、同一挑战最多 5 次尝试后锁定(需重发)、会话一次性使用。
- 限流:邮箱 60s/15min/24h = 3/5/10(超限软抑制,复用最近挑战);IP 15min/1h/24h = 10/30/100(硬 429);IP 不同邮箱 1h/24h = 5/20。
- 错误文案:expired / invalid / already used / too many attempts / could not verify。

### 会话
- Web:cookie 会话(35 天,refresh cookie 滚动续期),CSRF(无状态 HMAC 推导)。
- 移动端:idToken + refreshToken,`refresh-token` 端点续期,`revoke-token` 登出。
- 已删除账号的旧 token → 410 ACCOUNT_DELETED。

### 用户 bootstrap
- 首次认证请求自动:创建 user_settings、创建 "Personal" workspace 并选中。

### Workspace
- 列表/创建/切换/重命名/删除(确认文本 `delete workspace`,仅 owner 且 sole member)/reset-progress(确认文本)。

### 账号删除
- 必须输入 `delete my account`;删除:sole-member workspaces 级联删、user_settings、认证工件、deleted_subjects tombstone。
- 客户端清除本地数据但保留安装身份。

### 登出
- 移动端:确认弹窗("Log out and clear this device?")→ 清本地全部工作区与同步数据。

## 7. 设置项清单(v1)

| 分组 | 设置项 |
|---|---|
| 复习 | Review Animations(评分动画开关) |
| 通知 | Enable notifications、模式(Once daily 固定时间 / Inactivity 时间窗 + 重复间隔 30-240min)、badge、严格提醒(睡前 4/3/2h) |
| 调度 | FSRS-6 固定;desired retention(默认 0.90)、learning steps(默认 [1,10])、relearning steps(默认 [10])、maximum interval(默认 36500)、enable fuzz(默认 true);保存需确认("affects future reviews only")、可重置默认 |
| 工作区 | 当前 workspace、切换/重命名、Decks 管理、Tags 管理、Reset Study Progress、Delete Current Workspace |
| 账号 | Account Status(linked/guest/disconnected、Sync status、Last sync、Sign in/Sync now/Log out)、Language、Legal、Support、Open Source、Server 信息、Device 信息、Danger Zone(Delete Account) |
| 其他 | 语言(跟随系统 / web 独立选择器)、分享 App |

## 8. 多语言

- 9 语言:en / ar(RTL) / zh-Hans / de / hi / ja / ru / es-MX / es-ES。
- 机制:iOS 跟随系统 + 字符串表;web 应用内选择器 + Auto + preference 持久化。
- SceneLex 可替换语言集合,但保留机制。

## 9. 同步系统行为(字段级规格)

### 客户端数据流
- 本地优先:实体先落库,再写 outbox(web 两个独立事务;移动端同一 SQLite 事务)。
- 每次 mutation 立即入 outbox,然后触发后台同步(本地 mutation / 前台激活 / 在线事件 / 定时轮询 / 手动 Sync now)。
- review 提交产生**两条** outbox 记录:`review_event`(append,operationId = reviewEventId)+ 实体 upsert(affectsReviewSchedule: true)。
- 删除是墓碑(tombstone):deletedAt 置时间戳,仍走 upsert 操作,无独立 delete 操作类型。

### outbox 记录结构
```
operationId, workspaceId, createdAt(clientUpdatedAt), attemptCount(失败+1),
lastError, affectsReviewSchedule?, operation{entityType, entityId, action, clientUpdatedAt, payload}
```
- 按 createdAt 顺序推送,每批 100 条。
- ack(status ∈ applied/ignored/duplicate)后删除对应行;rejected → 标记失败并阻止后续批次。

### 端点协议
公共请求字段:`{installationId, platform, appVersion}`。

1. **POST `/workspaces/:id/sync/push`**
   - 请求:`{operations: [{operationId, entityType, entityId, action: upsert|append, clientUpdatedAt, payload}]}`
   - 响应:`{operations: [{operationId, status: applied|ignored|duplicate|rejected, resultingHotChangeId, error}]}`
   - review_event 要求 `clientUpdatedAt === payload.reviewedAtClient`。
   - 单事务;先 ensure workspace replica。

2. **POST `/workspaces/:id/sync/pull`**(hot 增量)
   - 请求:`{afterHotChangeId, limit: 1..500, includeMediaAssets?}`
   - 响应:`{changes: [{changeId, entityType, entityId, action: upsert, payload}], nextHotChangeId, hasMore}`
   - 服务端:`DISTINCT ON (entity_type, entity_id)` 每实体最新一条,change_id > afterHotChangeId,按 change_id ASC,limit+1 判 hasMore。
   - 过期游标(小于 min_available_hot_change_id)→ 409 SYNC_BOOTSTRAP_REQUIRED。

3. **POST `/workspaces/:id/sync/bootstrap`**(双模式)
   - pull 模式:不透明游标分页(内部三元组 [bootstrapHotChangeId, entityRank, entityId]),rank: 0=settings, 1=learning_state, 2=内容元数据…;响应含 `bootstrapHotChangeId`(客户端初始 hot 游标)与 `remoteIsEmpty`。
   - push 模式(远端为空时本地反哺):entries 带完整快照;响应 `{appliedEntriesCount, bootstrapHotChangeId}`;非空时 409 保护。

4. **POST `/workspaces/:id/sync/review-history/pull`**
   - 请求:`{afterReviewSequenceId, limit: 1..500}`;响应:`{reviewEvents, nextReviewSequenceId, hasMore}`。
   - keyset:`review_sequence > ? ORDER BY review_sequence ASC`。

### 幂等
- `applied_operations`:push 前按 operationId 查历史,命中 → duplicate + 原始 resultingHotChangeId,不重放。
- ReviewEvent 双重去重:PK review_event_id + UNIQUE (workspace, replica, client_event_id),`INSERT ... ON CONFLICT DO NOTHING`。

### LWW 冲突裁决(三字段,大者胜)
1. `clientUpdatedAt`(ISO 归一化)
2. `lastModifiedByReplicaId`(字节序比较)
3. `lastOperationId`(字节序比较)
- 服务端输 → `applied: false`,不改写 canonical 行,返回现存 winner 的 change_id。
- 客户端落盘同样比较(iOS SyncApplier:远端不如本地新 → skipped)。

### 设备模型
- `installations`:客户端生成的全局物理安装身份,跨 workspace 复用,平台不可变。
- `workspace_replicas`:replica_id = 确定性派生 `uuid_from_seed(sha256("{workspaceId}:{installationId}"))`;同安装同 workspace 恒为同一 replica。
- 每次同步请求:claim installation → upsert replica → 身份键不匹配 → 409 SYNC_REPLICA_CONFLICT。

### 客户端游标
- 本地保存:`lastAppliedHotChangeId`、`lastAppliedReviewSequenceId`、hasHydratedHotState、hasHydratedReviewHistory。
- 首次:bootstrap 循环水合(1000/页),**最后一页**才写初始 hot 游标。
- 增量:pull 循环(500/页),每页推进游标直到 hasMore=false。
- 本地库被清空的自愈:检测后重新全量 bootstrap。

## 10. FSRS-6 行为规格

### 权重与常量
- 21 权重固定(见 rewrite-plan 引用源 `apps/backend/src/scheduling/index.ts`),不可配置。
- 常量:S_MIN=0.001、W17/W18 上限 2、fuzz 区间 [2.5,7)→0.15 / [7,20)→0.1 / [20,∞)→0.05、间隔上限 36500。

### 持久化状态(每学习实体)
```
due_at(TIMESTAMPTZ, NULL=新)、reps、lapses、
fsrs_stability、fsrs_difficulty(1..10)、fsrs_last_reviewed_at、
fsrs_scheduled_days、fsrs_card_state(new|learning|review|relearning)、fsrs_step_index
```
- 不变量:new 必须全 NULL;review 必须 step_index IS NULL;learning/relearning 必须 step_index NOT NULL。

### 评级映射
- Again=0 / Hard=1 / Good=2 / Easy=3;FSRS grade = rating+1。
- New:Again/Hard 进 learning 第一步(1.5× 或前两步均值);Good 下一步或毕业;Easy 直接毕业。
- Learning:Again 重置第一步;Hard 不推进;Good 下一步或毕业;Easy 立即毕业。短期公式。
- Review:Again → 失败更新 + 进 relearning;Hard ≤ Good(取 min);Good 基准;Easy ≥ Good+1。长期公式。
- Relearning:同 learning,毕业回 review。
- 每次复习 reps+1;lapses 仅 review 态 Again 时 +1。
- fuzz 种子:`"${now.getTime()}_${reps}_${difficulty*stability}"`。

### due 计算
- 短期:复习时点 + 步骤分钟(scheduled_days=0)。
- 长期:`intervalModifier = ((retention^(1/DECAY))-1)/FACTOR`,raw = round(stability × modifier),clamp 1..maxInterval;fuzz 按区间取整(min 有 elapsedDays+1 约束)。

### 队列
- 取 `due_at IS NULL OR due_at <= now`;内存过滤未来卡。
- rank:最近 1h 内复习过的到期卡 → 其他到期卡 → 新卡 → 未来卡;tie-break: dueAt ASC → createdAt DESC → id ASC。
- Again/短步后卡片因最近复习跃升到老逾期卡之前。

### workspace 设置
- 可配置:desired_retention(0.90)、learning_steps([1,10])、relearning_steps([10])、maximum_interval_days(36500)、enable_fuzz(true)。
- 不存在:每日新卡数、FSRS 开关(恒开)、权重配置。
- forward-only:改动只影响未来复习。

## 11. 进度统计规格

- **streak**:用户级 `user_active_review_days`(按 user + local_date,所有 rating 计数),freeze 策略:容量 2、每复习日 +1 unit、10 units = 1 冻结额度。
- **每日柱状图**:review_events 按 reviewed_local_date 分组,workspace 级,四色分桶。
- **日程分桶**:cards.due_at 相对请求时区的本地日边界:new/today/1-7d/8-30d/31-90d/91-360d/1-2y/later。
- 时区:workspace 时区分日;reviewedAtClient 为时间基准。

## 12. flashcards 关键文件索引(对照用)

| 层 | 文件 |
|---|---|
| FSRS | `apps/backend/src/scheduling/index.ts`、`docs/fsrs-scheduling-logic.md`、`tests/fsrs-full-vectors.json` |
| 同步后端 | `apps/backend/src/sync/replication/{push,bootstrap,hotPull,reviewHistory,changes}.ts`、`sync/conflicts/{lww,fork}.ts`、`sync/identity/replica.ts` |
| 同步契约 | `apps/backend/src/sync/contracts/{input,types,snapshots}.ts` |
| 路由 | `apps/backend/src/routes/sync/index.ts`、`apps/backend/src/server/app.ts` |
| Web 本地 | `apps/web/src/localDb/`、`apps/web/src/appData/sync/` |
| iOS 本地 | `apps/ios/Flashcards/Flashcards/Database/`、`Cloud/Sync/` |
| Auth | `apps/auth/src/`、`docs/auth-service.md` |
| 迁移 | `db/migrations/`(110 个;0028 同步重写、0035 replica 化、0039 claim 为关键) |
