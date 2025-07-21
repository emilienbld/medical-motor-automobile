#ifndef SERVO_SCANNER_H
#define SERVO_SCANNER_H

#include <Arduino.h>
#include <Servo.h>
#include "config.h"
#include "distance_sensor.h"

class ServoScanner {
private:
    Servo scanServo;
    int currentAngle;
    int servoPin;
    DistanceSensor* distanceSensor;
    
public:
    ServoScanner(int pin, DistanceSensor* sensor);
    void init();
    void testScan();
    float scanDirection(int angle);
    bool checkLeftSafe(float threshold = OBSTACLE_DISTANCE_CM);
    bool checkRightSafe(float threshold = OBSTACLE_DISTANCE_CM);
    void returnToCenter();
    void fullScan();
    int getCurrentAngle() const;
};

#endif