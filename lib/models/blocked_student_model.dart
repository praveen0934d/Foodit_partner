class BlockedStudent {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentPhone;
  final String? profilePhoto;
  final String? reason;
  final DateTime createdAt;

  BlockedStudent({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentPhone,
    this.profilePhoto,
    this.reason,
    required this.createdAt,
  });

  factory BlockedStudent.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>? ?? {};
    return BlockedStudent(
      id: json['id'] ?? '',
      studentId: student['id'] ?? '',
      studentName: student['name'] ?? 'Unknown Student',
      studentPhone: student['phone'],
      profilePhoto: student['profile_photo'],
      reason: json['reason'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
