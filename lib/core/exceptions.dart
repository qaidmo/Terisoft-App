/// Thrown when a branch cannot be selected because it has no store to post
/// inventory against (no inventory bucket) — a hard block at login time.
class BlockedBranchException implements Exception {
  final String message;
  BlockedBranchException(this.message);

  @override
  String toString() => message;
}

/// Thrown at save time (Layer B guard) when the store on an invoice header does
/// not belong to the active branch. Saving anyway would make the
/// `UPDATE sun_stock` deduction a silent no-op and cause inventory drift.
class StoreBranchMismatchException implements Exception {
  final String message;
  StoreBranchMismatchException(this.message);

  @override
  String toString() => message;
}
