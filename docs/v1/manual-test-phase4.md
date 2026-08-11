# Phase 4 手动验证指引(离线优先)

目标:验证离线优先闭环——断网学习(本地 SQLite + outbox)→ 联网自动收敛 → 多端一致。

## 前置

```bash
docker compose -f docker/docker-compose.yml up -d
cargo run -p scenelex-server                # :8081
.venv/bin/python scripts/import_content.py  # 首次
cd app && flutter run -d chrome --web-port 8090
```

## 验证步骤

### 1. 在线建立数据
- 登录 → 词表添加 2-3 个词 → 学习 1 个词(Experience Player 全程 + 评分)。

### 2. 断网学习(核心)
- **停掉 server**(Ctrl-C),不要关 app。
- 在 Review 继续学习其他新词:Experience Player 应正常播放
  (program 已缓存到本地 SQLite)。
- 评分:正常推进队列——FSRS 由 Dart 本地计算(Dart 端口与 Rust core
  黄金向量 15/15 一致)。
- 词表页刷新:仍显示本地状态。
- 本地数据路径:SQLite 文件 `scenelex.db`(macOS 桌面/移动端),web 端 IndexedDB/WASM。

### 3. 联网收敛
- 重启 server(`cargo run -p scenelex-server`)。
- 在 app 中刷新(切换 tab 或重进 Review 页):sync engine 自动跑
  bootstrap→push outbox→pull hot→pull review history。
- 验证 server 收到离线期间的数据:
  ```bash
  docker exec scenelex-postgres psql -U scenelex -d scenelex -c \
    "SELECT count(*) FROM content.review_events;"
  docker exec scenelex-postgres psql -U scenelex -d scenelex -c \
    "SELECT count(*) FROM content.learning_states;"
  ```

### 4. 多端一致
- 用第二个浏览器(或 `curl` 直接调用 `/v1/workspaces/{id}/sync/bootstrap`)
  登录同一账号 → bootstrap 应包含离线期间产生的新 learning_state 和
  review_event(review-history pull 可见)。

### 5. 幂等重放
- 离线学习多个词后联网:server 日志不应有 duplicate-key 错误;
  重复同步(再刷新一次)不应产生新 review_event(幂等台账生效)。

## 验收清单

- [ ] 断网时:添加学习、播放 program、评分全部可用
- [ ] 断网时:FSRS 本地计算结果与在线一致(同一词同一评分 → 相同 dueAt)
- [ ] 联网后:outbox 自动清空(server 数据出现,本地 outbox 表归零)
- [ ] 双端一致:第二个客户端能看到全部数据
- [ ] 重复同步无副作用(幂等)

