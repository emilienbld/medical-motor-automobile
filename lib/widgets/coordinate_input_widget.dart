// widgets/coordinate_input_widget.dart
import 'package:flutter/material.dart';

class CoordinateInputWidget extends StatefulWidget {
  final Function(String coordinates) onCoordinatesEntered;
  final bool isNavigating;

  const CoordinateInputWidget({
    Key? key,
    required this.onCoordinatesEntered,
    required this.isNavigating,
  }) : super(key: key);

  @override
  State<CoordinateInputWidget> createState() => _CoordinateInputWidgetState();
}

class _CoordinateInputWidgetState extends State<CoordinateInputWidget> {
  final TextEditingController _latDegreesController = TextEditingController();
  final TextEditingController _latMinutesController = TextEditingController();
  final TextEditingController _latSecondsController = TextEditingController();
  final TextEditingController _longDegreesController = TextEditingController();
  final TextEditingController _longMinutesController = TextEditingController();
  final TextEditingController _longSecondsController = TextEditingController();
  
  String _latDirection = 'N';
  String _longDirection = 'E';

  @override
  void initState() {
    super.initState();
    
    // Ajouter des listeners pour vérifier si tous les champs sont remplis
    _latDegreesController.addListener(_checkFieldsCompletion);
    _latMinutesController.addListener(_checkFieldsCompletion);
    _latSecondsController.addListener(_checkFieldsCompletion);
    _longDegreesController.addListener(_checkFieldsCompletion);
    _longMinutesController.addListener(_checkFieldsCompletion);
    _longSecondsController.addListener(_checkFieldsCompletion);
  }

  void _checkFieldsCompletion() {
    setState(() {});
  }

  bool get _areAllFieldsFilled {
    return _latDegreesController.text.isNotEmpty &&
           _latMinutesController.text.isNotEmpty &&
           _latSecondsController.text.isNotEmpty &&
           _longDegreesController.text.isNotEmpty &&
           _longMinutesController.text.isNotEmpty &&
           _longSecondsController.text.isNotEmpty;
  }

  void _handleGoButtonPressed() {
    if (!_areAllFieldsFilled || widget.isNavigating) return;
    
    String latDegrees = _latDegreesController.text.trim();
    String latMinutes = _latMinutesController.text.trim();
    String latSeconds = _latSecondsController.text.trim();
    String longDegrees = _longDegreesController.text.trim();
    String longMinutes = _longMinutesController.text.trim();
    String longSeconds = _longSecondsController.text.trim();
    
    String coordinates = '${latDegrees}°${latMinutes}\'${latSeconds}"$_latDirection,${longDegrees}°${longMinutes}\'${longSeconds}"$_longDirection';
    
    widget.onCoordinatesEntered(coordinates);
  }

  @override
  void dispose() {
    _latDegreesController.dispose();
    _latMinutesController.dispose();
    _latSecondsController.dispose();
    _longDegreesController.dispose();
    _longMinutesController.dispose();
    _longSecondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !widget.isNavigating;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_location,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Entrer vos coordonnées',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Latitude
            _buildCoordinateRow(
              label: 'Latitude',
              direction: _latDirection,
              onDirectionChanged: (value) {
                setState(() {
                  _latDirection = value!;
                });
              },
              directionOptions: ['N', 'S'],
              degreesController: _latDegreesController,
              minutesController: _latMinutesController,
              secondsController: _latSecondsController,
              isEnabled: isEnabled,
            ),
            
            const SizedBox(height: 12),
            
            // Longitude
            _buildCoordinateRow(
              label: 'Longitude',
              direction: _longDirection,
              onDirectionChanged: (value) {
                setState(() {
                  _longDirection = value!;
                });
              },
              directionOptions: ['E', 'O'],
              degreesController: _longDegreesController,
              minutesController: _longMinutesController,
              secondsController: _longSecondsController,
              isEnabled: isEnabled,
            ),
            
            const SizedBox(height: 20),
            
            // Bouton Y ALLER
            Center(
              child: GestureDetector(
                onTap: (_areAllFieldsFilled && isEnabled) ? _handleGoButtonPressed : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: (_areAllFieldsFilled && isEnabled)
                        ? Colors.green[50] 
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_areAllFieldsFilled && isEnabled)
                          ? Colors.green 
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isNavigating ? Icons.navigation : Icons.send,
                        size: 16,
                        color: (_areAllFieldsFilled && isEnabled)
                            ? Colors.green 
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isNavigating ? 'NAVIGATION...' : 'Y ALLER',
                        style: TextStyle(
                          fontSize: 14,
                          color: (_areAllFieldsFilled && isEnabled)
                              ? Colors.green 
                              : Colors.grey[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateRow({
    required String label,
    required String direction,
    required ValueChanged<String?> onDirectionChanged,
    required List<String> directionOptions,
    required TextEditingController degreesController,
    required TextEditingController minutesController,
    required TextEditingController secondsController,
    required bool isEnabled,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isEnabled ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: directionOptions.map((option) => 
            Row(
              children: [
                Radio<String>(
                  value: option,
                  groupValue: direction,
                  onChanged: isEnabled ? onDirectionChanged : null,
                  activeColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    color: isEnabled ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ).toList(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(degreesController, isEnabled),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('°', style: TextStyle(fontSize: 14)),
              ),
              Expanded(
                flex: 2,
                child: _buildTextField(minutesController, isEnabled),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('\'', style: TextStyle(fontSize: 14)),
              ),
              Expanded(
                flex: 2,
                child: _buildTextField(secondsController, isEnabled),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('"', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, bool isEnabled) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      enabled: isEnabled,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.green),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        fillColor: isEnabled ? Colors.white : Colors.grey[50],
        filled: true,
      ),
      style: TextStyle(
        color: isEnabled ? Colors.black87 : Colors.grey,
      ),
    );
  }
}