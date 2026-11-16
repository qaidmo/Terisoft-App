class SunPump {
  final String mNo;
  final String mName;
  final double mRight;
  final String? dateMRight;

  SunPump({
    required this.mNo,
    required this.mName,
    required this.mRight,
    this.dateMRight,
  });

  factory SunPump.fromJson(Map<String, dynamic> json) {
    return SunPump(
      mNo: json['mNo']?.toString() ?? json['m_no']?.toString() ?? '',
      mName: json['mName']?.toString() ?? json['m_name']?.toString() ?? '',
      mRight: double.tryParse(json['mRight']?.toString() ?? json['m_right']?.toString() ?? '0') ?? 0.0,
      dateMRight: json['dateMRight']?.toString() ?? json['date_m_right']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'm_no': mNo,
      'm_name': mName,
      'm_right': mRight,
      'date_m_right': dateMRight,
    };
  }
}
