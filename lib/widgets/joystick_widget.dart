import 'package:flutter/material.dart';
import 'dart:math';

class JoystickWidget extends StatefulWidget {
  final Function(double x, double y) onJoystickMove;
  final double size;

  const JoystickWidget({
    Key? key,
    required this.onJoystickMove,
    this.size = 200,
  }) : super(key: key);

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  late double _centerX;
  late double _centerY;
  late double _knobX;
  late double _knobY;
  late double _radius;
  late double _knobRadius;

  @override
  void initState() {
    super.initState();
    _radius = widget.size / 2;
    _knobRadius = widget.size / 6;
    _centerX = _radius;
    _centerY = _radius;
    _knobX = _centerX;
    _knobY = _centerY;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    final dx = localPosition.dx - _centerX;
    final dy = localPosition.dy - _centerY;
    final distance = sqrt(dx * dx + dy * dy);
    
    if (distance <= _radius - _knobRadius) {
      setState(() {
        _knobX = localPosition.dx;
        _knobY = localPosition.dy;
      });
    } else {
      // Limiter le joystick au bord du cercle
      final angle = atan2(dy, dx);
      final maxDistance = _radius - _knobRadius;
      setState(() {
        _knobX = _centerX + cos(angle) * maxDistance;
        _knobY = _centerY + sin(angle) * maxDistance;
      });
    }
    
    // Calculer les valeurs normalisées (-1 à 1)
    final normalizedX = (_knobX - _centerX) / (_radius - _knobRadius);
    final normalizedY = (_knobY - _centerY) / (_radius - _knobRadius);
    
    widget.onJoystickMove(normalizedX, normalizedY);
  }

  void _onPanEnd(DragEndDetails details) {
    // Remettre le joystick au centre
    setState(() {
      _knobX = _centerX;
      _knobY = _centerY;
    });
    widget.onJoystickMove(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Cercle extérieur (base)
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
          ),
          
          // Lignes de guidage (optionnel)
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: JoystickGuidePainter(_radius),
          ),
          
          // Bouton du joystick
          Positioned(
            left: _knobX - _knobRadius,
            top: _knobY - _knobRadius,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Container(
                width: _knobRadius * 2,
                height: _knobRadius * 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.control_camera,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JoystickGuidePainter extends CustomPainter {
  final double radius;

  JoystickGuidePainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(radius, radius);

    // Lignes horizontale et verticale
    canvas.drawLine(
      Offset(20, radius),
      Offset(size.width - 20, radius),
      paint,
    );
    canvas.drawLine(
      Offset(radius, 20),
      Offset(radius, size.height - 20),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}