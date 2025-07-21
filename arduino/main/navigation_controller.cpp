#include "navigation_controller.h"

NavigationController::NavigationController(GPSHandler* gps, MPU6500Handler* mpu, MotorController* motor) 
    : gpsHandler(gps), mpuHandler(mpu), motorController(motor),
      targetLat(0.0), targetLng(0.0), targetSet(false), navigating(false) {
}

void NavigationController::init() {
    Serial.println("✅ Contrôleur de navigation initialisé");
}

void NavigationController::update() {
    if (navigating && targetSet && gpsHandler->isPositionValid()) {
        navigate();
    }
}

void NavigationController::navigate() {
    // 1. Calculer distance et direction vers la cible
    double distance = GPSHandler::calculateDistance(
        gpsHandler->getCurrentLatitude(), gpsHandler->getCurrentLongitude(), 
        targetLat, targetLng
    );
    double target_bearing = GPSHandler::calculateBearing(
        gpsHandler->getCurrentLatitude(), gpsHandler->getCurrentLongitude(), 
        targetLat, targetLng
    );
    
    Serial.print("Distance: ");
    Serial.print(distance, 1);
    Serial.print("m | Direction cible: ");
    Serial.print(target_bearing, 1);
    Serial.print("°");
    
    if (mpuHandler->isGyroOK()) {
        Serial.print(" | Angle robot: ");
        Serial.print(mpuHandler->getRobotAngle(), 1);
        Serial.println("°");
    } else {
        Serial.println();
    }
    
    // 2. Vérifier si on est arrivé
    if (distance <= ARRIVAL_DISTANCE) {
        Serial.println("🎯 ARRIVÉ À DESTINATION!");
        motorController->stop();
        navigating = false;
        return;
    }
    
    // 3. Navigation avec ou sans gyroscope
    if (mpuHandler->isGyroOK()) {
        // Navigation avec gyroscope (précise)
        double angle_error = target_bearing - mpuHandler->getRobotAngle();
        angle_error = MPU6500Handler::normalizeAngleDiffPublic(angle_error);
        
        Serial.print("Erreur d'angle: ");
        Serial.print(angle_error, 1);
        Serial.print("° | ");
        
        if (abs(angle_error) > ANGLE_TOLERANCE) {
            // Besoin de tourner
            int turn_speed = motorController->calculateTurnSpeed(angle_error);
            
            Serial.print("🔄 Correction ");
            
            if (angle_error > 0) {
                Serial.print("droite | Angle: ");
                Serial.print(angle_error, 1);
                Serial.print("° | Vitesse: ");
                Serial.println(turn_speed);
                motorController->turnRight(turn_speed);
            } else {
                Serial.print("gauche | Angle: ");
                Serial.print(abs(angle_error), 1);
                Serial.print("° | Vitesse: ");
                Serial.println(turn_speed);
                motorController->turnLeft(turn_speed);
            }
            
            // Attendre que la rotation se fasse
            unsigned long turn_duration = map(abs(angle_error), 8, 180, 200, 1000);
            delay(turn_duration);
            
            motorController->stop();
            delay(150);  // Pause pour stabiliser
            
        } else {
            // Direction correcte, avancer
            Serial.println("➡️ Avance vers la cible");
            motorController->goForward();
        }
    } else {
        // Navigation GPS seule (moins précise)
        Serial.println("⚠️ Navigation GPS seule - Gyroscope non disponible");
        Serial.println("➡️ Avance vers la cible");
        motorController->goForward();
    }
}

