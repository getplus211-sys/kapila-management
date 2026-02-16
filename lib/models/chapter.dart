class Chapter {
  final String id;
  final String subjectId;
  final String chapterCode;
  final String chapterName;
  final String? chapterNameGujarati;
  final int orderIndex;
  final DateTime? createdAt;

  Chapter({
    required this.id,
    required this.subjectId,
    required this.chapterCode,
    required this.chapterName,
    this.chapterNameGujarati,
    required this.orderIndex,
    this.createdAt,
  });

  // Getter for backward compatibility
  String get name => chapterName;

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      chapterCode: json['chapter_code'] as String,
      chapterName: json['chapter_name'] as String,
      chapterNameGujarati: json['chapter_name_gujarati'] as String?,
      orderIndex: json['order_index'] as int,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'chapter_code': chapterCode,
      'chapter_name': chapterName,
      'chapter_name_gujarati': chapterNameGujarati,
      'order_index': orderIndex,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}