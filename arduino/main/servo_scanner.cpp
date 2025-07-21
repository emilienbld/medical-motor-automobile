#include "servo_scanner.h"

ServoScanner::ServoScanner(int pin, DistanceSensor* sensor) 
    : servoPin(pin), currentAngle(SERVO_CENTER), distanceSensor(sensor) {
}

void ServoScanner::init() {
    Serial.println("🤖 Initialisation servo...");
    scanServo.attach(servoPin);
    scanServo.write(SERVO_CENTER);
    currentAngle = SERVO_CENTER;
    delay(SERVO_DELAY);
    Serial.println("✅ Servo attaché sur pin " + String(servoPin));
}

void ServoScanner::testScan() {
    Serial.println("\n🔄 Test scan 180°:");
    for(int angle = SERVO_RIGHT; angle <= SERVO_LEFT; angle += 30) {
        scanDirection(angle);
        delay(500);
    }
    returnToCenter();
    Serial.println("✅ Servo scanner opérationnel !");
}

float ServoScanner::scanDirection(int angle) {
    angle = constrain(angle, SERVO_MIN, SERVO_MAX);
    
    Serial.print("🔄 Rotation servo vers ");
    Serial.print(angle);
    Serial.print("°...");
    
    scanServo.write(angle);
    currentAngle = angle;
    delay(SERVO_DELAY);
    
    float distance = distanceSensor->measureDistance();
    
    Serial.print(" Distance: ");
    Serial.print(distance);
    Serial.println(" cm");
    
    return distance;
}

bool ServoScanner::checkLeftSafe(float threshold) {
    Serial.println("👈 Scan GAUCHE (150°)");
    float leftDistance = scanDirection(SERVO_LEFT);
    bool safe = (leftDistance > threshold);
    
    Serial.print("   Gauche ");
    Serial.print(safe ? "✅ LIBRE" : "❌ BLOQUÉ");
    Serial.print(" (");
    Serial.print(leftDistance);
    Serial.println(" cm)");
    
    return safe;
}

bool ServoScanner::checkRightSafe(float threshold) {
    Serial.println("👉 Scan DROITE (30°)");
    float rightDistance = scanDirection(SERVO_RIGHT);
    bool safe = (rightDistance > threshold);
    
    Serial.print("   Droite ");
    Serial.print(safe ? "✅ LIBRE" : "❌ BLOQUÉ");
    Serial.print(" (");
    Serial.print(rightDistance);
    Serial.println(" cm)");
    
    return safe;
}

void ServoScanner::returnToCenter() {
    if (currentAngle != SERVO_CENTER) {
        Serial.println("🎯 Retour au centre (90°)");
        scanServo.write(SERVO_CENTER);
        currentAngle = SERVO_CENTER;
        delay(SERVO_DELAY);
    }
}

void ServoScanner::fullScan() {
    Serial.println(" -> SCAN 180°");
    for(int angle = SERVO_RIGHT; angle <= SERVO_LEFT; angle += 30) {
        scanDirection(angle);
        delay(300);
    }
    returnToCenter();
}

int ServoScanner::getCurrentAngle() const {
    return currentAngle;
}