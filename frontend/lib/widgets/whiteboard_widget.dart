import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/room_socket_service.dart';

class WhiteboardWidget extends StatefulWidget {
  final RoomSocketService socket;
  final bool canDraw; // true pour l'enseignant, ou l'élève autorisé à parler/écrire
  const WhiteboardWidget({super.key, required this.socket, this.canDraw = true});

  @override
  State<WhiteboardWidget> createState() => WhiteboardWidgetState();
}

class WhiteboardWidgetState extends State<WhiteboardWidget> {
  final List<Stroke> _strokes = [];
  List<Map<String, double>> _currentPoints = [];
  Color _color = Colors.black;
  double _strokeWidth = 3;

  void receiveStroke(Stroke stroke) {
    setState(() => _strokes.add(stroke));
  }

  void receiveSync(List<Stroke> strokes) {
    setState(() {
      _strokes.clear();
      _strokes.addAll(strokes);
    });
  }

  void clearAll() {
    setState(() => _strokes.clear());
  }

  void _onPanStart(DragStartDetails d) {
    if (!widget.canDraw) return;
    _currentPoints = [
      {'x': d.localPosition.dx, 'y': d.localPosition.dy}
    ];
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.canDraw) return;
    setState(() {
      _currentPoints = [
        ..._currentPoints,
        {'x': d.localPosition.dx, 'y': d.localPosition.dy}
      ];
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (!widget.canDraw || _currentPoints.isEmpty) return;
    final stroke = Stroke(points: _currentPoints, colorValue: _color.value, width: _strokeWidth);
    setState(() => _strokes.add(stroke));
    widget.socket.sendStroke(stroke.toJson());
    _currentPoints = [];
  }

  void _pickColor(Color c) => setState(() => _color = c);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.canDraw)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                for (final c in [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => _pickColor(c),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: c,
                        child: _color == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 12,
                    value: _strokeWidth,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Effacer le tableau',
                  onPressed: () {
                    clearAll();
                    widget.socket.clearWhiteboard();
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: ClipRect(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                painter: _WhiteboardPainter(
                  strokes: _strokes,
                  liveStroke: _currentPoints,
                  liveColor: _color,
                  liveWidth: _strokeWidth,
                ),
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Map<String, double>> liveStroke;
  final Color liveColor;
  final double liveWidth;

  _WhiteboardPainter({
    required this.strokes,
    required this.liveStroke,
    required this.liveColor,
    required this.liveWidth,
  });

  void _drawStroke(Canvas canvas, List<Map<String, double>> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(
        Offset(points[i]['x']!, points[i]['y']!),
        Offset(points[i + 1]['x']!, points[i + 1]['y']!),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round;
      _drawStroke(canvas, stroke.points, paint);
    }
    if (liveStroke.isNotEmpty) {
      final paint = Paint()
        ..color = liveColor
        ..strokeWidth = liveWidth
        ..strokeCap = StrokeCap.round;
      _drawStroke(canvas, liveStroke, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}
