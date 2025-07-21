#include "mpu6500_handler.h"

MPU6500Handler::MPU6500Handler() 
    : gyroOffset(0.0), robotAngle(0.0), lastGyroTime(0), gyroOK(false) {
}

void MPU6500Handler::init() {
    Serial.print("Initialisation MPU-6500... ");
    
    Wire.beginTransmission(MPU6500_ADDR);
    Wire.write(0x6B);  // PWR_MGMT_1
    Wire.write(0);     // Réveiller le capteur
    byte error = Wire.endTransmission(true);
    
    if (error == 0) {
        // Vérifier l'ID du composant
        Wire.beginTransmission(MPU6500_ADDR);
        Wire.write(0x75);  // WHO_AM_I
        Wire.endTransmission(false);
        Wire.requestFrom(MPU6500_ADDR, 1, true);
        
        if (Wire.available()) {
            byte who_am_i = Wire.read();
            Serial.print("ID=0x"); Serial.print(who_am_i, HEX); Serial.print(" ");
            
            if (who_am_i == 0x70 || who_am_i == 0x68) {  // MPU-6500 ou MPU-6050
                // Configuration gyroscope ±250°/s
                Wire.beginTransmission(MPU6500_ADDR);
                Wire.write(0x1B);
                Wire.write(0x00);
                Wire.endTransmission(true);
                
                gyroOK = true;
                lastGyroTime = millis();
                Serial.println("✅ OK");
                
                calibrate();
            } else {
                gyroOK = false;
                Serial.println("❌ ID incorrect");
            }
        } else {
            gyroOK = false;
            Serial.println("❌ Pas de réponse ID");
        }
    } else {
        gyroOK = false;
        Serial.println("❌ Pas de connexion I2C");
    }
}

void MPU6500Handler::update() {
    if (!gyroOK) return;
    
    unsigned long now = millis();
    float dt = (now - lastGyroTime) / 1000.0;  // Delta temps en secondes
    
    if (dt < (MIN_GYRO_INTERVAL / 1000.0)) return;  // Minimum entre lectures
    
    // Lire vitesse de rotation Z (°/s)
    float rotation_speed = readGyroZ() - gyroOffset;
    
    // Intégrer pour obtenir l'angle
    robotAngle += rotation_speed * dt;
    robotAngle = normalizeAngle(robotAngle);
    
    lastGyroTime = now;
}

void MPU6500Handler::calibrate() {
    if (!gyroOK) return;
    
    Serial.print("Calibration gyroscope (ne pas bouger)... ");
    
    float sum = 0;
    
    for (int i = 0; i < GYRO_SAMPLES_CALIBRATION; i++) {
        sum += readGyroZ();
        delay(2);
    }
    
    gyroOffset = sum / GYRO_SAMPLES_CALIBRATION;
    robotAngle = 0.0;  // Reset de l'angle
    
    Serial.print("✅ Terminé (offset: ");
    Serial.print(gyroOffset, 2);
    Serial.println("°/s)");
}

float MPU6500Handler::readGyroZ() const {
    if (!gyroOK) return 0.0;
    
    Wire.beginTransmission(MPU6500_ADDR);
    Wire.write(0x47);  // GYRO_ZOUT_H
    Wire.endTransmission(false);
    Wire.requestFrom(MPU6500_ADDR, 2, true);
    
    if (Wire.available() >= 2) {
        int16_t raw = Wire.read() << 8 | Wire.read();
        return raw / 131.0;  // Conversion en °/s (sensibilité ±250°/s)
    }
    return 0.0;
}

bool MPU6500Handler::isGyroOK() const {
    return gyroOK;
}

float MPU6500Handler::getRobotAngle() const {
    return robotAngle;
}

float MPU6500Handler::getRotationSpeed() const {
    return readGyroZ() - gyroOffset;
}

void MPU6500Handler::resetAngle() {
    robotAngle = 0.0;
}

double MPU6500Handler::normalizeAngle(double angle) {
    while (angle >= 360.0) angle -= 360.0;
    while (angle < 0.0) angle += 360.0;
    return angle;
}

double MPU6500Handler::normalizeAngleDiff(double angle_diff) {
    while (angle_diff > 180.0) angle_diff -= 360.0;
    while (angle_diff < -180.0) angle_diff += 360.0;
    return angle_diff;
}

double MPU6500Handler::normalizeAnglePublic(double angle) {
    return normalizeAngle(angle);
}

double MPU6500Handler::normalizeAngleDiffPublic(double angle_diff) {
    return normalizeAngleDiff(angle_diff);
}

// === FONCTIONS DE TEST ET DIAGNOSTIC ===

