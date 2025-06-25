// widgets/joystick_widget.dart - VERSION CORRIGÉE
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

class _JoystickWidgetState extends State<JoystickWidget>
    with TickerProviderStateMixin {
  late double _centerX;
  late double _centerY;
  late double _knobX;
  late double _knobY;
  late double _radius;
  late double _knobRadius;
  
  // NOUVEAU: Animation pour le retour au centre
  late AnimationController _animationController;
  late Animation<Offset> _animation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _radius = widget.size / 2;
    _knobRadius = widget.size / 6;
    _centerX = _radius;
    _centerY = _radius;
    _knobX = _centerX;
    _knobY = _centerY;
    
    // CORRECTION: Initialiser l'animation pour le retour au centre
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animation.addListener(() {
      // CORRECTION: Seulement mettre à jour la position si on n'est PAS en train de drag
      if (!_isDragging && mounted) {
        setState(() {
          _knobX = _centerX + _animation.value.dx;
          _knobY = _centerY + _animation.value.dy;
        });
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    print('🎮 DRAG START');
    _isDragging = true;
    _animationController.stop();
    _animationController.reset(); // CORRECTION: Reset complet de l'animation
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // CORRECTION: Supprimer la condition qui bloque le mouvement
    print('🎮 DRAG UPDATE - isDragging: $_isDragging');
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    final dx = localPosition.dx - _centerX;
    final dy = localPosition.dy - _centerY;
    final distance = sqrt(dx * dx + dy * dy);
    
    // CORRECTION: Toujours permettre le mouvement pendant le drag
    setState(() {
      if (distance <= _radius - _knobRadius) {
        _knobX = localPosition.dx;
        _knobY = localPosition.dy;
      } else {
        // Limiter le joystick au bord du cercle
        final angle = atan2(dy, dx);
        final maxDistance = _radius - _knobRadius;
        _knobX = _centerX + cos(angle) * maxDistance;
        _knobY = _centerY + sin(angle) * maxDistance;
      }
    });
    
    // Calculer les valeurs normalisées (-1 à 1)
    final normalizedX = (_knobX - _centerX) / (_radius - _knobRadius);
    final normalizedY = (_knobY - _centerY) / (_radius - _knobRadius);
    
    print('🎮 Position: x=${normalizedX.toStringAsFixed(2)}, y=${normalizedY.toStringAsFixed(2)}');
    widget.onJoystickMove(normalizedX, normalizedY);
  }

  void _onPanEnd(DragEndDetails details) {
    print('🎮 DRAG END');
    _isDragging = false;
    
    // CORRECTION: S'assurer que l'animation est complètement reset
    _animationController.reset();
    
    // Calculer la position actuelle
    final currentOffset = Offset(_knobX - _centerX, _knobY - _centerY);
    
    // CORRECTION: Nouvelle animation vers le centre
    _animation = Tween<Offset>(
      begin: currentOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Envoyer STOP immédiatement
    widget.onJoystickMove(0, 0);
    
    // CORRECTION: Démarrer l'animation après un petit délai
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && !_isDragging) {
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Cercle extérieur (base) - AMÉLIORÉ visuellement
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[400]!, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          
          // NOUVEAU: Zone morte visible
          Center(
            child: Container(
              width: (_radius - _knobRadius) * 2 * 0.5, // 50% du rayon = deadzone
              height: (_radius - _knobRadius) * 2 * 0.5,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
          
          // Lignes de guidage améliorées
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: JoystickGuidePainter(_radius),
          ),
          
          // Bouton du joystick - AMÉLIORÉ
          Positioned(
            left: _knobX - _knobRadius,
            top: _knobY - _knobRadius,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Container(
                width: _knobRadius * 2,
                height: _knobRadius * 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4CAF50),
                      const Color(0xFF388E3C),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.control_camera,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // NOUVEAU: Indicateur de direction
          if (_isDragging) _buildDirectionIndicator(),
        ],
      ),
    );
  }

  // NOUVEAU: Widget pour afficher la direction actuelle
  Widget _buildDirectionIndicator() {
    final dx = _knobX - _centerX;
    final dy = _knobY - _centerY;
    final distance = sqrt(dx * dx + dy * dy);
    
    if (distance < (_radius - _knobRadius) * 0.5) {
      return Positioned(
        bottom: 10,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ZONE MORTE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    
    // Déterminer la direction pour l'affichage
    String direction = "UNKNOWN";
    final normalizedX = dx / (_radius - _knobRadius);
    final normalizedY = dy / (_radius - _knobRadius);
    
    if (normalizedY < -0.5 && normalizedX.abs() < 0.3) direction = "AVANT";
    else if (normalizedY > 0.5 && normalizedX.abs() < 0.3) direction = "ARRIÈRE";
    else if (normalizedX > 0.5 && normalizedY.abs() < 0.3) direction = "DROITE";
    else if (normalizedX < -0.5 && normalizedY.abs() < 0.3) direction = "GAUCHE";
    else if (normalizedY < -0.3 && normalizedX > 0.3) direction = "AV-DROITE";
    else if (normalizedY < -0.3 && normalizedX < -0.3) direction = "AV-GAUCHE";
    else if (normalizedY > 0.3 && normalizedX > 0.3) direction = "AR-DROITE";
    else if (normalizedY > 0.3 && normalizedX < -0.3) direction = "AR-GAUCHE";
    
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            direction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class JoystickGuidePainter extends CustomPainter {
  final double radius;

  JoystickGuidePainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(radius, radius);

    // Lignes horizontale et verticale principales
    canvas.drawLine(
      Offset(30, radius),
      Offset(size.width - 30, radius),
      paint,
    );
    canvas.drawLine(
      Offset(radius, 30),
      Offset(radius, size.height - 30),
      paint,
    );
    
    // NOUVEAU: Lignes diagonales pour les directions
    paint.color = Colors.grey[300]!;
    paint.strokeWidth = 1;
    
    // Diagonales
    canvas.drawLine(
      Offset(50, 50),
      Offset(size.width - 50, size.height - 50),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 50, 50),
      Offset(50, size.height - 50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}