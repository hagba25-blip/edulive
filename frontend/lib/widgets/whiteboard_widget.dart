import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/room_socket_service.dart';

enum BoardTool { pen, text, shape, eraser }

class WhiteboardWidget extends StatefulWidget {
  final RoomSocketService socket;
  final bool canDraw; // true pour l'enseignant, ou l'élève autorisé à parler/écrire
  const WhiteboardWidget({super.key, required this.socket, this.canDraw = true});

  @override
  State<WhiteboardWidget> createState() => WhiteboardWidgetState();
}

class WhiteboardWidgetState extends State<WhiteboardWidget> {
  final List<BoardElement> _elements = [];
  List<Map<String, double>> _currentPoints = [];
  Offset? _shapeStart;
  Offset? _shapeLive;

  BoardTool _tool = BoardTool.pen;
  BoardShapeType _shapeType = BoardShapeType.line;
  Color _color = Colors.black;
  double _strokeWidth = 3;

  static const List<Color> _palette = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
  ];

  // Symboles rapides pour le "clavier mathématique"
  static const List<String> _mathSymbols = [
    '+', '−', '×', '÷', '=', '≠', '≤', '≥', '±',
    '√', 'π', 'Δ', '∞', '°', '²', '³', '½',
    '→', '∑', '∫', 'α', 'β', 'θ', '(', ')',
  ];

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}';

  // ---------- SYNCHRONISATION TEMPS RÉEL ----------
  void receiveSync(List<BoardElement> elements) {
    setState(() {
      _elements.clear();
      _elements.addAll(elements);
    });
  }

  void receiveElement(BoardElement element) {
    setState(() => _elements.add(element));
  }

  void receiveErase(String elementId) {
    setState(() => _elements.removeWhere((e) => e.id == elementId));
  }

  void clearAll() {
    setState(() => _elements.clear());
  }

  // ---------- GESTES ----------
  void _onPanStart(DragStartDetails d) {
    if (!widget.canDraw) return;
    switch (_tool) {
      case BoardTool.pen:
        _currentPoints = [
          {'x': d.localPosition.dx, 'y': d.localPosition.dy}
        ];
        break;
      case BoardTool.shape:
        _shapeStart = d.localPosition;
        _shapeLive = d.localPosition;
        break;
      case BoardTool.eraser:
        _eraseAt(d.localPosition);
        break;
      case BoardTool.text:
        break; // le texte se place au "tap", pas au glissement
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.canDraw) return;
    switch (_tool) {
      case BoardTool.pen:
        setState(() {
          _currentPoints = [
            ..._currentPoints,
            {'x': d.localPosition.dx, 'y': d.localPosition.dy}
          ];
        });
        break;
      case BoardTool.shape:
        setState(() => _shapeLive = d.localPosition);
        break;
      case BoardTool.eraser:
        _eraseAt(d.localPosition);
        break;
      case BoardTool.text:
        break;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (!widget.canDraw) return;
    switch (_tool) {
      case BoardTool.pen:
        if (_currentPoints.isEmpty) return;
        final element = FreehandBoardElement(
          id: _newId(),
          points: _currentPoints,
          colorValue: _color.value,
          width: _strokeWidth,
        );
        setState(() => _elements.add(element));
        widget.socket.sendStroke(element.toJson());
        _currentPoints = [];
        break;
      case BoardTool.shape:
        if (_shapeStart == null || _shapeLive == null) return;
        final element = ShapeBoardElement(
          id: _newId(),
          shapeType: _shapeType,
          x1: _shapeStart!.dx,
          y1: _shapeStart!.dy,
          x2: _shapeLive!.dx,
          y2: _shapeLive!.dy,
          colorValue: _color.value,
          strokeWidth: _strokeWidth,
        );
        setState(() {
          _elements.add(element);
          _shapeStart = null;
          _shapeLive = null;
        });
        widget.socket.sendStroke(element.toJson());
        break;
      case BoardTool.eraser:
      case BoardTool.text:
        break;
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (!widget.canDraw || _tool != BoardTool.text) return;
    _openTextDialog(d.localPosition);
  }

  // ---------- GOMME (efface l'élément touché, pas tout le tableau) ----------
  void _eraseAt(Offset point) {
    const threshold = 18.0;
    BoardElement? hit;
    for (final e in _elements.reversed) {
      if (_hitTest(e, point, threshold)) {
        hit = e;
        break;
      }
    }
    if (hit != null) {
      setState(() => _elements.removeWhere((e) => e.id == hit!.id));
      widget.socket.eraseElement(hit.id);
    }
  }

  bool _hitTest(BoardElement e, Offset p, double threshold) {
    if (e is FreehandBoardElement) {
      for (final pt in e.points) {
        if ((Offset(pt['x']!, pt['y']!) - p).distance <= threshold) return true;
      }
      return false;
    } else if (e is TextBoardElement) {
      final w = e.text.length * e.fontSize * 0.55 + threshold;
      final h = e.fontSize * 1.4 + threshold;
      return p.dx >= e.x - threshold && p.dx <= e.x + w && p.dy >= e.y - threshold && p.dy <= e.y + h;
    } else if (e is ShapeBoardElement) {
      final left = e.x1 < e.x2 ? e.x1 : e.x2;
      final right = e.x1 > e.x2 ? e.x1 : e.x2;
      final top = e.y1 < e.y2 ? e.y1 : e.y2;
      final bottom = e.y1 > e.y2 ? e.y1 : e.y2;
      return p.dx >= left - threshold &&
          p.dx <= right + threshold &&
          p.dy >= top - threshold &&
          p.dy <= bottom + threshold;
    }
    return false;
  }

  // ---------- DIALOGUE TEXTE (clavier normal + clavier mathématique) ----------
  void _openTextDialog(Offset position) {
    final textCtrl = TextEditingController();
    Color dialogColor = _color;

    void insertSymbol(String symbol) {
      final sel = textCtrl.selection;
      final base = sel.start >= 0 ? sel.start : textCtrl.text.length;
      final newText = textCtrl.text.replaceRange(base, base, symbol);
      textCtrl.text = newText;
      textCtrl.selection = TextSelection.collapsed(offset: base + symbol.length);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Ajouter du texte'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textCtrl,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Écris ton texte (clavier normal du téléphone)...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Symboles mathématiques', style: Theme.of(context).textTheme.labelMedium),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _mathSymbols
                      .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 15)),
                            onPressed: () => setDialogState(() => insertSymbol(s)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Couleur:', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(width: 8),
                    ..._palette.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setDialogState(() => dialogColor = c),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: c,
                              child: dialogColor == c
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final content = textCtrl.text.trim();
                if (content.isEmpty) {
                  Navigator.pop(dialogContext);
                  return;
                }
                final element = TextBoardElement(
                  id: _newId(),
                  x: position.dx,
                  y: position.dy,
                  text: content,
                  colorValue: dialogColor.value,
                  fontSize: 16 + _strokeWidth * 2,
                );
                setState(() => _elements.add(element));
                widget.socket.sendStroke(element.toJson());
                Navigator.pop(dialogContext);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- BARRE D'OUTILS ----------
  Widget _toolButton(BoardTool tool, IconData icon, String tooltip) {
    final selected = _tool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
          foregroundColor: selected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey[700],
        ),
        onPressed: () => setState(() => _tool = tool),
      ),
    );
  }

  Widget _shapeIcon(BoardShapeType type) {
    switch (type) {
      case BoardShapeType.line:
        return const Icon(Icons.horizontal_rule, size: 18);
      case BoardShapeType.rectangle:
        return const Icon(Icons.crop_square, size: 18);
      case BoardShapeType.circle:
        return const Icon(Icons.circle_outlined, size: 18);
      case BoardShapeType.triangle:
        return const Icon(Icons.change_history, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.canDraw)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              children: [
                // Ligne 1 : sélection de l'outil
                Row(
                  children: [
                    _toolButton(BoardTool.pen, Icons.edit, 'Stylo'),
                    _toolButton(BoardTool.text, Icons.text_fields, 'Texte'),
                    PopupMenuButton<BoardShapeType>(
                      tooltip: 'Formes géométriques',
                      icon: Icon(
                        Icons.category_outlined,
                        color: _tool == BoardTool.shape
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                      ),
                      onSelected: (type) => setState(() {
                        _shapeType = type;
                        _tool = BoardTool.shape;
                      }),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: BoardShapeType.line,
                          child: Row(children: [_shapeIcon(BoardShapeType.line), const SizedBox(width: 8), const Text('Ligne')]),
                        ),
                        PopupMenuItem(
                          value: BoardShapeType.rectangle,
                          child: Row(children: [_shapeIcon(BoardShapeType.rectangle), const SizedBox(width: 8), const Text('Rectangle')]),
                        ),
                        PopupMenuItem(
                          value: BoardShapeType.circle,
                          child: Row(children: [_shapeIcon(BoardShapeType.circle), const SizedBox(width: 8), const Text('Cercle')]),
                        ),
                        PopupMenuItem(
                          value: BoardShapeType.triangle,
                          child: Row(children: [_shapeIcon(BoardShapeType.triangle), const SizedBox(width: 8), const Text('Triangle')]),
                        ),
                      ],
                    ),
                    _toolButton(BoardTool.eraser, Icons.auto_fix_normal, 'Gomme (efface un élément)'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Tout effacer',
                      onPressed: () {
                        clearAll();
                        widget.socket.clearWhiteboard();
                      },
                    ),
                  ],
                ),
                // Ligne 2 : couleurs + épaisseur
                Row(
                  children: [
                    for (final c in _palette)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: c,
                            child: _color == c ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: 12,
                        value: _strokeWidth,
                        onChanged: (v) => setState(() => _strokeWidth = v),
                      ),
                    ),
                  ],
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
              onTapUp: _onTapUp,
              child: Container(
                color: Colors.white,
                child: CustomPaint(
                  painter: _WhiteboardPainter(
                    elements: _elements,
                    liveFreehand: _currentPoints,
                    liveShapeStart: _shapeStart,
                    liveShapeEnd: _shapeLive,
                    liveShapeType: _shapeType,
                    liveColor: _color,
                    liveWidth: _strokeWidth,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<BoardElement> elements;
  final List<Map<String, double>> liveFreehand;
  final Offset? liveShapeStart;
  final Offset? liveShapeEnd;
  final BoardShapeType liveShapeType;
  final Color liveColor;
  final double liveWidth;

  _WhiteboardPainter({
    required this.elements,
    required this.liveFreehand,
    required this.liveShapeStart,
    required this.liveShapeEnd,
    required this.liveShapeType,
    required this.liveColor,
    required this.liveWidth,
  });

  void _drawPolyline(Canvas canvas, List<Map<String, double>> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(
        Offset(points[i]['x']!, points[i]['y']!),
        Offset(points[i + 1]['x']!, points[i + 1]['y']!),
        paint,
      );
    }
  }

  void _drawShape(Canvas canvas, BoardShapeType type, Offset start, Offset end, Paint paint) {
    switch (type) {
      case BoardShapeType.line:
        canvas.drawLine(start, end, paint);
        break;
      case BoardShapeType.rectangle:
        canvas.drawRect(Rect.fromPoints(start, end), paint);
        break;
      case BoardShapeType.circle:
        final rect = Rect.fromPoints(start, end);
        canvas.drawOval(rect, paint);
        break;
      case BoardShapeType.triangle:
        final path = Path()
          ..moveTo((start.dx + end.dx) / 2, start.dy)
          ..lineTo(start.dx, end.dy)
          ..lineTo(end.dx, end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in elements) {
      if (e is FreehandBoardElement) {
        final paint = Paint()
          ..color = Color(e.colorValue)
          ..strokeWidth = e.width
          ..strokeCap = StrokeCap.round;
        _drawPolyline(canvas, e.points, paint);
      } else if (e is TextBoardElement) {
        final painter = TextPainter(
          text: TextSpan(
            text: e.text,
            style: TextStyle(color: Color(e.colorValue), fontSize: e.fontSize),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(e.x, e.y));
      } else if (e is ShapeBoardElement) {
        final paint = Paint()
          ..color = Color(e.colorValue)
          ..strokeWidth = e.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        _drawShape(canvas, e.shapeType, Offset(e.x1, e.y1), Offset(e.x2, e.y2), paint);
      }
    }

    // Aperçu en cours de tracé
    if (liveFreehand.isNotEmpty) {
      final paint = Paint()
        ..color = liveColor
        ..strokeWidth = liveWidth
        ..strokeCap = StrokeCap.round;
      _drawPolyline(canvas, liveFreehand, paint);
    }
    if (liveShapeStart != null && liveShapeEnd != null) {
      final paint = Paint()
        ..color = liveColor
        ..strokeWidth = liveWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      _drawShape(canvas, liveShapeType, liveShapeStart!, liveShapeEnd!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}