//! Last-writer-wins conflict resolution, mirroring the reference
//! three-field tuple: (clientUpdatedAt, lastModifiedByReplicaId, lastOperationId),
//! compared in order, larger wins.

use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq)]
pub struct LwwMetadata {
    pub client_updated_at: DateTime<Utc>,
    pub last_modified_by_replica_id: Uuid,
    pub last_operation_id: Uuid,
}

/// Does `incoming` beat `current`? Returns true when there is no current row.
pub fn incoming_lww_wins(incoming: &LwwMetadata, current: Option<&LwwMetadata>) -> bool {
    let Some(current) = current else {
        return true;
    };

    if incoming.client_updated_at != current.client_updated_at {
        return incoming.client_updated_at > current.client_updated_at;
    }
    if incoming.last_modified_by_replica_id != current.last_modified_by_replica_id {
        // UUID bytes compare in the same order as their hex string form.
        return incoming.last_modified_by_replica_id.as_bytes()
            > current.last_modified_by_replica_id.as_bytes();
    }
    incoming.last_operation_id.as_bytes() > current.last_operation_id.as_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn meta(at: &str, replica: u128, op: u128) -> LwwMetadata {
        LwwMetadata {
            client_updated_at: chrono::NaiveDateTime::parse_from_str(
                at, "%Y-%m-%dT%H:%M:%SZ",
            )
            .map(|naive| naive.and_utc())
            .unwrap(),
            last_modified_by_replica_id: Uuid::from_u128(replica),
            last_operation_id: Uuid::from_u128(op),
        }
    }

    #[test]
    fn newer_timestamp_wins() {
        let a = meta("2026-01-02T00:00:00Z", 1, 1);
        let b = meta("2026-01-03T00:00:00Z", 1, 1);
        assert!(!incoming_lww_wins(&a, Some(&b)));
        assert!(incoming_lww_wins(&b, Some(&a)));
    }

    #[test]
    fn same_timestamp_replica_wins() {
        let a = meta("2026-01-02T00:00:00Z", 100, 1);
        let b = meta("2026-01-02T00:00:00Z", 200, 1);
        assert!(incoming_lww_wins(&b, Some(&a)));
        assert!(!incoming_lww_wins(&a, Some(&b)));
    }

    #[test]
    fn empty_current_always_wins() {
        let a = meta("2026-01-02T00:00:00Z", 1, 1);
        assert!(incoming_lww_wins(&a, None));
    }
}
