// lib/models/sun_user.dart

class SunUser {
  final int id;
  final int userNo;
  final String userGroup;
  final String userName;
  final int userBranch;
  final String userType;
  final int userDepartment;
  final String userStatus;
  final String? passwordHash;
  final int? transactionSequence;

  int? boxNo;
  int? noStore;
  int? receiptBoxNo;
  int? paymentBoxNo;

  final String? boxAccountId;
  final String? apiStoreId;

  final String? sourceId;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final String? lastUpdated;

  SunUser({
    required this.id,
    required this.userNo,
    required this.userGroup,
    required this.userName,
    required this.userBranch,
    required this.userType,
    required this.userDepartment,
    required this.userStatus,
    this.passwordHash,
    this.transactionSequence,
    this.boxNo,
    this.noStore,
    this.receiptBoxNo,
    this.paymentBoxNo,
    this.boxAccountId,
    this.apiStoreId,
    this.sourceId,
    this.createdAt,
    this.modifiedAt,
    this.lastUpdated,
  });

  factory SunUser.fromJson(Map<String, dynamic> json) {
    return SunUser(
      id: json['id'] as int? ?? 0,
      userNo: json['user_no'] as int? ?? 0,
      userGroup: json['user_group'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Unknown',
      userBranch: json['user_branch'] as int? ?? 0,
      userType: json['user_type'] as String? ?? 'user',
      userDepartment: json['user_department'] as int? ?? 0,
      userStatus: json['user_status'] as String? ?? 'active',
      passwordHash: json['password_hash'] as String?,
      transactionSequence: json['transaction_sequence'] as int?,
      receiptBoxNo: json['receipt_box_no'] as int?,
      paymentBoxNo: json['payment_box_no'] as int?,
      boxAccountId: json['box_account_id'] as String?,
      apiStoreId: json['store_id'] as String?,
      sourceId: json['source_id']?.toString(),
      createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at']),
      modifiedAt: json['modified_at'] == null ? null : DateTime.tryParse(json['modified_at']),
      lastUpdated: json['last_updated'] as String?,
    );
  }

  factory SunUser.fromMap(Map<String, dynamic> map) {
    return SunUser(
      id: map['id'] as int,
      userNo: map['user_no'] as int,
      userGroup: map['user_group'] as String,
      userName: map['user_name'] as String,
      userBranch: map['user_branch'] as int,
      userType: map['user_type'] as String,
      userDepartment: map['user_department'] as int,
      userStatus: map['user_status'] as String,
      passwordHash: map['password_hash'] as String?,
      transactionSequence: map['transaction_sequence'] as int?,
      boxNo: map['box_no'] as int?,
      noStore: map['no_store'] as int?,
      receiptBoxNo: map['receipt_box_no'] as int?,
      paymentBoxNo: map['payment_box_no'] as int?,
      sourceId: map['source_id'] as String?,
      createdAt: map['created_at'] == null ? null : DateTime.tryParse(map['created_at']),
      modifiedAt: map['modified_at'] == null ? null : DateTime.tryParse(map['modified_at']),
      lastUpdated: map['last_updated'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_no': userNo,
      'user_group': userGroup,
      'user_name': userName,
      'user_branch': userBranch,
      'user_type': userType,
      'user_department': userDepartment,
      'user_status': userStatus,
      'password_hash': passwordHash,
      'transaction_sequence': transactionSequence,
      'box_no': boxNo,
      'no_store': noStore,
      'receipt_box_no': receiptBoxNo,
      'payment_box_no': paymentBoxNo,
      'source_id': sourceId,
      'created_at': createdAt?.toIso8601String(),
      'modified_at': modifiedAt?.toIso8601String(),
      'last_updated': lastUpdated,
    };
  }
}