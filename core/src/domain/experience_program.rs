use serde::{Deserialize, Serialize};

/// ExperienceProgram Contract v1 wire shape.
///
/// 与 `schema/experience-program.schema.json` 的 JSON 结构一一对应。这是内容渠道
/// 单向分发的类型；编译由 `tools/experience_compiler.py` 完成，本类型只负责
/// 序列化/反序列化与稳定载体。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ExperienceProgram {
    /// 本契约版本，当前固定为 "1.0"。
    pub schema_version: String,
    /// 稳定程序身份字符串，不要求 UUID。
    pub program_id: String,
    /// 同一 program_id 的编译版本，从 1 开始递增。
    pub program_version: u32,
    pub status: ProgramStatus,
    pub target: ProgramTarget,
    pub semantic_model: SemanticModel,
    /// 有序概念单元。数组顺序与 sequence 都是权威顺序。
    pub units: Vec<ExperienceUnit>,
    /// 独立于概念单元；所有概念单元都必须发生在 symbol_binding 之前。
    pub symbol_binding: SymbolBinding,
    pub grounding: Grounding,
    pub review_pool: Vec<ReviewItem>,
    pub metadata: ProgramMetadata,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProgramStatus {
    Draft,
    Reviewed,
    Published,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProgramTarget {
    /// 编译输入权威 WordSense 的 ID。
    pub sense_id: String,
    pub lemma: String,
    pub pos: String,
    /// 可选 IPA 音标。
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ipa: Option<String>,
    /// 学习者 L1 语言代码，例如 "zh"。
    pub locale_l1: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SemanticModel {
    /// 核心不变式：该经验范畴成立的判定性陈述。
    pub invariant: String,
    pub necessary_conditions: Vec<String>,
    /// 明确不蕴涵的结论。
    pub non_entailments: Vec<String>,
    /// 常见的伴随表现（相关性证据，不升格为必要条件）。
    pub typical_correlates: Vec<String>,
    pub misconceptions: Vec<Misconception>,
    /// L1 经验切割与本词义不一致造成的典型干扰。
    pub l1_interference: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Misconception {
    /// 稳定误解 ID，供 ExperienceUnit.hypothesis_target 引用。
    pub id: String,
    pub description: String,
    pub correction: String,
}

/// 教学 primitive。本契约不规定所有词必须使用完全相同的 role 组合。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UnitRole {
    Anchor,
    Variation,
    Perturbation,
    Discrimination,
    Transfer,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ExperienceUnit {
    pub id: String,
    /// 从 1 开始连续递增，与数组顺序一致。
    pub sequence: u32,
    pub role: UnitRole,
    /// 本单元纠正/反驳的 misconception id；无对应误解时为 None。
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hypothesis_target: Option<String>,
    /// 受控不变的经验变量。
    pub preserved_variables: Vec<String>,
    /// 相对基线单元改变的变量；transfer 至少改变两个表面维度。
    pub changed_variables: Vec<String>,
    /// 模型无关的语义事件规格。
    pub semantic_spec: serde_json::Value,
    pub experience: Experience,
    pub interaction: Interaction,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Experience {
    /// learner-visible 经验叙事：不得出现目标 L2 词、相邻 L2 词、内部 ref、
    /// Compiler 元数据或 sense ID。
    pub episode: String,
    /// 学习者可观察到的证据条目。
    pub observable_evidence: Vec<String>,
    /// 可检查的表面维度及其相对基线的偏离。
    pub surface_dimensions: Vec<SurfaceDimension>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SurfaceDimension {
    pub name: String,
    pub baseline: String,
    pub deviation: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Interaction {
    pub question: String,
    pub answers: Vec<Answer>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Answer {
    /// 稳定 answer ID，供评分与追踪使用。
    pub id: String,
    pub text: String,
    pub is_correct: bool,
    pub feedback: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SymbolBinding {
    pub reveal: Reveal,
    /// 最小 L1 释义，用于确认而不是定义。
    pub minimal_l1_gloss: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Reveal {
    pub l2_word: String,
    pub ipa: String,
    /// 把 L2 声音/字形绑定到已体验经验的教学呈现说明。
    pub presentation: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Grounding {
    /// 引用首学中真实存在的 experience 的 unit id。
    pub source_experience_id: String,
    pub l2_realization: String,
    pub constructions: Vec<String>,
    pub collocations: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReviewItem {
    pub id: String,
    pub semantic_spec: serde_json::Value,
    pub experience: Experience,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProgramMetadata {
    pub compiler_version: String,
    /// 四阶段各自的 prompt 版本。
    pub prompt_versions: PromptVersions,
    /// ISO-8601 UTC 生成时间。
    pub generated_at: String,
    /// 编译所依据的 WordSense semantic_revision。
    pub source_semantic_revision: u32,
    pub model_provider: Option<String>,
    pub model_name: Option<String>,
    /// 可选的各阶段非敏感 request ID（不含认证信息）。
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub request_ids: Vec<String>,
    pub quality_gate: QualityGateResult,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PromptVersions {
    pub semantic_planner: String,
    pub program_planner: String,
    pub surface_generator: String,
    pub quality_gate: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct QualityGateResult {
    pub passed: bool,
    pub dimensions: Vec<QualityDimension>,
    /// 可选维度分数 (0-10)；不是通过门的依据。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub scores: Option<std::collections::BTreeMap<String, f64>>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct QualityDimension {
    pub name: String,
    #[serde(rename = "verdict")]
    pub verdict: QualityVerdict,
    pub note: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QualityVerdict {
    Pass,
    Fail,
    Warn,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_through_json() {
        let program = ExperienceProgram {
            schema_version: "1.0".into(),
            program_id: "test-01-program".into(),
            program_version: 1,
            status: ProgramStatus::Draft,
            target: ProgramTarget {
                sense_id: "test-01".into(),
                lemma: "test".into(),
                pos: "noun".into(),
                ipa: Some("/test/".into()),
                locale_l1: "zh".into(),
            },
            semantic_model: SemanticModel {
                invariant: "invariant".into(),
                necessary_conditions: vec!["condition".into()],
                non_entailments: vec!["not entailed".into()],
                typical_correlates: vec![],
                misconceptions: vec![Misconception {
                    id: "misc-1".into(),
                    description: "d".into(),
                    correction: "c".into(),
                }],
                l1_interference: vec![],
            },
            units: vec![ExperienceUnit {
                id: "unit-1".into(),
                sequence: 1,
                role: UnitRole::Anchor,
                hypothesis_target: None,
                preserved_variables: vec!["scene".into()],
                changed_variables: vec!["willingness".into()],
                semantic_spec: serde_json::json!({"judgment": "judge it"}),
                experience: Experience {
                    episode: "an episode".into(),
                    observable_evidence: vec!["visible sign".into()],
                    surface_dimensions: vec![SurfaceDimension {
                        name: "posture".into(),
                        baseline: "upright".into(),
                        deviation: "turned away".into(),
                    }],
                },
                interaction: Interaction {
                    question: "what happened?".into(),
                    answers: vec![Answer {
                        id: "a1".into(),
                        text: "yes".into(),
                        is_correct: true,
                        feedback: "right".into(),
                    }],
                },
            }],
            symbol_binding: SymbolBinding {
                reveal: Reveal {
                    l2_word: "test".into(),
                    ipa: "/test/".into(),
                    presentation: "present".into(),
                },
                minimal_l1_gloss: "测试".into(),
            },
            grounding: Grounding {
                source_experience_id: "unit-1".into(),
                l2_realization: "It is a test.".into(),
                constructions: vec!["a test".into()],
                collocations: vec!["test run".into()],
            },
            review_pool: vec![ReviewItem {
                id: "review-1".into(),
                semantic_spec: serde_json::json!({"judgment": "judge it again"}),
                experience: Experience {
                    episode: "a new episode".into(),
                    observable_evidence: vec!["another sign".into()],
                    surface_dimensions: vec![SurfaceDimension {
                        name: "posture".into(),
                        baseline: "upright".into(),
                        deviation: "turned away".into(),
                    }],
                },
            }],
            metadata: ProgramMetadata {
                compiler_version: "1.0.0".into(),
                prompt_versions: PromptVersions {
                    semantic_planner: "v1".into(),
                    program_planner: "v1".into(),
                    surface_generator: "v1".into(),
                    quality_gate: "v1".into(),
                },
                generated_at: "2026-01-01T00:00:00Z".into(),
                source_semantic_revision: 1,
                model_provider: Some("fake".into()),
                model_name: Some("fake-model".into()),
                request_ids: vec![],
                quality_gate: QualityGateResult {
                    passed: true,
                    dimensions: vec![QualityDimension {
                        name: "semantic_correctness".into(),
                        verdict: QualityVerdict::Pass,
                        note: "ok".into(),
                    }],
                    scores: None,
                },
            },
        };

        let json = serde_json::to_string(&program).expect("serialize");
        let decoded: ExperienceProgram = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(decoded, program);
        assert_eq!(decoded.schema_version, "1.0");
        assert_eq!(decoded.units[0].role, UnitRole::Anchor);
    }

    #[test]
    fn deserializes_without_scores_for_legacy_revision() {
        // scores 是可选参考信息: 缺失时反序列化必须成功且保持 None;
        // legacy WordSense (无 semantic_revision 概念) 按 revision 1 绑定。
        let json = r#"{
          "schema_version": "1.0",
          "program_id": "legacy-01-program",
          "program_version": 1,
          "status": "draft",
          "target": {"sense_id": "legacy-01", "lemma": "legacy", "pos": "noun",
                     "locale_l1": "zh"},
          "semantic_model": {"invariant": "i", "necessary_conditions": ["c"],
                             "non_entailments": ["n"], "typical_correlates": [],
                             "misconceptions": [{"id": "m-1", "description": "d",
                                                 "correction": "c"}],
                             "l1_interference": []},
          "units": [{
            "id": "unit-1", "sequence": 1, "role": "anchor",
            "hypothesis_target": null, "preserved_variables": ["scene"],
            "changed_variables": ["state"],
            "semantic_spec": {"judgment": "judge it"},
            "experience": {"episode": "an episode", "observable_evidence": ["sign"],
                           "surface_dimensions": [{"name": "state", "baseline": "a",
                                                   "deviation": "b"}]},
            "interaction": {"question": "q", "answers": [{"id": "a1", "text": "t",
                           "is_correct": true, "feedback": "f"}]}
          }],
          "symbol_binding": {"reveal": {"l2_word": "legacy", "ipa": "/l/",
                                        "presentation": "p"},
                             "minimal_l1_gloss": "旧词"},
          "grounding": {"source_experience_id": "unit-1", "l2_realization": "l",
                        "constructions": ["a"], "collocations": ["b"]},
          "review_pool": [{
            "id": "review-1", "semantic_spec": {"judgment": "j"},
            "experience": {"episode": "new", "observable_evidence": ["s"],
                           "surface_dimensions": [{"name": "state", "baseline": "a",
                                                   "deviation": "b"}]}
          }],
          "metadata": {"compiler_version": "1.0.0",
                       "prompt_versions": {"semantic_planner": "v1",
                                           "program_planner": "v1",
                                           "surface_generator": "v1",
                                           "quality_gate": "v1"},
                       "generated_at": "2026-01-01T00:00:00Z",
                       "source_semantic_revision": 1,
                       "model_provider": "fake", "model_name": "fake",
                       "quality_gate": {"passed": true, "dimensions": []}}
        }"#;
        let decoded: ExperienceProgram = serde_json::from_str(json).expect("deserialize");
        assert_eq!(decoded.metadata.source_semantic_revision, 1);
        assert!(decoded.metadata.quality_gate.scores.is_none());
        assert!(decoded.metadata.request_ids.is_empty());

        let reencoded = serde_json::to_string(&decoded).expect("serialize");
        let decoded_again: ExperienceProgram =
            serde_json::from_str(&reencoded).expect("deserialize again");
        assert_eq!(decoded_again, decoded);
        // 关键: 无 scores 时 round-trip 后 scores 仍为 None, 序列化不注入空对象。
        assert!(decoded_again.metadata.quality_gate.scores.is_none());
    }

    #[test]
    fn scores_round_trip_when_present() {
        let program = ExperienceProgram {
            schema_version: "1.0".into(),
            program_id: "scored-01-program".into(),
            program_version: 1,
            status: ProgramStatus::Draft,
            target: ProgramTarget {
                sense_id: "scored-01".into(),
                lemma: "scored".into(),
                pos: "noun".into(),
                ipa: None,
                locale_l1: "zh".into(),
            },
            semantic_model: SemanticModel {
                invariant: "i".into(),
                necessary_conditions: vec!["c".into()],
                non_entailments: vec!["n".into()],
                typical_correlates: vec![],
                misconceptions: vec![Misconception {
                    id: "m-1".into(),
                    description: "d".into(),
                    correction: "c".into(),
                }],
                l1_interference: vec![],
            },
            units: vec![ExperienceUnit {
                id: "unit-1".into(),
                sequence: 1,
                role: UnitRole::Anchor,
                hypothesis_target: None,
                preserved_variables: vec!["scene".into()],
                changed_variables: vec!["state".into()],
                semantic_spec: serde_json::json!({"judgment": "judge it"}),
                experience: Experience {
                    episode: "an episode".into(),
                    observable_evidence: vec!["sign".into()],
                    surface_dimensions: vec![SurfaceDimension {
                        name: "state".into(),
                        baseline: "a".into(),
                        deviation: "b".into(),
                    }],
                },
                interaction: Interaction {
                    question: "q".into(),
                    answers: vec![Answer {
                        id: "a1".into(),
                        text: "t".into(),
                        is_correct: true,
                        feedback: "f".into(),
                    }],
                },
            }],
            symbol_binding: SymbolBinding {
                reveal: Reveal {
                    l2_word: "scored".into(),
                    ipa: "/s/".into(),
                    presentation: "p".into(),
                },
                minimal_l1_gloss: "得分".into(),
            },
            grounding: Grounding {
                source_experience_id: "unit-1".into(),
                l2_realization: "l".into(),
                constructions: vec!["a".into()],
                collocations: vec!["b".into()],
            },
            review_pool: vec![],
            metadata: ProgramMetadata {
                compiler_version: "1.0.0".into(),
                prompt_versions: PromptVersions {
                    semantic_planner: "v1".into(),
                    program_planner: "v1".into(),
                    surface_generator: "v1".into(),
                    quality_gate: "v1".into(),
                },
                generated_at: "2026-01-01T00:00:00Z".into(),
                source_semantic_revision: 1,
                model_provider: Some("fake".into()),
                model_name: Some("fake".into()),
                request_ids: vec![],
                quality_gate: QualityGateResult {
                    passed: true,
                    dimensions: vec![QualityDimension {
                        name: "semantic_correctness".into(),
                        verdict: QualityVerdict::Pass,
                        note: "ok".into(),
                    }],
                    scores: Some(std::collections::BTreeMap::from([(
                        "semantic_correctness".to_string(),
                        9.0,
                    )])),
                },
            },
        };
        let json = serde_json::to_string(&program).expect("serialize");
        assert!(json.contains("\"scores\""));
        let decoded: ExperienceProgram = serde_json::from_str(&json).expect("deserialize");
        let scores = decoded
            .metadata
            .quality_gate
            .scores
            .expect("scores present");
        assert!((scores["semantic_correctness"] - 9.0).abs() < 1e-9);
    }
}
