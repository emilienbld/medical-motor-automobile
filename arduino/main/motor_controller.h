#ifndef MOTOR_CONTROLLER_H
#define MOTOR_CONTROLLER_H

#include <Arduino.h>
#include "config.h"

class MotorController {
private:
    int pwmA, pwmB, ain, bin, stby;
    unsigned long rotationStartTime;
    bool isRotating;
    
public:
    MotorController(int pwmA_pin, int pwmB_pin, int ain_pin, int bin_pin, int stby_pin);
    void init();
    void forward();
    void backward();
    void rotateLeft90();
    void rotateRight90();
    void forwardRight();
    void forwardLeft();
    void backwardRight();
    void backwardLeft();
    void stop();
    void checkRotationTimeout();
    bool getIsRotating() const;
    
    // Nouvelles méthodes pour navigation GPS
    void goForward();
    void turnRight(int speed);
    void turnLeft(int speed);
    void turnRight(); // Version sans paramètre (vitesse par défaut)
    void turnLeft();  // Version sans paramètre (vitesse par défaut)
    int calculateTurnSpeed(double angle_error);
    void testMotors();
};

#endif