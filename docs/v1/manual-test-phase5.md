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
