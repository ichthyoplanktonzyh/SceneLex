import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/sync/lww.dart';

LwwMetadata meta(String clientUpdatedAt, String replicaId, String operationId) =>
    LwwMetadata(
      clientUpdatedAt: clientUpdatedAt,
      lastModifiedByReplicaId: replicaId,
      lastOperationId: operationId,
    );

void main() {
  group('compareLww (parity with server lww.rs)', () {
    test('newer timestamp wins', () {
      final older = meta('2026-01-02T00:00:00Z', 'a', 'a');
      final newer = meta('2026-01-03T00:00:00Z', 'a', 'a');
      expect(compareLww(older, newer), -1);
      expect(compareLww(newer, older), 1);
    });

    test('same timestamp: replicaId decides', () {
      final a = meta('2026-01-02T00:00:00Z', '0000000000000001', 'a');
      final b = meta('2026-01-02T00:00:00Z', '0000000000000002', 'a');
      expect(compareLww(a, b), -1);
      expect(compareLww(b, a), 1);
    });

    test('same timestamp and replicaId: operationId decides', () {
      final a = meta('2026-01-02T00:00:00Z', 'r', '0000000000000001');
      final b = meta('2026-01-02T00:00:00Z', 'r', '0000000000000002');
      expect(compareLww(a, b), -1);
      expect(compareLww(b, a), 1);
    });

    test('all three equal compares equal (apply)', () {
      final a = meta('2026-01-02T00:00:00Z', 'r', 'o');
      expect(compareLww(a, a), 0);
      expect(compareLww(a, meta('2026-01-02T00:00:00Z', 'r', 'o')), 0);
    });

    test('missing remote fields sort as minimum (never wins)', () {
      final local = meta('2026-01-02T00:00:00Z', 'r', 'o');
      final missingRemote = LwwMetadata(
        clientUpdatedAt: '',
        lastModifiedByReplicaId: '',
        lastOperationId: '',
      );
      expect(compareLww(local, missingRemote), 1);
      expect(compareLww(missingRemote, local), -1);
    });
  });
}
