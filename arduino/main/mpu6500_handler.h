#ifndef MPU6500_HANDLER_H
#define MPU6500_HANDLER_H

#include <Arduino.h>
#include <Wire.h>
#include "config.h"

class MPU6500Handler {
private:
    float gyroOffset;
    float robotAngle;
    unsigned long lastGyroTime;
    bool gyroOK;
    
    float readGyroZ() const;
    static double normalizeAngle(double angle);
    static double normalizeAngleDiff(double angle_diff);
    
public:
    MPU6500Handler();
    void init();
    void update();
    void calibrate();
    bool isGyroOK() const;
    float getRobotAngle() const;
    float getRotationSpeed() const;
    void resetAngle();
    
    // Fonctions de test et diagnostic
    void testGyroscope();
    void testGyroLive();
    void debugMPU6500();
    void resetMPU6500();
    void scanI2C();
    
    // Utilitaires d'angle
    static double normalizeAnglePublic(double angle);
    static double normalizeAngleDiffPublic(double angle_diff);
};

#endif