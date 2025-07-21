#ifndef NAVIGATION_CONTROLLER_H
#define NAVIGATION_CONTROLLER_H

#include <Arduino.h>
#include "config.h"
#include "gps_handler.h"
#include "mpu6500_handler.h"
#include "motor_controller.h"

class NavigationController {
private:
    GPSHandler* gpsHandler;
    MPU6500Handler* mpuHandler;
    MotorController* motorController;
    
    // Variables de navigation
    double targetLat, targetLng;
    bool targetSet;
    bool navigating;
    
    void navigate();
    
public:
    NavigationController(GPSHandler* gps, MPU6500Handler* mpu, MotorController* motor);
    void init();
    void update();
    void handleCommands();
    
    // Commandes de navigation
    void setTarget(String coords);
    void startNavigation();
    void stopNavigation();
    void printStatus();
    
    // Tests
    void testTurning();
    void testSpeedMapping();
    
    // Getters
    bool isNavigating() const;
    bool isTargetSet() const;
};

#endif