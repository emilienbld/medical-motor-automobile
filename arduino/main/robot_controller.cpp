#include "robot_controller.h"
#include <Wire.h>

RobotController::RobotController() 
    : distanceSensor(TRIG_PIN, ECHO_PIN),
      servoScanner(SERVO_PIN, &distanceSensor),
      motorController(PWMA, PWMB, AIN, BIN, STBY),
      obstacleDetected(false),
      gpsHandler(),
      mpuHandler(),
      navigationController(&gpsHandler, &mpuHandler, &motorController) {
    // Corps du constructeur
}

void RobotController::init() {
    Serial.begin(SERIAL_BAUD);
    Serial.println("=== Robot MMA v6.0 COMPLET (Obstacles + GPS) ===");
    
    Wire.begin(); // Initialiser I2C pour MPU-6500
    pinMode(LED_BUILTIN, OUTPUT);
    
    // Initialisation des composants évitement d'obstacles
    distanceSensor.init();
    servoScanner.init();
    motorController.init();
    
    // Test du servo scanner
    servoScanner.testScan();
    
    // Initialisation des composants navigation GPS
    gpsHandler.init();
    mpuHandler.init();
    navigationController.init();
    
    Serial.println("✅ Robot complet initialisé !");
    Serial.println("MODES DISPONIBLES:");
    Serial.println("- Évitement d'obstacles: z,s,q,d,x,i,r");
    Serial.println("- Navigation GPS: set, go, stop, status, etc.");
    Serial.println("==========================================");
}

void RobotController::update() {
    motorController.checkRotationTimeout();
    
    // === MISE À JOUR CAPTEURS ===
    
    // Capteur de distance pour évitement d'obstacles
    if (distanceSensor.updateDistance()) {
        bool wasObstacle = obstacleDetected;
        obstacleDetected = distanceSensor.isObstacleDetected();
        
        if (obstacleDetected != wasObstacle) {
            Serial.print(">>> CHANGEMENT: ");
            Serial.println(obstacleDetected ? "🚨 OBSTACLE DÉTECTÉ" : "✅ VOIE LIBRE");
        }
    }
    
    // GPS et gyroscope pour navigation
    gpsHandler.update();
    mpuHandler.update();
    
    // === SÉCURITÉS ===
    
    // Arrêt sécurité obstacle (seulement si pas en navigation GPS)
    if (obstacleDetected && !motorController.getIsRotating() && !navigationController.isNavigating()) {
        Serial.println("🛑 ARRÊT SÉCURITÉ - Obstacle détecté");
        motorController.stop();
    }
    
    // === NAVIGATION GPS ===
    navigationController.update();
}

bool RobotController::processMovementCommand(String cmd) {
    return checkMovementSafety(cmd);
}

bool RobotController::checkMovementSafety(String cmd) {
    bool blocked = false;
    
    // Vérification obstacle frontal
    if (cmd.indexOf("forward") != -1 && obstacleDetected) {
        blocked = true;
    }
    
    // Scan automatique pour les mouvements latéraux
    if (cmd == "left" || cmd == "forward_left" || cmd == "backward_left") {
        Serial.println("🔍 SCAN GAUCHE automatique...");
        if (!servoScanner.checkLeftSafe(OBSTACLE_DISTANCE_CM)) {
            Serial.println("❌ MOUVEMENT GAUCHE BLOQUÉ - Obstacle détecté !");
            blocked = true;
        }
        servoScanner.returnToCenter();
    }
    else if (cmd == "right" || cmd == "forward_right" || cmd == "backward_right") {
        Serial.println("🔍 SCAN DROITE automatique...");
        if (!servoScanner.checkRightSafe(OBSTACLE_DISTANCE_CM)) {
            Serial.println("❌ MOUVEMENT DROITE BLOQUÉ - Obstacle détecté !");
            blocked = true;
        }
        servoScanner.returnToCenter();
    }
    
    if (!blocked) {
        executeMovement(cmd);
    }
    
    return blocked;
}

void RobotController::executeMovement(String cmd) {
    if (cmd == "forward") motorController.forward();
    else if (cmd == "backward") motorController.backward();
    else if (cmd == "left") motorController.rotateLeft90();
    else if (cmd == "right") motorController.rotateRight90();
    else if (cmd == "forward_right") motorController.forwardRight();
    else if (cmd == "forward_left") motorController.forwardLeft();
    else if (cmd == "backward_right") motorController.backwardRight();
    else if (cmd == "backward_left") motorController.backwardLeft();
    else if (cmd == "stop") motorController.stop();
}