void NavigationController::handleCommands() {
    if (!Serial.available()) return;
    
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toLowerCase();
    
    if (cmd.startsWith("set ")) {
        setTarget(cmd.substring(4));
    }
    else if (cmd == "go") {
        startNavigation();
    }
    else if (cmd == "stop") {
        stopNavigation();
    }
    else if (cmd == "status") {
        printStatus();
    }
    else if (cmd == "calibrate") {
        mpuHandler->calibrate();
    }
    else if (cmd == "gyro_test") {
        mpuHandler->testGyroscope();
    }
    else if (cmd == "scan") {
        mpuHandler->scanI2C();
    }
    else if (cmd == "mpu_debug") {
        mpuHandler->debugMPU6500();
    }
    else if (cmd == "mpu_reset") {
        mpuHandler->resetMPU6500();
    }
    else if (cmd == "turn_test") {
        testTurning();
    }
    else if (cmd == "gyro_live") {
        mpuHandler->testGyroLive();
    }
    else if (cmd == "test") {
        motorController->testMotors();
    }
    else if (cmd == "speed_test") {
        testSpeedMapping();
    }
    else {
        Serial.println("❓ Commande inconnue");
    }
}

void NavigationController::setTarget(String coords) {
    // Parse "48°50'18"N,2°18'41"E"
    int comma = coords.indexOf(',');
    if (comma == -1) {
        Serial.println("❌ Format invalide. Exemple: 48°50'18\"N,2°18'41\"E");
        return;
    }
    
    String lat_str = coords.substring(0, comma);
    String lng_str = coords.substring(comma + 1);
    
    targetLat = GPSHandler::parseDMS(lat_str);
    targetLng = GPSHandler::parseDMS(lng_str);
    
    if (isnan(targetLat) || isnan(targetLng)) {
        Serial.println("❌ Coordonnées invalides");
        return;
    }
    
    targetSet = true;
    Serial.println("✅ Destination définie:");
    Serial.print("   Latitude: "); Serial.println(targetLat, 6);
    Serial.print("   Longitude: "); Serial.println(targetLng, 6);
    
    if (gpsHandler->isPositionValid()) {
        double dist = GPSHandler::calculateDistance(
            gpsHandler->getCurrentLatitude(), gpsHandler->getCurrentLongitude(), 
            targetLat, targetLng
        );
        double bearing = GPSHandler::calculateBearing(
            gpsHandler->getCurrentLatitude(), gpsHandler->getCurrentLongitude(), 
            targetLat, targetLng
        );
        Serial.print("   Distance: "); Serial.print(dist, 1); Serial.println("m");
        Serial.print("   Direction: "); Serial.print(bearing, 1); Serial.println("°");
    }
}

void NavigationController::startNavigation() {
    if (!targetSet) {
        Serial.println("❌ Aucune destination définie");
        return;
    }
    if (!gpsHandler->isPositionValid()) {
        Serial.println("❌ Position GPS non disponible");
        return;
    }
    if (!mpuHandler->isGyroOK()) {
        Serial.println("⚠️ Gyroscope non disponible - Navigation GPS seule");
    }
    
    navigating = true;
    Serial.println("🚀 NAVIGATION DÉMARRÉE");
}

void NavigationController::stopNavigation() {
    navigating = false;
    motorController->stop();
    Serial.println("🛑 Navigation arrêtée");
}

void NavigationController::printStatus() {
    Serial.println("=== ÉTAT ACTUEL ===");
    Serial.print("GPS: "); Serial.println(gpsHandler->isPositionValid() ? "✅ OK" : "❌ Pas de signal");
    Serial.print("MPU-6500: "); Serial.println(mpuHandler->isGyroOK() ? "✅ OK" : "❌ Erreur");
    Serial.print("Destination: "); Serial.println(targetSet ? "✅ Définie" : "❌ Non définie");
    Serial.print("Navigation: "); Serial.println(navigating ? "🚀 Active" : "⏸️ Arrêtée");
    
    if (gpsHandler->isPositionValid()) {
        Serial.print("Position: "); Serial.print(gpsHandler->getCurrentLatitude(), 6); 
        Serial.print(", "); Serial.println(gpsHandler->getCurrentLongitude(), 6);
    }
    if (mpuHandler->isGyroOK()) {
        Serial.print("Angle robot: "); Serial.print(mpuHandler->getRobotAngle(), 1); Serial.println("°");
        Serial.print("Vitesse rotation: "); Serial.print(mpuHandler->getRotationSpeed(), 2); Serial.println("°/s");
    }
    if (targetSet) {
        Serial.print("Destination: "); Serial.print(targetLat, 6);
        Serial.print(", "); Serial.println(targetLng, 6);
    }
    Serial.println("==================");
}

