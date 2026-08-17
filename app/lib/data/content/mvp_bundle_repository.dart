/// Loads the Teaching Archetype MVP bundle from assets.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../features/archetype_mvp/archetype_mvp_models.dart';

class MvpBundleRepository {
  const MvpBundleRepository();

  static const String assetPath = 'assets/content/archetype-mvp.v1.json';

  Future<MvpBundle> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    return MvpBundle.fromJson((decoded as Map).cast<String, dynamic>());
  }
}
