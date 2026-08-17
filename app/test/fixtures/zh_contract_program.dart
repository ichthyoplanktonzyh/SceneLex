/// Shared synthetic Contract v1 program that complies with the Learning
/// Presentation Language Contract v1 (zh-CN → en).
///
/// Used by the acceptance tests: zh-CN Discover (pre-binding), Symbol
/// Binding, Grounding, zh-CN Boundary with L2 options, and zh-CN Early
/// Recall. All pre-binding learner-visible fields are Chinese; the target
/// L2 first appears at symbol_binding; grounding is natural L2.
library;

const String kZhContractProgramSenseId = 'messy-test-01';
const String kZhContractLemma = 'messy';
const String kZhContractIpa = '/ˈmesi/';

/// A Contract v1 program for lemma `messy` whose content complies with the
/// language contract: Chinese pre-binding scenes, L2 first at reveal.
Map<String, Object> zhContractProgramJson() {
  return {
    'schema_version': '1.0',
    'program_id': 'messy-test-01-program',
    'program_version': 1,
    'status': 'reviewed',
    'language_policy': {
      'policy_version': 1,
      'learner_l1': 'zh-CN',
      'target_l2': 'en',
    },
    'target': {
      'sense_id': kZhContractProgramSenseId,
      'lemma': kZhContractLemma,
      'pos': 'adjective',
      'ipa': kZhContractIpa,
      'locale_l1': 'zh',
    },
    'units': [
      _zhUnit(
        id: 'unit-1',
        sequence: 1,
        role: 'anchor',
        hypothesisTarget: null,
        preservedVariables: ['surface', 'location'],
        changedVariables: ['placement', 'orientation'],
        semanticSpec: {
          'judgment': '位置上是否偏离了通常状态',
          'placement': 'displaced',
          'orientation': 'displaced',
        },
        episode: '晚饭后，书桌上的东西都离开了平时的位置：'
            '笔记本斜躺在键盘上，马克杯倒扣在显示器前，'
            '笔撒在桌角，椅垫翻在地上。',
        evidence: const [
          '笔记本斜躺在键盘上，压住了几个按键',
          '马克杯倒扣在显示器前',
          '笔散落在桌角，椅垫翻在地上',
        ],
        dimensions: const [
          {'name': 'placement', 'baseline': '每件物品都在通常位置', 'deviation': '笔记本在键盘上、杯子倒扣、笔在桌角'},
          {'name': 'orientation', 'baseline': '物品正放', 'deviation': '杯子和椅垫都翻着'},
        ],
        question: '这张书桌的状态和平时一样吗？',
        answers: [
          {'id': 'a1', 'text': '不一样，东西都离开了通常位置', 'is_correct': true, 'feedback': '桌子上的物品大多不在原位，位置秩序被破坏了。'},
          {'id': 'a2', 'text': '一样，一切照旧', 'is_correct': false, 'feedback': '物品明显错位了，不是平时的样子。'},
        ],
      ),
      _zhUnit(
        id: 'unit-2',
        sequence: 2,
        role: 'variation',
        hypothesisTarget: null,
        preservedVariables: ['room', 'surface'],
        changedVariables: ['clutter', 'objects'],
        semanticSpec: {
          'judgment': '客厅的正例是否仍然成立',
          'clutter': 'yes',
          'objects': 'scattered',
        },
        episode: '客厅里，积木洒了一地，沙发靠垫从扶手上滑落，'
            '茶几上的遥控器和零食袋混在一起，玩具车停在沙发底下。',
        evidence: const [
          '积木洒了一地，脚印踩过几块',
          '靠垫从扶手上滑落到地面',
          '遥控器被零食袋压住，玩具车在沙发底下',
        ],
        dimensions: const [
          {'name': 'clutter', 'baseline': '物品各归其位', 'deviation': '积木、靠垫、遥控器都离开了位置'},
        ],
        question: '这个客厅的状态，和上一题的书桌是同一类吗？',
        answers: [
          {'id': 'a1', 'text': '是，都是物品错位', 'is_correct': true, 'feedback': '两个场景里物品都离开了通常位置，属于同一类状态。'},
          {'id': 'a2', 'text': '不是，这是别的问题', 'is_correct': false, 'feedback': '这里同样是物品秩序被破坏。'},
        ],
      ),
    ],
    'symbol_binding': {
      'reveal': {
        'l2_word': kZhContractLemma,
        'ipa': kZhContractIpa,
        'presentation': '刚才你看到的书桌和客厅状态，就用这个词来命名：messy。',
      },
      'minimal_l1_gloss': '凌乱',
    },
    'grounding': {
      'source_experience_id': 'unit-1',
      'l2_realization': 'The desk looks messy after dinner.',
      'constructions': ['messy [noun]', 'look messy'],
      'collocations': ['messy room', 'messy desk'],
    },
    'review_pool': [
      {
        'id': 'review-1',
        'semantic_spec': {'judgment': '新的场景是否仍成立'},
        'scaffold_level': 'early_post_binding',
        'experience': {
          'episode': '厨房操作台上，面粉袋敞着口，'
              '碗勺堆在水池边，调味瓶横七竖八地倒在台面上。',
          'observable_evidence': const [
            '面粉袋敞着口，面粉洒在台面一角',
            '碗勺堆在水池边没有归位',
            '调味瓶横七竖八地倒着',
          ],
          'surface_dimensions': const [
            {'name': 'placement', 'baseline': '台面物品摆放整齐', 'deviation': '调味瓶倒着、碗勺堆在水池边'},
          ],
        },
      },
    ],
    'metadata': {
      'compiler_version': '2.1.0',
      'source_contract_hash': 'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      'language_policy': {'policy_version': 1, 'learner_l1': 'zh-CN', 'target_l2': 'en'},
    },
  };
}

