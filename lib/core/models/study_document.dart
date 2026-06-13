/// Represents a single study document that has been processed by Klassify.
/// Immutable; use [copyWith] to produce updated copies.
class StudyDocument {
  final String id;
  final String title;
  final DateTime createdAt;
  final String? pdfPath;
  final String? flashcardsPath;
  final String? audioPath;

  const StudyDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    this.pdfPath,
    this.flashcardsPath,
    this.audioPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'pdfPath': pdfPath,
        'flashcardsPath': flashcardsPath,
        'audioPath': audioPath,
      };

  factory StudyDocument.fromJson(Map<String, dynamic> json) {
    return StudyDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pdfPath: json['pdfPath'] as String?,
      flashcardsPath: json['flashcardsPath'] as String?,
      audioPath: json['audioPath'] as String?,
    );
  }

  StudyDocument copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? pdfPath,
    String? flashcardsPath,
    String? audioPath,
    // Pass `audioPath: null` does nothing; use clearAudioPath to explicitly
    // remove the audio reference.
  }) {
    return StudyDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      pdfPath: pdfPath ?? this.pdfPath,
      flashcardsPath: flashcardsPath ?? this.flashcardsPath,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyDocument &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StudyDocument(id: $id, title: $title)';
}
