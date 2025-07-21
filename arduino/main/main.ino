#include <Wire.h>
#include "config.h"
#include "robot_controller.h"
#include "wifi_handler.h"

// Instances globales
RobotController robot;
WiFiHandler wifiHandler(&robot);

void setup() {
    // Initialisation du robot complet
    robot.init();
    
    // Initialisation du WiFi
    wifiHandler.init();
    
    Serial.println("✅ Système complet initialisé !");
}

void loop() {
    // Mise à jour du robot (capteurs, sécurité, navigation, timeouts)
    robot.update();
    
    // Gestion des clients WiFi
    wifiHandler.handleClients();
    
    // Gestion des commandes série
    robot.handleSerialCommand();
}