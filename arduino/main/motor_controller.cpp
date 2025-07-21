#include "motor_controller.h"

MotorController::MotorController(int pwmA_pin, int pwmB_pin, int ain_pin, int bin_pin, int stby_pin) 
    : pwmA(pwmA_pin), pwmB(pwmB_pin), ain(ain_pin), bin(bin_pin), stby(stby_pin), 
      rotationStartTime(0), isRotating(false) {
}

void MotorController::init() {
    pinMode(pwmA, OUTPUT);
    pinMode(pwmB, OUTPUT);
    pinMode(ain, OUTPUT);
    pinMode(bin, OUTPUT);
    pinMode(stby, OUTPUT);
    
    digitalWrite(stby, LOW);
    stop();
    Serial.println("✅ Contrôleur moteur initialisé");
}

void MotorController::forward() {
    isRotating = false;
    digitalWrite(stby, HIGH);
    digitalWrite(ain, HIGH);
    digitalWrite(bin, HIGH);
    analogWrite(pwmA, MOTOR_SPEED_NORMAL);
    analogWrite(pwmB, MOTOR_SPEED_NORMAL);
}

void MotorController::backward() {
    isRotating = false;
    digitalWrite(stby, HIGH);
    digitalWrite(ain, LOW);
    digitalWrite(bin, LOW);
    analogWrite(pwmA, MOTOR_SPEED_NORMAL);
    analogWrite(pwmB, MOTOR_SPEED_NORMAL);
}

void MotorController::rotateLeft90() {
    isRotating = true;
    rotationStartTime = millis();
    digitalWrite(stby, HIGH);
    digitalWrite(ain, HIGH);
    digitalWrite(bin, LOW);
    analogWrite(pwmA, MOTOR_SPEED_TURN);
    analogWrite(pwmB, MOTOR_SPEED_TURN);
}

void MotorController::rotateRight90() {
    isRotating = true;
    rotationStartTime = millis();
    digitalWrite(stby, HIGH);
    digitalWrite(ain, LOW);
    digitalWrite(bin, HIGH);
    analogWrite(pwmA, MOTOR_SPEED_TURN);
    analogWrite(pwmB, MOTOR_SPEED_TURN);
}

void MotorController::forwardRight() {
    isRotating = false;
    digitalWrite(stby, HIGH);
    digitalWrite(ain, HIGH);
    digitalWrite(bin, HIGH);
    analogWrite(pwmA, MOTOR_SPEED_CURVE);
    analogWrite(pwmB, MOTOR_SPEED_NORMAL);
}

void MotorController::forwardLeft() {
    isRotating = false;
    digitalWrite(stby, HIGH);
    digitalWrite(ain, HIGH);
    digitalWrite(bin, HIGH);
    analogWrite(pwmA, MOTOR_SPEED_NORMAL);
    analogWrite(pwmB, MOTOR_SPEED_CURVE);
}

void MotorController::backwardRight() {
    isRotating = false;
    digitalWrite(stby, HIGH);
    digitalWrite(ain, LOW);
    digitalWrite(bin, LOW);
    analogWrite(pwmA, MOTOR_SPEED_CURVE);
    analogWrite(pwmB, MOTOR_SPEED_NORMAL);
}

void MotorController::backwardLeft() {
    isRotating = false;
    digitalWrite(stby, HIGH);
    digitalWrite(ain, LOW);
    digitalWrite(bin, LOW);
    analogWrite(pwmA, MOTOR_SPEED_NORMAL);
    analogWrite(pwmB, MOTOR_SPEED_CURVE);
}

void MotorController::stop() {
    analogWrite(pwmA, 0);
    analogWrite(pwmB, 0);
    digitalWrite(stby, LOW);
}

void MotorController::checkRotationTimeout() {
    if (isRotating && (millis() - rotationStartTime >= ROTATION_90_DURATION)) {
        stop();
        isRotating = false;
    }
}

bool MotorController::getIsRotating() const {
    return isRotating;
}

// === NOUVELLES MÉTHODES POUR NAVIGATION GPS ===

void MotorController::goForward() {
    forward(); // Utilise la méthode existante
}

void MotorController::turnRight(int speed) {
    isRotating = false; // Les rotations GPS ne sont pas limitées dans le temps
    digitalWrite(stby, HIGH);
    digitalWrite(ain, HIGH);   // Moteur A en avant
    digitalWrite(bin, LOW);    // Moteur B en arrière
    analogWrite(pwmA, speed);
    analogWrite(pwmB, speed);
}

void MotorController::turnLeft(int speed) {
    isRotating = false; // Les rotations GPS ne sont pas limitées dans le temps
    digitalWrite(stby, HIGH);
    digitalWrite(ain, LOW);    // Moteur A en arrière
    digitalWrite(bin, HIGH);   // Moteur B en avant
    analogWrite(pwmA, speed);
    analogWrite(pwmB, speed);
}

void MotorController::turnRight() {
    turnRight(MIN_TURN_SPEED + 30);  // Vitesse par défaut
}

void MotorController::turnLeft() {
    turnLeft(MIN_TURN_SPEED + 30);   // Vitesse par défaut
}

int MotorController::calculateTurnSpeed(double angle_error) {
    // Calculer la vitesse en fonction de l'angle à tourner
    double abs_error = abs(angle_error);
    int speed;
    
    if (abs_error <= 8) {
        speed = MIN_TURN_SPEED;
    } else if (abs_error <= 20) {
        speed = map(abs_error, 8, 20, MIN_TURN_SPEED, MIN_TURN_SPEED + 25);
    } else if (abs_error <= 45) {
        speed = map(abs_error, 20, 45, MIN_TURN_SPEED + 25, MIN_TURN_SPEED + 50);
    } else {
        speed = MAX_TURN_SPEED;
    }
    
    return constrain(speed, MIN_TURN_SPEED, MAX_TURN_SPEED);
}

void MotorController::testMotors() {
    Serial.println("🔧 Test moteurs:");
    Serial.println("   Avance 2s...");
    goForward();
    delay(2000);
    Serial.println("   Tourne droite 1s...");
    turnRight();
    delay(1000);
    Serial.println("   Tourne gauche 1s...");
    turnLeft();
    delay(1000);
    stop();
    Serial.println("✅ Test terminé");
}