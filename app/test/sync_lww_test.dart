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

    test('fractional-digit prefix pair compares by instant, not lexically', () {
      // "…789Z" (0/3-digit server form) is EARLIER than "…789012Z" (6-digit),
      // even though 'Z' (0x5A) > '0' (0x30) makes the raw string bigger.
      final shorter = meta('2026-01-02T00:00:00.789Z', 'r', 'o');
      final longer = meta('2026-01-02T00:00:00.789012Z', 'r', 'o');
      expect(compareLww(shorter, longer), -1);
      expect(compareLww(longer, shorter), 1);
    });

    test('same instant with different serialization compares equal', () {
      final withZero = meta('2026-01-02T00:00:00Z', 'r', 'o');
      final withMillis = meta('2026-01-02T00:00:00.000Z', 'r', 'o');
      expect(compareLww(withZero, withMillis), 0);
      // Falls through to the replica/operation tie-breakers.
      final withZeroBigger =
          meta('2026-01-02T00:00:00Z', 'rr', 'o');
      expect(compareLww(withMillis, withZeroBigger), -1);
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

    test('unparseable timestamp sorts as minimum (never wins)', () {
      final local = meta('2026-01-02T00:00:00Z', 'r', 'o');
      final garbage = meta('not-a-timestamp', 'r', 'o');
      expect(compareLww(local, garbage), 1);
      expect(compareLww(garbage, local), -1);
    });
  });
}
