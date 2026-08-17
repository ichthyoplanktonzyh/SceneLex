/// object_inspection renderer — 2D object cards with feature hotspots and
/// variant switching. Object names can be hidden pre-binding
/// (hide_object_names); classification happens in a later step — this
/// renderer only presents the Author's inspection content.
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_models.dart';
import 'holistic_step_chrome.dart';

class ObjectInspectionRenderer extends StatefulWidget {
  const ObjectInspectionRenderer({super.key, required this.step});

  final HolisticStep step;

  @override
  State<ObjectInspectionRenderer> createState() => _ObjectInspectionState();
}

class _ObjectInspectionState extends State<ObjectInspectionRenderer> {
  int _objectIndex = 0;
  int _variantIndex = -1; // -1 = 未选变体（显示对象基础特征）
  String? _highlightedFeature;

  @override
  Widget build(BuildContext context) {
    final content = widget.step.content;
    final prompt = content['inspect_prompt'] as String? ?? '';
    final hideNames = content['hide_object_names'] == true;
    final objects = [
      for (final o in (content['objects'] as List?) ?? const [])
        if (o is Map) o.cast<String, dynamic>(),
    ];
    if (objects.isEmpty) {
      return const HolisticStepScroll(children: [HolisticNote('（课程内容缺少对象）')]);
    }
    final object = objects[_objectIndex.clamp(0, objects.length - 1)];
    final variants = [
      for (final v in (object['variants'] as List?) ?? const [])
        if (v is Map) v.cast<String, dynamic>(),
    ];
    final variant = _variantIndex >= 0 && _variantIndex < variants.length
        ? variants[_variantIndex]
        : null;
    final featureList = variant?['features'] ?? object['features'];
    final features = [
      for (final f in (featureList as List? ?? const [])) f as String,
    ];
    final displayName = hideNames
        ? '对象 ${_objectIndex + 1}'
        : (object['name'] as String? ?? '对象 ${_objectIndex + 1}');

    return HolisticStepScroll(
      children: [
        if (prompt.isNotEmpty) HolisticNote(prompt),
        const SizedBox(height: 14),
        // 2D object placeholder card (no image generation / 3D).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kColorDusk.withValues(alpha: 0.10),
                kColorEmber.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kColorDusk.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hideNames ? Icons.help_outline : Icons.category_outlined,
                size: 44,
                color: kColorDusk.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                ),
              ),
              if (hideNames)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '名称先隐藏，观察特征后再判断',
                    style: TextStyle(fontSize: 12, color: Color(0xFF84848F)),
                  ),
                ),
            ],
          ),
        ),
        if (objects.length > 1) ...[
          const SizedBox(height: 14),
          const HolisticLabel('对象'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, obj) in objects.indexed)
                ChoiceChip(
                  key: ValueKey('object-chip-$i'),
                  label: Text(
                    hideNames
                        ? '对象 ${i + 1}'
                        : (obj['name'] as String? ?? '对象 ${i + 1}'),
                  ),
                  selected: i == _objectIndex,
                  onSelected: (_) => setState(() {
                    _objectIndex = i;
                    _variantIndex = 0;
                    _highlightedFeature = null;
                  }),
                ),
            ],
          ),
        ],
        if (variants.isNotEmpty) ...[
          const SizedBox(height: 14),
          const HolisticLabel('变体'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, v) in variants.indexed)
                ChoiceChip(
                  key: ValueKey('variant-chip-$i'),
                  label: Text(v['label'] as String? ?? '变体 ${i + 1}'),
                  selected: i == _variantIndex,
                  onSelected: (_) => setState(() {
                    _variantIndex = i;
                    _highlightedFeature = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const HolisticLabel('特征（点击查看）'),
        const SizedBox(height: 8),
        for (final (i, feature) in features.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              key: ValueKey('feature-$i'),
              color: _highlightedFeature == feature
                  ? kColorEmber.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _highlightedFeature == feature
                      ? kColorEmber
                      : const Color(0xFFE2E2EA),
                ),
              ),
              child: InkWell(
                onTap: () => setState(() {
                  _highlightedFeature = _highlightedFeature == feature
                      ? null
                      : feature;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _highlightedFeature == feature
                            ? Icons.touch_app
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: _highlightedFeature == feature
                            ? kColorEmber
                            : const Color(0xFF9A9AA5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.5,
                            color: kColorInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
