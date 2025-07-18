#include "DistanceSensor.h"

// Définition des broches
const int trigPin = 13;
const int echoPin = 12;

// Instanciation de l'objet capteur
DistanceSensor capteur(trigPin, echoPin);

void setup() {
  Serial.begin(9600);
  capteur.begin();
}

void loop() {
  float distance = capteur.getDistanceCM();
  Serial.print("Distance : ");
  Serial.print(distance);
  Serial.println(" cm");
  delay(500);
}
