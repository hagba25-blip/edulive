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

/// Un trait dessiné sur le tableau blanc (une "ligne" de points reliés)
class Stroke {
  final List<Map<String, double>> points; // [{x: .., y: ..}, ...]
  final int colorValue;
  final double width;

  Stroke({required this.points, required this.colorValue, required this.width});

  Map<String, dynamic> toJson() => {
        'points': points,
        'color': colorValue,
        'width': width,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
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

class ChatMessage {
  final String senderId;
  final String content;
  final bool isPrivate;

  ChatMessage({required this.senderId, required this.content, this.isPrivate = false});
}
