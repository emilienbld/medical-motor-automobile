#ifndef ROBOT_CONTROLLER_H
#define ROBOT_CONTROLLER_H

#include <Arduino.h>
#include "config.h"
#include "distance_sensor.h"
#include "servo_scanner.h"
#include "motor_controller.h"
#include "gps_handler.h"
#include "mpu6500_handler.h"
#include "navigation_controller.h"

class RobotController {
private:
    // Composants évitement d'obstacles
    DistanceSensor distanceSensor;
    ServoScanner servoScanner;
    MotorController motorController;
    bool obstacleDetected;
    
    // Composants navigation GPS
    GPSHandler gpsHandler;
    MPU6500Handler mpuHandler;
    NavigationController navigationController;
    
   
    
    void executeMovement(String cmd);
    bool checkMovementSafety(String cmd);
    
public:
    RobotController();
    void init();
    void update();
    void handleSerialCommand();
    bool processMovementCommand(String cmd);
    
    // Getters pour WiFi (obstacle avoidance)
    float getDistance() const;
    bool isObstacleDetected() const;
    
    // Getters pour navigation GPS
    bool isGPSValid() const;
    double getGPSLatitude() const;
    double getGPSLongitude() const;
    bool isGyroOK() const;
    float getRobotAngle() const;
    bool isNavigating() const;
    
    // Getters pour caméra
    bool isCameraOK() const;
    
    // Accès aux composants si nécessaire
    DistanceSensor& getDistanceSensor() { return distanceSensor; }
    ServoScanner& getServoScanner() { return servoScanner; }
    MotorController& getMotorController() { return motorController; }
    GPSHandler& getGPSHandler() { return gpsHandler; }
    MPU6500Handler& getMPUHandler() { return mpuHandler; }
    NavigationController& getNavigationController() { return navigationController; }
};

#endif