#include "distance_sensor.h"

DistanceSensor::DistanceSensor(int trig, int echo) 
    : trigPin(trig), echoPin(echo), lastValidDistance(INVALID_DISTANCE), lastMeasure(0) {
}

void DistanceSensor::init() {
    pinMode(trigPin, OUTPUT);
    pinMode(echoPin, INPUT);
    Serial.println("✅ Capteur distance initialisé");
}

float DistanceSensor::measureDistance() {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    long duration = pulseIn(echoPin, HIGH, PULSE_TIMEOUT);
    
    if (duration > 0) {
        float distance = (duration * 0.034) / 2.0;
        if (distance <= MAX_VALID_DISTANCE) {
            return distance;
        }
    }
    return INVALID_DISTANCE;
}

bool DistanceSensor::updateDistance() {
    unsigned long now = millis();
    if (now - lastMeasure < MEASURE_INTERVAL) return false;
    
    float distance = measureDistance();
    
    Serial.print("🔍 Distance mesurée: ");
    Serial.print(distance);
    Serial.println(" cm");
    
    if (distance < INVALID_DISTANCE) {
        lastValidDistance = distance;
    }
    
    lastMeasure = now;
    return true;
}

float DistanceSensor::getLastValidDistance() const {
    return lastValidDistance;
}

bool DistanceSensor::isObstacleDetected(float threshold) const {
    return (lastValidDistance <= threshold && lastValidDistance > 0);
}