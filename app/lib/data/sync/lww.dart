/// Last-write-wins metadata for synced entities, compared field by field in
/// the same semantic order as the backend `server/src/sync/lww.rs` (and the
/// reference iOS `SyncApplier.compareLwwTuple`):
///   1. clientUpdatedAt — compared as a point in time. The raw strings are
///      NOT compared lexicographically: the backend serializes timestamptz
///      with 0/3/6/9 fractional digits while Dart's toIso8601String() emits
///      3 or 6, and a prefix pair ("…56.789Z" vs "…56.789012Z") would compare
///      the wrong way ('Z' > '0'). Parse to DateTime (UTC) and compare the
///      instant instead; unparseable or missing values sort as the minimum,
///      so they never win against any real local row.
///   2. lastModifiedByReplicaId  (hex UUID; String.compareTo == byte order)
///   3. lastOperationId  (hex UUID)
library;

class LwwMetadata {
  const LwwMetadata({
    required this.clientUpdatedAt,
    required this.lastModifiedByReplicaId,
    required this.lastOperationId,
  });

  final String clientUpdatedAt;
  final String lastModifiedByReplicaId;
  final String lastOperationId;
}

/// -1 when [left] sorts before [right], 1 when after, 0 when equal.
int compareLww(LwwMetadata left, LwwMetadata right) {
  final timestampComparison = _compareInstants(
    left.clientUpdatedAt,
    right.clientUpdatedAt,
  );
  if (timestampComparison != 0) return timestampComparison < 0 ? -1 : 1;

  final replicaComparison = left.lastModifiedByReplicaId.compareTo(
    right.lastModifiedByReplicaId,
  );
  if (replicaComparison != 0) return replicaComparison < 0 ? -1 : 1;

  final operationComparison = left.lastOperationId.compareTo(
    right.lastOperationId,
  );
  if (operationComparison != 0) return operationComparison < 0 ? -1 : 1;

  return 0;
}

int _compareInstants(String left, String right) {
  final leftInstant = _parseInstant(left);
  final rightInstant = _parseInstant(right);
  if (leftInstant == null && rightInstant == null) return 0;
  if (leftInstant == null) return -1;
  if (rightInstant == null) return 1;
  return leftInstant.compareTo(rightInstant);
}

DateTime? _parseInstant(String raw) => DateTime.tryParse(raw)?.toUtc();
