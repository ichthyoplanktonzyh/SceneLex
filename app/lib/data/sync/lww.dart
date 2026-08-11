/// Last-write-wins metadata for synced entities, compared field by field in
/// exactly the same order as the backend `server/src/sync/lww.rs` (and the
/// reference iOS `SyncApplier.compareLwwTuple`):
///   1. clientUpdatedAt  (ISO-8601; lexicographic order == chronological)
///   2. lastModifiedByReplicaId  (hex UUID; String.compareTo == byte order)
///   3. lastOperationId  (hex UUID)
/// Missing fields are treated as the minimum (empty string sorts before any
/// real value), so a remote payload without clientUpdatedAt never wins.
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
  final timestampComparison = left.clientUpdatedAt.compareTo(right.clientUpdatedAt);
  if (timestampComparison != 0) return timestampComparison < 0 ? -1 : 1;

  final replicaComparison = left.lastModifiedByReplicaId.compareTo(right.lastModifiedByReplicaId);
  if (replicaComparison != 0) return replicaComparison < 0 ? -1 : 1;

  final operationComparison = left.lastOperationId.compareTo(right.lastOperationId);
  if (operationComparison != 0) return operationComparison < 0 ? -1 : 1;

  return 0;
}
