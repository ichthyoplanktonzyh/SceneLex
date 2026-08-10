# Phase 3 手动验证指引(客户端学习闭环)

目标:验证 Flutter 客户端核心学习闭环——登录 → 词表 → 学习 → 经验播放 → 评分 → 队列推进。

## 前置

```bash
# 1. 基础设施
docker compose -f docker/docker-compose.yml up -d

# 2. server(默认 8081;8080 可能被本地 python http.server 占用)
cargo run -p scenelex-server

# 3. 导入词义库(首次)
.venv/bin/python scripts/import_content.py
# 期望输出: imported: 4 senses, 4 programs, 21 units
```

## Web 端(最快路径)

```bash
cd app
flutter run -d chrome --web-port 8090
```

## 验证步骤

1. **登录**:输入任意邮箱(如 `you@example.com`)→ 发送验证码 →
   从 server 日志找 `[DEV EMAIL] to=... code=XXXXXXXX` → 输入 8 位码 → 登录。
2. **词表(Cards tab)**:应看到 4 个词(almost / dirty / messy / reluctant)。
   点每个词右侧「学习」→ 状态变为「新词 · 等待学习」。
3. **今日学习(Review tab)**:
   - 队列出现刚添加的新词。
   - 点开 reluctant:播放 Experience Program:
     - 「经验原型」阶段显示标题 + 叙事(synopsis)
     - 依次经历 变式 → 边界扰动 → 区分 → 词义揭示 → 语言用法 → 迁移判断
     - 每个单元可点「继续」,带 learning_tasks 的显示判断题与选项
   - 播完进入评分:Again / Hard / Good / Easy → 点任一 → 队列推进到下一个词。
4. **队列空**:全部学完后显示空态。
5. **复习到期**:通过 server 日志或改系统时间不可行——用 API 快速验证:
   ```bash
   # 直接调用 review 端点把 dueAt 拉到过去?不。
   # 更简单:重复学习,learning 步骤 1/10 分钟很快就到期,或
   # 用 psql 手动改 due_at 为过去:
   docker exec scenelex-postgres psql -U scenelex -d scenelex -c \
     "UPDATE content.learning_states SET due_at = now() - interval '1 minute' WHERE due_at IS NOT NULL;"
   # 刷新 Review tab → 到期词重新进入队列(状态「复习中」)
   ```
6. **进度/设置**:占位页;设置页可退出登录(清 token → 回登录页)。

## 已知限制(Phase 3)

- 在线模式:所有操作直连 server,无本地缓存/离线。
- 词表「学习」按钮在已添加后显示勾,点击词行只弹状态 SnackBar。
- 评分页不显示下次间隔文案(服务端返回 dueAt 但 UI 未展示)。
- 无每日目标、无统计(Phase 5)。

## 验收清单

- [ ] 邮箱验证码登录成功(含错误码场景:过期/错误码)
- [ ] 词表展示 4 词义,可添加学习
- [ ] Experience Player 完整播放 reluctant-01 的全部阶段
- [ ] 评分后队列推进;全部学完显示空态
- [ ] 到期词(改 due_at 后)重新入队
- [ ] 退出登录回到登录页
