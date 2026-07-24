# reluctant-01 · Token Plan Wan 2.7 状态编辑实验

## 本轮唯一问题

Token Plan 的 `wan2.7-image-pro` 能否通过图片编辑和多图参考，
准确执行 reluctant 场景最困难的四个冻结视觉状态？

## 输入版本（执行时确认）

| 层 | 版本 | 路径 |
|---|---|---|
| Scene | reluctant-01-proto-01 | — |
| Shot Plan | v05 | `data/drafts/shot-plans/reluctant-01-proto-01/v05/` |
| Keyframe Plan | v02 | `data/drafts/keyframe-plans/reluctant-01-proto-01/v02/` |
| Image Keyframes | v01 | `data/drafts/image-keyframes/reluctant-01-proto-01/v01/` |

## Base Commit

`58c958dea90eb0de6b618ab1201b736526b856d8`

## Token Plan Endpoint 状态

### 主 Endpoint（指令规定）

```
https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
```

**结果：SSL_ERROR_SYSCALL（连接被 SSL 握手前强制切断）**

- curl 诊断：Host 解析为 `198.18.1.221`（本地代理/防火墙/WARP 拦截）
- TLS handshake 在 Client Hello 之后、Server Hello 之前被切断
- 重试 3 次（指数退避），每次相同结果
- request_id 为空（未到达服务端）

### DashScope Endpoint（SCENELEX_IMG_ENDPOINT 覆盖验证）

```
https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
```

**结果：HTTP 401 InvalidApiKey**

- SSL 握手成功（TLSv1.3，证书 `*.aliyuncs.com`）
- request_id 正常返回：`ae57fa00-56fc-9695-8b5b-fc922ff07009`
- 结论：网络层通畅；`sk-sp-` 前缀的 Token Plan Key 在 DashScope 域无效（两个域的 Key 不通用）

### 诊断结论

当前运行环境（macOS）的网络代理拦截了 `*.maas.aliyuncs.com` 的 TLS 连接，
但没有拦截 `dashscope.aliyuncs.com`。

Token Plan Key 是 `maas.aliyuncs.com` 专属凭据，不能在 `dashscope.aliyuncs.com` 使用。
两个域对应不同的服务授权体系。

**不切换 Endpoint，不替换 Key（符合指令约束）。**

## api_gate

```
api_gate: blocked
```

**原因类型：** 网络层 SSL 拦截（不是 Token Plan 服务本身拒绝，也不是 Key 格式错误）

**具体原因：**
- `token-plan.cn-beijing.maas.aliyuncs.com` 被当前运行环境的网络代理在 TLS 握手阶段切断
- 未向 Token Plan 服务发出任何有效请求
- 如果在没有此类代理的网络（例如直连中国大陆网络、VPN 转发至大陆出口）中运行，SSL 握手应能成功

## semantic_gate

```
semantic_gate: not_run
```

**原因：** api_gate: blocked，四帧均未生成

## 四张诊断帧

| keyframe_id | 状态 | 原因 |
|---|---|---|
| shot-02-kf-03 | 未生成 | api_gate: blocked |
| shot-02-kf-04 | 未生成 | api_gate: blocked |
| shot-03-kf-01 | 未生成 | api_gate: blocked |
| shot-03-kf-03 | 未生成 | api_gate: blocked |

## 本 PR 实际完成的工作

### 代码

| 文件 | 状态 | 说明 |
|---|---|---|
| `tools/imagegen.py` | 已修改 | 新增 aliyun-token-plan 协议与 `edit()` 函数；ComfyUI 路径不变 |
| `tools/image_keyframe_edit.py` | 新建 | 领域库：compile_edit_instruction, review_html, validate_edit_run, build_edit_run |
| `tools/image_keyframe_edits.py` | 新建 | CLI：smoke / generate / review / validate / show |
| `schema/image-keyframe-edit-run.schema.json` | 新建 | 实验记录 schema |
| `tests/test_image_keyframe_edits.py` | 新建 | 59 个测试全部通过（15.1–15.4） |

### 测试结果

```
pytest tests/test_image_keyframe_edits.py
59 passed in 0.27s
```

所有测试使用 monkeypatch/fake HTTP，无真实网络访问。

### 历史目录保护

- `data/drafts/shot-plans/reluctant-01-proto-01/v05/` — **未变更** ✓
- `data/drafts/keyframe-plans/reluctant-01-proto-01/v02/` — **未变更** ✓
- `data/drafts/image-keyframes/reluctant-01-proto-01/v01/` — **未变更** ✓

## 下一步

若需在有效网络环境中重新运行：

```bash
export SCENELEX_IMG_PROTOCOL=aliyun-token-plan
export SCENELEX_ALIYUN_TOKEN_PLAN_KEY=sk-sp-...
# 不需要 SCENELEX_IMG_ENDPOINT（默认已指向 Token Plan 主 Endpoint）
python3 tools/image_keyframe_edits.py smoke reluctant-01-proto-01 --source-image-version 1 --version 1
# smoke pass 后：
python3 tools/image_keyframe_edits.py generate reluctant-01-proto-01 --source-image-version 1 --version 1
```

## 未回答的问题

**wan2.7-image-pro 能否准确执行 Keyframe Plan v02 中被冻结的状态**（特别是
"手在配合，但躯干仍然后靠"的 reluctant 核心判据）——
**本轮因网络环境未能得到答案。**

代码、schema、测试框架均已就绪，在可连接 Token Plan Endpoint 的网络环境中可立即执行。
