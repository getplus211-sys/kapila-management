class Chapter {
  final String id;
  final String subjectId;
  final String name;
  final String chapterCode;
  final DateTime? createdAt;

  Chapter({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.chapterCode,
    this.createdAt,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      name: json['name'] as String,
      chapterCode: json['chapter_code'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'name': name,
      'chapter_code': chapterCode,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}