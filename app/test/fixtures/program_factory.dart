/// Shared synthetic Contract v1 program factory for tests.
library;

Map<String, Object> programJsonWithUnitCount(int count) {
  final answers = [
    {
      'id': 'a1',
      'text': 'correct answer',
      'is_correct': true,
      'feedback': 'correct feedback',
    },
    {
      'id': 'a2',
      'text': 'wrong answer',
      'is_correct': false,
      'feedback': 'wrong feedback',
    },
  ];
  return {
    'schema_version': '1.0',
    'program_id': 'synthetic-program',
    'program_version': 1,
    'status': 'reviewed',
    'target': {
      'sense_id': 'synthetic-01',
      'lemma': 'synthetic',
      'pos': 'noun',
      'ipa': 'sɪnˈθetɪk',
      'locale_l1': 'zh',
    },
    'units': List.generate(
      count,
      (i) => {
        'id': 'unit-${i + 1}',
        'sequence': i + 1,
        'role': 'variation',
        'experience': {
          'episode': 'episode $i',
          'observable_evidence': ['evidence $i'],
          'surface_dimensions': [
            {'name': 'd$i', 'baseline': 'b', 'deviation': 'd'},
          ],
        },
        'interaction': {'question': 'question $i', 'answers': answers},
      },
    ),
    'symbol_binding': {
      'reveal': {
        'l2_word': 'synthetic',
        'ipa': 'sɪnˈθetɪk',
        'presentation': 'presentation text',
      },
      'minimal_l1_gloss': '合成的',
    },
    'grounding': {
      'source_experience_id': 'unit-1',
      'l2_realization': 'a synthetic sentence',
      'constructions': ['synthetic [noun]'],
      'collocations': ['synthetic example'],
    },
    'review_pool': [],
    'metadata': {'compiler_version': '1.0.0'},
  };
}
