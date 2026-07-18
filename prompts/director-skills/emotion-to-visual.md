# 情绪 → 可画视觉线索（导演 skill）

**用途**：导演编译关键帧提示词时，把目标词的精确词义（尤其心理/情绪/态度类）翻成**面部 + 肢体 + 视线 + 时序**的具体可画线索，并派生 must-not 边界。这是 SceneLex 语义精确性的落点——通用生成 Agent 在此画偏（把 reluctant 画成 annoyed/energetic），本 skill 靠 FACS + 动画表演体系把它钉准。

依据：FACS 面部动作编码系统（Ekman & Friesen，AU + 强度 A–E）+ 迪士尼动画十二原则（时序/表演）。本 skill 不追求生理精确，追求**可画、可区分、有边界**。

---

## 核心手法

1. **别写情绪名，写动作单元。** 提示词里禁止出现 `reluctant / sad / angry` 这类抽象情绪词——扩散模型对它们的先验很脏。改写成面部 AU 的可见形态 + 肢体姿态。
2. **三线汇聚，不靠单一表情。** 面部（AU）+ 肢体姿态朝向 + 视线落点，三者指向同一状态才算立住；单个表情特写不构成证据（与 scene-strategies 的外化纪律一致）。
3. **must-not 从近义词派生。** 列出 2–3 个最易混的邻词，写出它们**特有**的 AU/姿态，塞进 negative。词义的边界靠"排除邻居"划定。
4. **时序也是线索。** i2v 阶段的运动提示要带速度/迟疑（`slow, delayed, hesitant, foot-dragging`）——很多态度词（reluctant/eager/careless）的差别就在动作快慢与启动延迟。

---

## FACS AU 速查（可画子集）

| AU | 名称 | 可画形态 |
|---|---|---|
| AU1 | 眉内侧上扬 | 眉头内角抬高（担忧/难过起点） |
| AU2 | 眉外侧上扬 | 眉梢抬高（惊讶） |
| AU4 | 眉压低聚拢 | 皱眉、眉间竖纹 |
| AU5 | 上睑上提 | 瞪眼、眼睛睁大 |
| AU6 | 脸颊上提 | 真笑（眼周），Duchenne |
| AU7 | 眼睑收紧 | 眯眼、瞪视（愤怒/专注） |
| AU9 | 皱鼻 | 厌恶 |
| AU10 | 上唇上提 | 轻蔑/厌恶 |
| AU12 | 嘴角上拉 | 微笑 |
| AU14 | 单侧嘴角收紧（酒窝肌） | 轻蔑、不屑、勉强 |
| AU15 | 嘴角下拉 | 撇嘴、不情愿、难过 |
| AU17 | 下巴上抬 | 撅嘴、憋气、忍耐 |
| AU20 | 嘴角平拉 | 恐惧/紧张 |
| AU23/24 | 唇收紧/紧压 | 隐忍、克制、生气忍住 |
| AU25/26 | 唇分开/下颌张开 | 叹气、说话、松口气 |
| AU43 | 闭眼 | 长叹时闭眼、疲惫 |

肢体/视线常用词：`slumped shoulders, body turned away from the task, torso oriented toward the desired object, backward glance, dragging feet, mid-motion frozen, minimal contact (two-finger grip), heavy sigh with closed eyes`。

---

## 方法（四步）

1. **拆词义**：从义项的语义骨架取"成立条件 + 内在张力"（如 reluctant = 有更想做的事 + 被外部要求 + 内心抗拒但仍执行）。
2. **选核心 AU + 姿态**：挑 2–3 个 AU + 1 个身体朝向 + 1 个视线落点，指向该张力。
3. **写成英文可画短语**（塞进关键帧 prompt 的表情/姿态位）。
4. **派生 must-not**：列 2–3 个邻词的特有形态 → negative。

---

## 范例：reluctant（不情愿）

- **面部**：AU15（嘴角下拉）+ AU17（下巴上抬撅嘴）+ 轻 AU4（微皱眉）+ 半闭眼/AU43（叹气瞬间）。
  → `downturned mouth, slight pout, faintly furrowed brow, half-closed eyes, long sigh`
- **肢体**：垮肩、身体朝向背离任务、动作迟缓。
  → `slumped shoulders, body turned away from the chore and toward the game, dragging feet, sluggish mid-motion`
- **视线**：不看任务，回望所欲之物。
  → `not looking at the task, glancing back at the game screen`
- **时序（给 i2v）**：`slow, delayed start, foot-dragging, unwilling`
- **must-not（派生自邻词）**：
  - vs **annoyed/angry**：排除 AU4+5+7 强皱眉瞪眼、前倾逼近 → `no scowl, no glaring, no aggressive forward lean`
  - vs **lazy/bored**：不情愿有"被要求的对象+抗拒"，不是纯瘫散冷漠 → `not limp indifference, not sprawled relaxation`
  - vs **eager/happy**：排除 AU6+12 真笑、直立利落 → `no cheerful smile, no upright energetic posture, no springing up`
  - vs **sad/crying**：排除 AU1+4+15 全难过、流泪 → `no tears, not full sadness`

**整合进关键帧 prompt（示意）**：
`{char:boy}, slumped shoulders, downturned mouth with slight pout, faintly furrowed brow, body turned away from the trash bag and toward the game screen, glancing back at the screen`
`negative: cheerful smile, upright energetic posture, springing up, scowl, glaring, aggressive lean, tears`

---

## 陷阱

- 直接写情绪名（`reluctant`）当提示词；
- 只给面部特写、丢掉肢体朝向与视线（外化不成立）；
- 不写 must-not，导致模型滑向审美先验里最"燃/好看"的邻近情绪；
- 把结果当状态：`reluctant` 不等于"最终去做了"，抗拒才是核心，别用"完成动作"替代抗拒证据。
