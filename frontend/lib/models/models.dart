class User {
  final String id;
  final String email;
  final String fullName;
  final String role; // "teacher" | "student"
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['email'],
        fullName: json['full_name'],
        role: json['role'],
        avatarUrl: json['avatar_url'],
      );

  bool get isTeacher => role == 'teacher';
}

class SchoolClass {
  final String id;
  final String name;
  final String subject;
  final String teacherId;
  final String inviteCode;

  SchoolClass({
    required this.id,
    required this.name,
    required this.subject,
    required this.teacherId,
    required this.inviteCode,
  });

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
        id: json['id'],
        name: json['name'],
        subject: json['subject'],
        teacherId: json['teacher_id'],
        inviteCode: json['invite_code'],
      );
}

class CourseSession {
  final String id;
  final String classId;
  final String title;
  final String status; // scheduled | live | ended

  CourseSession({
    required this.id,
    required this.classId,
    required this.title,
    required this.status,
  });

  factory CourseSession.fromJson(Map<String, dynamic> json) => CourseSession(
        id: json['id'],
        classId: json['class_id'],
        title: json['title'],
        status: json['status'],
      );
}

/// Élément générique du tableau blanc : trait libre, texte, ou forme géométrique.
abstract class BoardElement {
  final String id;
  BoardElement(this.id);

  Map<String, dynamic> toJson();

  static BoardElement fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'text':
        return TextBoardElement.fromJson(json);
      case 'shape':
        return ShapeBoardElement.fromJson(json);
      default:
        return FreehandBoardElement.fromJson(json);
    }
  }
}

/// Un trait dessiné à main levée (une ligne de points reliés).
class FreehandBoardElement extends BoardElement {
  final List<Map<String, double>> points;
  final int colorValue;
  final double width;

  FreehandBoardElement({
    required String id,
    required this.points,
    required this.colorValue,
    required this.width,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': 'freehand',
        'points': points,
        'color': colorValue,
        'width': width,
      };

  factory FreehandBoardElement.fromJson(Map<String, dynamic> json) => FreehandBoardElement(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        points: (json['points'] as List)
            .map<Map<String, double>>((p) => {
                  'x': (p['x'] as num).toDouble(),
                  'y': (p['y'] as num).toDouble(),
                })
            .toList(),
        colorValue: json['color'],
        width: (json['width'] as num).toDouble(),
      );
}

/// Un texte (normal ou avec symboles mathématiques) placé sur le tableau.
class TextBoardElement extends BoardElement {
  final double x;
  final double y;
  final String text;
  final int colorValue;
  final double fontSize;

  TextBoardElement({
    required String id,
    required this.x,
    required this.y,
    required this.text,
    required this.colorValue,
    required this.fontSize,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': 'text',
        'x': x,
        'y': y,
        'text': text,
        'color': colorValue,
        'fontSize': fontSize,
      };

  factory TextBoardElement.fromJson(Map<String, dynamic> json) => TextBoardElement(
        id: json['id'].toString(),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        text: json['text'],
        colorValue: json['color'],
        fontSize: (json['fontSize'] as num).toDouble(),
      );
}

enum BoardShapeType { line, rectangle, circle, triangle }

/// Une forme géométrique (ligne, rectangle, cercle, triangle) tracée entre deux points.
class ShapeBoardElement extends BoardElement {
  final BoardShapeType shapeType;
  final double x1, y1, x2, y2;
  final int colorValue;
  final double strokeWidth;

  ShapeBoardElement({
    required String id,
    required this.shapeType,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.colorValue,
    required this.strokeWidth,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': 'shape',
        'shapeType': shapeType.name,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'color': colorValue,
        'width': strokeWidth,
      };

  factory ShapeBoardElement.fromJson(Map<String, dynamic> json) => ShapeBoardElement(
        id: json['id'].toString(),
        shapeType: BoardShapeType.values.firstWhere(
          (t) => t.name == json['shapeType'],
          orElse: () => BoardShapeType.line,
        ),
        x1: (json['x1'] as num).toDouble(),
        y1: (json['y1'] as num).toDouble(),
        x2: (json['x2'] as num).toDouble(),
        y2: (json['y2'] as num).toDouble(),
        colorValue: json['color'],
        strokeWidth: (json['width'] as num).toDouble(),
      );
}

class ChatMessage {
  final String senderId;
  final String content;
  final bool isPrivate;

  ChatMessage({required this.senderId, required this.content, this.isPrivate = false});
}