void RobotController::handleSerialCommand() {
    if (!Serial.available()) return;
    
    String input = Serial.readStringUntil('\n');
    input.trim();
    
    // === COMMANDES NAVIGATION GPS (multi-caractères) ===
    if (input.length() > 1) {
        navigationController.handleCommands();
        return;
    }
    
    // === COMMANDES ÉVITEMENT D'OBSTACLES (caractère unique) ===
    char cmd = input.charAt(0);
    bool blocked = false;
    
    Serial.print("💻 COMMANDE SÉRIE: ");
    Serial.print(cmd);
    
    switch (cmd) {
        case 'z':
            if (!obstacleDetected && !navigationController.isNavigating()) {
                Serial.println(" -> FORWARD autorisé");
                motorController.forward();
            } else {
                Serial.println(" -> FORWARD BLOQUÉ");
                blocked = true;
            }
            break;
        case 's': 
            if (!navigationController.isNavigating()) {
                Serial.println(" -> BACKWARD");
                motorController.backward();
            } else {
                Serial.println(" -> BACKWARD BLOQUÉ (navigation GPS active)");
                blocked = true;
            }
            break;
        case 'q': 
            if (!navigationController.isNavigating()) {
                Serial.println(" -> LEFT avec scan...");
                if (servoScanner.checkLeftSafe(OBSTACLE_DISTANCE_CM)) {
                    servoScanner.returnToCenter();
                    motorController.rotateLeft90();
                } else {
                    servoScanner.returnToCenter();
                    Serial.println("❌ ROTATION GAUCHE BLOQUÉE");
                    blocked = true;
                }
            } else {
                Serial.println(" -> LEFT BLOQUÉ (navigation GPS active)");
                blocked = true;
            }
            break;
        case 'd': 
            if (!navigationController.isNavigating()) {
                Serial.println(" -> RIGHT avec scan...");
                if (servoScanner.checkRightSafe(OBSTACLE_DISTANCE_CM)) {
                    servoScanner.returnToCenter();
                    motorController.rotateRight90();
                } else {
                    servoScanner.returnToCenter();
                    Serial.println("❌ ROTATION DROITE BLOQUÉE");
                    blocked = true;
                }
            } else {
                Serial.println(" -> RIGHT BLOQUÉ (navigation GPS active)");
                blocked = true;
            }
            break;
        case 'x': 
            Serial.println(" -> STOP");
            motorController.stop();
            if (navigationController.isNavigating()) {
                navigationController.stopNavigation();
                Serial.println("🛑 Navigation GPS arrêtée");
            }
            break;
        case 'i':
            Serial.print(" -> INFO: Distance ");
            Serial.print(distanceSensor.getLastValidDistance()); 
            Serial.print("cm");
            if (gpsHandler.isPositionValid()) {
                Serial.print(" | GPS: ");
                Serial.print(gpsHandler.getCurrentLatitude(), 6);
                Serial.print(",");
                Serial.print(gpsHandler.getCurrentLongitude(), 6);
            }
            Serial.println();
            break;
        case 'r':
            if (!navigationController.isNavigating()) {
                servoScanner.fullScan();
            } else {
                Serial.println(" -> SCAN BLOQUÉ (navigation GPS active)");
                blocked = true;
            }
            break;
        default:
            Serial.println(" -> INCONNUE");
            Serial.println("💡 Commandes disponibles:");
            Serial.println("   z,s,q,d,x,i,r - Contrôle robot");
            Serial.println("   set, go, stop, status... - Navigation GPS");
            break;
    }
    
    if (blocked) Serial.println("❌ COMMANDE BLOQUÉE PAR SÉCURITÉ");
}

float RobotController::getDistance() const {
    return distanceSensor.getLastValidDistance();
}

bool RobotController::isObstacleDetected() const {
    return obstacleDetected;
}

// === GETTERS POUR NAVIGATION GPS ===

bool RobotController::isGPSValid() const {
    return gpsHandler.isPositionValid();
}

double RobotController::getGPSLatitude() const {
    return gpsHandler.getCurrentLatitude();
}

double RobotController::getGPSLongitude() const {
    return gpsHandler.getCurrentLongitude();
}

bool RobotController::isGyroOK() const {
    return mpuHandler.isGyroOK();
}

float RobotController::getRobotAngle() const {
    return mpuHandler.getRobotAngle();
}

bool RobotController::isNavigating() const {
    return navigationController.isNavigating();
}