# Holistic vs Legacy 对比报告 — messy-01

> 只展示可核查差异，不自动宣称哪边更好。

## 1. 步骤数量
- Holistic 总计 19 步（learning_flow 13 + review_progression 6）
- Legacy 总计 6 步（units 4 + review_pool 2）

## 2. 任务 / primitive 分布
- Holistic primitives: {'scene_observation': 1, 'evidence_highlight': 1, 'binary_judgment': 2, 'symbol_reveal': 1, 'pronunciation': 1, 'l2_grounding': 3, 'boundary_choice': 2, 'transfer_judgment': 4, 'recall_reveal': 2, 'recall_self_grade': 2}
- Legacy roles: {'anchor': 1, 'variation': 1, 'perturbation': 1, 'transfer': 1}
- Legacy review items: 2

## 3. misconception 分别在哪些步骤处理
- Holistic: {'misc-1': ['s3_dimension', 's8_boundary_dirty'], 'misc-4': ['s4_whole_visible'], 'misc-2': ['s9_transfer_abstract'], 'misc-3': ['s11_transfer_quantity'], 'misc-5': ['s12_transfer_damage']}
- Legacy (hypothesis_target): {'misc-2': ['unit-1'], 'misc-1': ['unit-3']}

## 4. dirty / messy 处理
- Holistic 处理 dirty 侧（misc-1 或 boundary_choice）的步骤数：4（boundary 步骤：['s8_boundary_dirty', 'r3_boundary_dirty']）
- Legacy 以 hypothesis_target=misc-1 处理脏乱混淆的单元数：1

## 5. Symbol Binding 位置
- Holistic: learning_flow 第 4 步（0-based；None=缺失）
- Legacy: units 之后（symbol_binding 区块）

## 6. Boundary
- Holistic boundary_choice 步骤：['s8_boundary_dirty', 'r3_boundary_dirty']
- Legacy：program 内无 boundary（boundary 属独立 package 管线）

## 7. Transfer 策略
- Holistic transfer_judgment 步骤：['s9_transfer_abstract', 's10_transfer_visible', 's11_transfer_quantity', 's12_transfer_damage']
- Legacy role=transfer 单元：['unit-4']

## 8. Review 脚手架递进
- Holistic review_progression: [{'id': 'r1_recall', 'timing': 'next_day', 'scaffold_level': 'early_post_binding', 'primitive': 'recall_reveal'}, {'id': 'r1_selfgrade', 'timing': 'next_day', 'scaffold_level': 'early_post_binding', 'primitive': 'recall_self_grade'}, {'id': 'r2_recall_transfer', 'timing': '3_days_later', 'scaffold_level': 'later_post_binding', 'primitive': 'recall_reveal'}, {'id': 'r2_ground_later', 'timing': '3_days_later', 'scaffold_level': 'later_post_binding', 'primitive': 'l2_grounding'}, {'id': 'r2_selfgrade', 'timing': '3_days_later', 'scaffold_level': 'later_post_binding', 'primitive': 'recall_self_grade'}, {'id': 'r3_boundary_dirty', 'timing': '7_days_later', 'scaffold_level': 'later_post_binding', 'primitive': 'boundary_choice'}]
- Legacy review_pool（无 scaffold_level 字段）: ['review-1', 'review-2']

## 9. LLM 课程设计调用次数
- Holistic 课程级调用（author/critic/repair）：3（全部调用含格式修复：5）
- Legacy request_ids 数量：0
