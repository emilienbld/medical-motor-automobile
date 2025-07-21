#ifndef DISTANCE_SENSOR_H
#define DISTANCE_SENSOR_H

#include <Arduino.h>
#include "config.h"

class DistanceSensor {
private:
    int trigPin;
    int echoPin;
    float lastValidDistance;
    unsigned long lastMeasure;
    
public:
    DistanceSensor(int trig, int echo);
    void init();
    float measureDistance();
    bool updateDistance();
    float getLastValidDistance() const;
    bool isObstacleDetected(float threshold = OBSTACLE_DISTANCE_CM) const;
};

#endif