Map<String, Object?> _zhUnit({
  required String id,
  required int sequence,
  required String role,
  required String? hypothesisTarget,
  required List<String> preservedVariables,
  required List<String> changedVariables,
  required Map<String, Object> semanticSpec,
  required String episode,
  required List<String> evidence,
  required List<Map<String, String>> dimensions,
  required String question,
  required List<Map<String, Object>> answers,
}) {
  return <String, Object?>{
    'id': id,
    'sequence': sequence,
    'role': role,
    'hypothesis_target': hypothesisTarget,
    'preserved_variables': preservedVariables,
    'changed_variables': changedVariables,
    'semantic_spec': semanticSpec,
    'experience': {
      'episode': episode,
      'observable_evidence': evidence,
      'surface_dimensions': dimensions,
    },
    'interaction': {'question': question, 'answers': answers},
  };
}

/// A Boundary package (dirty ↔ messy) whose content complies with the
/// language contract: Chinese scenes, L2 options only.
Map<String, Object> zhContractBoundaryJson() {
  return {
    'schema_version': '1.0',
    'boundary_id': 'dirty-01__messy-01',
    'sense_a': 'dirty-01',
    'sense_b': 'messy-01',
    'status': 'reviewed',
    'language_policy': {
      'policy_version': 1,
      'learner_l1': 'zh-CN',
      'target_l2': 'en',
    },
    'diagnostic_dimension': {
      'dimension': '状态偏离的来源与需要的处置',
      'sense_a_value': '外来污物附着在表面上，需要清洗',
      'sense_b_value': '物品位置秩序错位，需要整理',
      'description': '沿"偏离来自哪里"对比两个义项。',
    },
    'minimal_pairs': [
      {
        'id': 'pair-1',
        'correct_sense': 'messy-01',
        'experience': {
          'episode': '午休后的办公室：文件散在桌上，'
              '椅子歪在过道里，抽屉半开着，但桌面没有灰尘和污渍。',
          'observable_evidence': const [
            '文件散在桌上，椅子歪在过道里',
            '桌面没有灰尘和污渍',
          ],
          'surface_dimensions': const [
            {'name': 'placement', 'baseline': '物品归位', 'deviation': '文件散着、椅子歪着、抽屉开着'},
          ],
        },
        'interaction': {
          'question': '这个办公室的状态，更符合哪个词？',
          'answers': [
            {'id': 'a1', 'text': 'dirty', 'is_correct': false, 'feedback': '桌面上没有外来污物，不是 dirty。'},
            {'id': 'a2', 'text': 'messy', 'is_correct': true, 'feedback': '物品位置错位而表面干净，是 messy。'},
          ],
        },
        'explanation': {
          'correct': '物品离开了通常位置，但表面没有污物——位置秩序被破坏。',
          'other': '没有污物附着，所以不是表面不洁。',
        },
      },
      {
        'id': 'pair-2',
        'correct_sense': 'dirty-01',
        'experience': {
          'episode': '厨房水槽边：盘子上的油渍和残渣清晰可见，'
              '水龙头把手上沾着酱汁，但碗筷都整齐地码在沥水架上。',
          'observable_evidence': const [
            '盘子上的油渍和残渣清晰可见',
            '水龙头把手上沾着酱汁',
            '碗筷整齐地码在沥水架上',
          ],
          'surface_dimensions': const [
            {'name': 'contamination', 'baseline': '表面洁净', 'deviation': '油渍、残渣、酱汁附着在表面'},
          ],
        },
        'interaction': {
          'question': '这个厨房的状态，更符合哪个词？',
          'answers': [
            {'id': 'a1', 'text': 'dirty', 'is_correct': true, 'feedback': '表面附着着油渍和酱汁，需要清洗。'},
            {'id': 'a2', 'text': 'messy', 'is_correct': false, 'feedback': '物品摆放整齐，没有位置错位。'},
          ],
        },
        'explanation': {
          'correct': '表面附着外来污物，偏离了洁净状态。',
          'other': '物品整齐，没有秩序问题。',
        },
      },
    ],
    'gate': {'passed': true, 'dimensions': []},
    'metadata': {
      'compiler_version': '2.1.0',
      'contract_a_hash': 'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      'contract_b_hash': 'sha256:0000000000000000000000000000000000000000000000000000000000000000',
    },
  };
}
