import 'package:flutter/material.dart';

class DeviceItem extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onToggleConnection;

  const DeviceItem({
    Key? key,
    required this.device,
    required this.onToggleConnection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isConnected = device['isConnected'] ?? false;
    final Color statusColor = isConnected ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          
          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  device['type'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // Time and battery
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (device['time'] != null && device['time'].isNotEmpty)
                Text(
                  device['time'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              Text(
                device['battery'] ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Connect button
          GestureDetector(
            onTap: onToggleConnection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isConnected ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isConnected ? 'Déconnecter' : 'Connecter',
                style: TextStyle(
                  fontSize: 11,
                  color: isConnected ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}