void NavigationController::testTurning() {
    if (!mpuHandler->isGyroOK()) {
        Serial.println("❌ Test impossible - Gyroscope non disponible");
        return;
    }
    
    Serial.println("🔄 TEST ROTATION CONTRÔLÉE");
    Serial.println("Test rotation de 90° vers la droite...");
    
    float start_angle = mpuHandler->getRobotAngle();
    float target_angle = MPU6500Handler::normalizeAnglePublic(start_angle + 90);
    
    Serial.print("Angle initial: "); Serial.print(start_angle, 1);
    Serial.print("° | Cible: "); Serial.print(target_angle, 1); Serial.println("°");
    
    unsigned long start_time = millis();
    while (millis() - start_time < 15000) {  // Max 15 secondes
        
        // Forcer la lecture du gyroscope
        mpuHandler->update();
        
        // Calculer l'erreur d'angle
        double angle_error = target_angle - mpuHandler->getRobotAngle();
        angle_error = MPU6500Handler::normalizeAngleDiffPublic(angle_error);
        
        // Calculer la vitesse adaptative
        int turn_speed = motorController->calculateTurnSpeed(angle_error);
        
        // Afficher les données
        float gyro_speed = mpuHandler->getRotationSpeed();
        
        Serial.print("Angle: "); Serial.print(mpuHandler->getRobotAngle(), 1);
        Serial.print("° | Erreur: "); Serial.print(angle_error, 1);
        Serial.print("° | Vitesse: "); Serial.print(turn_speed);
        Serial.print(" | Gyro: "); Serial.print(gyro_speed, 1); Serial.println("°/s");
        
        // Arrêter si proche de la cible
        if (abs(angle_error) < 4.0) {
            Serial.println("🎯 Angle cible atteint!");
            break;
        }
        
        // Tourner avec la vitesse adaptée
        if (angle_error > 0) {
            motorController->turnRight(turn_speed);
        } else {
            motorController->turnLeft(turn_speed);
        }
        
        delay(100);
    }
    
    motorController->stop();
    
    float final_angle = mpuHandler->getRobotAngle();
    float actual_rotation = final_angle - start_angle;
    if (actual_rotation < -180) actual_rotation += 360;
    if (actual_rotation > 180) actual_rotation -= 360;
    
    Serial.print("Rotation réelle: "); Serial.print(actual_rotation, 1); Serial.println("°");
    Serial.println("✅ Test terminé");
}

void NavigationController::testSpeedMapping() {
    Serial.println("🔧 TEST MAPPING VITESSE/ANGLE");
    Serial.println("Test des vitesses selon l'erreur d'angle:");
    
    double test_angles[] = {5, 10, 20, 30, 45, 60, 90, 120, 180};
    int num_tests = sizeof(test_angles) / sizeof(test_angles[0]);
    
    for (int i = 0; i < num_tests; i++) {
        double angle = test_angles[i];
        int speed = motorController->calculateTurnSpeed(angle);
        
        Serial.print("   Angle: ");
        if (angle < 10) Serial.print(" ");
        if (angle < 100) Serial.print(" ");
        Serial.print(angle, 0);
        Serial.print("° → Vitesse PWM: ");
        Serial.println(speed);
    }
    
    Serial.println("✅ Mapping terminé");
}

bool NavigationController::isNavigating() const {
    return navigating;
}

bool NavigationController::isTargetSet() const {
    return targetSet;
}