void MPU6500Handler::testGyroscope() {
    Serial.println("🔄 TEST GYROSCOPE FORCÉ");
    
    Serial.print("1. Test connexion I2C MPU-6500: ");
    Wire.beginTransmission(MPU6500_ADDR);
    byte error = Wire.endTransmission(true);
    if (error == 0) {
        Serial.println("✅ OK");
    } else {
        Serial.print("❌ Erreur "); Serial.println(error);
        return;
    }
    
    Serial.print("2. Lecture ID: ");
    Wire.beginTransmission(MPU6500_ADDR);
    Wire.write(0x75);  // WHO_AM_I
    Wire.endTransmission(false);
    Wire.requestFrom(MPU6500_ADDR, 1, true);
    if (Wire.available()) {
        byte id = Wire.read();
        Serial.print("0x"); Serial.print(id, HEX);
        if (id == 0x70) {
            Serial.println(" ✅ Correct (MPU-6500)");
        } else if (id == 0x68) {
            Serial.println(" ✅ Correct (MPU-6050)");
        } else {
            Serial.println(" ⚠️ Différent (mais ça peut marcher)");
        }
    } else {
        Serial.println(" ❌ Pas de réponse");
        return;
    }
    
    Serial.println("3. Test 10 lectures gyroscope:");
    for (int i = 0; i < 10; i++) {
        float gyro_val = readGyroZ();
        Serial.print("   Lecture "); Serial.print(i+1); Serial.print(": ");
        Serial.print(gyro_val, 2); Serial.println("°/s");
        delay(200);
    }
    
    Serial.println("4. Réactiver le gyroscope:");
    init();
}

void MPU6500Handler::testGyroLive() {
    Serial.println("🔄 TEST GYROSCOPE EN TEMPS RÉEL");
    Serial.println("Tournez le robot maintenant - 15 secondes de test");
    
    unsigned long start_time = millis();
    float last_angle = robotAngle;
    
    while (millis() - start_time < 15000) {  // 15 secondes
        float raw_gyro = readGyroZ();
        float corrected_gyro = raw_gyro - gyroOffset;
        
        update();
        
        Serial.print("Raw: "); Serial.print(raw_gyro, 2);
        Serial.print(" | Corrigé: "); Serial.print(corrected_gyro, 2);
        Serial.print("°/s | Angle: "); Serial.print(robotAngle, 1);
        Serial.print("° | Δ: "); Serial.println(robotAngle - last_angle, 2);
        
        last_angle = robotAngle;
        delay(200);
    }
    
    Serial.println("✅ Test terminé");
}

void MPU6500Handler::debugMPU6500() {
    Serial.println("🔍 DEBUG MPU-6500 DÉTAILLÉ");
    
    Serial.print("1. Connexion I2C (0x68): ");
    Wire.beginTransmission(MPU6500_ADDR);
    byte error = Wire.endTransmission(true);
    Serial.print("Erreur="); Serial.print(error);
    if (error == 0) Serial.println(" ✅ OK");
    else Serial.println(" ❌ Problème");
    
    Serial.print("2. WHO_AM_I: ");
    Wire.beginTransmission(MPU6500_ADDR);
    Wire.write(0x75);
    Wire.endTransmission(false);
    Wire.requestFrom(MPU6500_ADDR, 1, true);
    if (Wire.available()) {
        byte id = Wire.read();
        Serial.print("0x"); Serial.print(id, HEX);
        if (id == 0x70) Serial.println(" ✅ MPU-6500");
        else if (id == 0x68) Serial.println(" ✅ MPU-6050");
        else Serial.println(" ⚠️ Autre modèle");
    } else {
        Serial.println(" ❌ Pas de réponse");
    }
    
    Serial.println("3. Registres importants:");
    byte regs[] = {0x6B, 0x1B, 0x1C};
    String names[] = {"PWR_MGMT_1", "GYRO_CONFIG", "ACCEL_CONFIG"};
    
    for (int i = 0; i < 3; i++) {
        Wire.beginTransmission(MPU6500_ADDR);
        Wire.write(regs[i]);
        Wire.endTransmission(false);
        Wire.requestFrom(MPU6500_ADDR, 1, true);
        if (Wire.available()) {
            byte val = Wire.read();
            Serial.print("   "); Serial.print(names[i]); 
            Serial.print(" (0x"); Serial.print(regs[i], HEX);
            Serial.print("): 0x"); Serial.println(val, HEX);
        }
    }
    
    Serial.print("État gyroOK: "); Serial.println(gyroOK ? "true" : "false");
}

void MPU6500Handler::resetMPU6500() {
    Serial.println("🔄 RESET FORCÉ MPU-6500");
    
    Wire.beginTransmission(MPU6500_ADDR);
    Wire.write(0x6B);  // PWR_MGMT_1
    Wire.write(0x80);  // Device Reset
    Wire.endTransmission(true);
    
    delay(100);
    
    init();
    
    Serial.println("✅ Reset terminé");
}

void MPU6500Handler::scanI2C() {
    Serial.println("🔍 SCAN I2C - Recherche de tous les composants:");
    
    int devices = 0;
    for (byte addr = 1; addr < 127; addr++) {
        Wire.beginTransmission(addr);
        byte error = Wire.endTransmission();
        
        if (error == 0) {
            Serial.print("Composant trouvé à l'adresse 0x");
            if (addr < 16) Serial.print("0");
            Serial.print(addr, HEX);
            
            if (addr == 0x68) Serial.print(" (MPU-6500/6050)");
            else if (addr == 0x77) Serial.print(" (BMP280/BME280)");
            else Serial.print(" (Inconnu)");
            
            Serial.println();
            devices++;
        }
    }
    
    if (devices == 0) {
        Serial.println("❌ Aucun composant I2C trouvé");
    } else {
        Serial.print("✅ "); Serial.print(devices); Serial.println(" composant(s) trouvé(s)");
    }
}