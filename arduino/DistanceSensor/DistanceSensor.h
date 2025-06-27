// #ifndef DISTANCESENSOR_H
// #define DISTANCESENSOR_H

// class DistanceSensor {
//   public:
//     DistanceSensor(int trigPin, int echoPin);
//     void begin();
//     float getDistanceCM();

//   private:
//     int _trigPin;
//     int _echoPin;
// };

// #endif
#include <Servo.h>
Servo test;

void setup() {
  Serial.begin(115200);
  test.attach(10);
  Serial.println("DÉMARRAGE TEST SERVO SEUL");
}

void loop() {
  Serial.println("0°");
  test.write(0);
  delay(2000);
  
  Serial.println("90°");  
  test.write(90);
  delay(2000);
  
  Serial.println("180°");
  test.write(180);
  delay(2000);
}