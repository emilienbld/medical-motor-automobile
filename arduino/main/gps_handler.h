#ifndef GPS_HANDLER_H
#define GPS_HANDLER_H

#include <Arduino.h>
#include <SoftwareSerial.h>
#include <TinyGPS++.h>
#include "config.h"

class GPSHandler {
private:
    TinyGPSPlus gps;
    SoftwareSerial* gpsSerial;
    double currentLat, currentLng;
    bool positionValid;
    
public:
    GPSHandler();
    ~GPSHandler();
    void init();
    void update();
    bool isPositionValid() const;
    double getCurrentLatitude() const;
    double getCurrentLongitude() const;
    void printPosition() const;
    
    // Calculs géographiques statiques
    static double calculateDistance(double lat1, double lng1, double lat2, double lng2);
    static double calculateBearing(double lat1, double lng1, double lat2, double lng2);
    static double parseDMS(String dms);
};

#endif