# Web 集成测试（实机检查点）基建

本文件记录如何在 SceneLex 里做 **真实浏览器 + 真实本地 server** 的集成
验证（“实机检查点”），包括基建、用法、踩坑与扩展方法。
来源：P0-2 C 段交付时为四个手工检查点（断网自动同步 / resume 立即同步 /
rejected 中止 / 登出后 refresh 401）建立的方案，2026-08 实跑通过。

## 为什么需要这套东西

- Flutter 官方 web 集成测试路径（`flutter drive -d chrome` + chromedriver +
  dwds）在本机 Chrome 151 上不稳定：dwds 与 Chrome 的调试握手会间歇性失败
  （`AppConnectionException` / `Connection reset by peer`），重试不保证成功。
- 绕开方式：**`flutter drive -d web-server`**（只编译 + 起 dev server，不起
  Chrome、不连 chromedriver），然后用**普通 Chrome 打开页面**。页面里的测试
  自行跑完，结果由 flutter drive 收集。此路径稳定。
- 两个附带难点：
  1. **OTP 验证码无法预知**：UI 里点 “Send code” 会创建新挑战，bash 预抓的
     旧码立即失效（verify 取最新挑战）。解法：code relay（见下）。
  2. **文本 finder 依赖语言**：app 默认跟随系统语言（本机 zh），集成测试的
     文案 finder 会失配。解法：测试里 override locale 为 en。

## 文件清单

| 文件 | 作用 |
| --- | --- |
| `app/integration_test/sync_flow_test.dart` | 4 个检查点本体，`CHECKPOINT=1..4` 各自独立登录运行 |
| `app/test_driver/integration_test.dart` | flutter drive 标准 driver（截图落盘用） |
| `scripts/code-relay.py` | 127.0.0.1:9001 小服务：`GET /request-code?email=` 触发 send-code 并从 server log 抓最新码返回；`GET /log?msg=` 供测试上报进度。**安全守卫**：目标 server（`RELAY_BASE`，默认 `http://127.0.0.1:8081/v1`）必须解析到 loopback（127.0.0.1 / localhost / ::1），否则拒绝启动并报错——因为该服务把 OTP 明文（登录凭证）通过 HTTP 吐给测试页面，**只允许钉死在本地开发**，绝不能指向远程环境 |
| `scripts/run-checkpoints.sh` | 编排：起 relay → 生成新邮箱 → `flutter drive -d web-server` → 等 dev server 就绪 → `open` Chrome 打开页面 → 收结果 |

## 怎么跑

前置：本地 server 在 `:8081`（含内容数据，见 `scripts/import_content.py`）。

```bash
# 单个检查点
bash scripts/run-checkpoints.sh 1        # 或 2 / 3 / 4
# 全部四个（每个独立新邮箱，总耗时约 4-6 分钟）
bash scripts/run-checkpoints.sh all
```

脚本输出 `checkpoint N: PASS/FAIL` 与 `=== pass=… fail=… ===`。失败详情在
`/tmp/cpN.log`（flutter drive 原始输出，含 failureDetails JSON）。

首次运行会弹 Chrome 窗口（正常，测试在页面里自动执行）。

## 检查点与断言

1. **断网评分 → 恢复 → 60s 内自动同步**：真实 UI 添加词 + 评分（outbox 产生
   操作）→ 把 `ApiClient.baseUrl` 指向死端口模拟断网 → 断言 sync 状态 offline
   → 恢复 → 断言 60s 内回到 synced 且 outbox 清空。
2. **切后台再回前台立即同步**：按合法 lifecycle 链模拟
   `inactive→hidden→paused→hidden→inactive→resumed`（跳级会触发
   AppLifecycleListener 断言）→ 断言 resume 后数秒内出现 syncing 周期。
3. **rejected 中止整轮**：往 drift outbox 表注入缺 LWW 字段的坏操作 → 触发
   sync → 断言 offline、hot cursor 未推进、坏操作留在 outbox 且标记失败。
4. **登出后旧 refreshToken 401**：真实 UI 登出 → 用旧 refreshToken 请求
   `/auth/refresh-token` → 断言 401 `REFRESH_TOKEN_FAILED`。

## 关键实现细节

- **测试用独立 `ProviderContainer`** + `UncontrolledProviderScope` 挂真实
  app（`SceneLexApp`），override `apiClientProvider`（拿到 client 实例以便
  切 baseUrl 模拟断网）与 locale（固定 en）。
- **login 流程**：UI 填邮箱 → 点 Send code → 等 Sign in 出现 → 请求
  code relay 拿最新验证码 → 填码登录 → 等 `authControllerProvider` signedIn
  → 等库 hydration。
- **hydration 兜底**：登录后 `libraryProvider` 首次结果可能与 hydration
  竞态（缓存空结果）。`_waitHydrated` 先手动 `ApiClient.get('/content/senses')`
  写入 drift 缓存（真实路径），再 `invalidate(libraryProvider)` 重读。
- **不要手动 `container.dispose()`**：sync 触发是 fire-and-forget，周期在
  dispose 后完成会写已销毁的 provider（UnmountedRefException）。进程退出
  自行回收。

## 踩坑记录（按时间序）

1. `flutter test -d chrome` 不支持 web 集成测试 → 必须 flutter drive。
2. chromedriver cask 安装可能只有 LICENSE/NOTICES 缺二进制；且 macOS
   Gatekeeper 会拦截（`xattr -d com.apple.quarantine` 解除）。
3. flutter drive + chromedriver 路径的 dwds 握手不稳定（见上）→ web-server
   模式。
4. 每次 flutter drive 全新 Chrome profile（localStorage 空）→ 检查点必须
   各自登录，不能共享 session。
5. app 跟随系统语言（zh）→ override locale 为 en。
6. OTP 挑战被 UI 重发作废 → code relay 在点击后取码。
7. lifecycle 模拟必须走合法迁移链（`AppLifecycleListener` 断言相邻迁移）。
8. **真实产品 bug（本方案逼出）**：`experience_player.dart` 的 `dispose()`
   读 `ref`（riverpod 禁止），树卸载时崩溃 → 改为 initState 缓存字段。
9. 遗留观察：`local_repository.dart` 的 `setHotCursor` 无条件写
   `hasHydratedHotState: true`（疑似产品缺陷，未验证根因，暂不影响行为）。

## 扩展新检查点

1. 在 `sync_flow_test.dart` 增加 `case N:` 分支（switch 在 `main()` 内），
   复用 `_boot/_signIn/_waitFor/_report` 等 helper。
2. 需要新服务端动作时，`_report('name', ...)` 把进度/断言 POST 到
   code relay（GET 简单请求，避免 CORS 预检），bash 侧
   `grep "TEST-LOG" /tmp/code-relay.log` 取证。
3. 保持每个检查点自包含（新邮箱、独立登录、独立断言）。
