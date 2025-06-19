#include "Arduino.h"
#include "DistanceSensor.h"

DistanceSensor::DistanceSensor(int trigPin, int echoPin) {
  _trigPin = trigPin;
  _echoPin = echoPin;
}

void DistanceSensor::begin() {
  pinMode(_trigPin, OUTPUT);
  pinMode(_echoPin, INPUT);
}

float DistanceSensor::getDistanceCM() {
  // Envoi d'une impulsion de 10 µs
  digitalWrite(_trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(_trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(_trigPin, LOW);

  // Lecture du temps aller-retour
  long duration = pulseIn(_echoPin, HIGH);

  // Calcul de la distance en cm
  float distance = (duration * 0.034) / 2.0;

  return distance;
}
