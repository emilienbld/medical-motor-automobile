#include "gps_handler.h"
#include <math.h>

GPSHandler::GPSHandler() 
    : currentLat(0.0), currentLng(0.0), positionValid(false) {
    gpsSerial = new SoftwareSerial(GPS_RX_PIN, GPS_TX_PIN);
}

GPSHandler::~GPSHandler() {
    delete gpsSerial;
}

void GPSHandler::init() {
    gpsSerial->begin(GPS_BAUD);
    Serial.println("✅ GPS initialisé");
}

void GPSHandler::update() {
    while (gpsSerial->available() > 0) {
        if (gps.encode(gpsSerial->read())) {
            if (gps.location.isValid()) {
                currentLat = gps.location.lat();
                currentLng = gps.location.lng();
                positionValid = true;
            }
        }
    }
}

bool GPSHandler::isPositionValid() const {
    return positionValid;
}

double GPSHandler::getCurrentLatitude() const {
    return currentLat;
}

double GPSHandler::getCurrentLongitude() const {
    return currentLng;
}

void GPSHandler::printPosition() const {
    if (positionValid) {
        Serial.print("GPS: ");
        Serial.print(currentLat, 6);
        Serial.print(", ");
        Serial.println(currentLng, 6);
    }
}

double GPSHandler::calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Formule de Haversine pour calculer la distance entre 2 points GPS
    const double R = 6371000.0; // Rayon de la Terre en mètres
    
    double dLat = (lat2 - lat1) * PI / 180.0;
    double dLng = (lng2 - lng1) * PI / 180.0;
    
    double a = sin(dLat/2) * sin(dLat/2) + 
               cos(lat1 * PI / 180.0) * cos(lat2 * PI / 180.0) * 
               sin(dLng/2) * sin(dLng/2);
               
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return R * c; // Distance en mètres
}

double GPSHandler::calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    // Calcule la direction (bearing) du point 1 vers le point 2
    double dLng = (lng2 - lng1) * PI / 180.0;
    
    double y = sin(dLng) * cos(lat2 * PI / 180.0);
    double x = cos(lat1 * PI / 180.0) * sin(lat2 * PI / 180.0) - 
               sin(lat1 * PI / 180.0) * cos(lat2 * PI / 180.0) * cos(dLng);
               
    double bearing = atan2(y, x) * 180.0 / PI;
    
    // Normaliser entre 0-360°
    while (bearing >= 360.0) bearing -= 360.0;
    while (bearing < 0.0) bearing += 360.0;
    
    return bearing;
}

double GPSHandler::parseDMS(String dms) {
    // Parse "48°50'18"N" vers décimal
    dms.trim();
    
    int deg_pos = dms.indexOf('°');
    int min_pos = dms.indexOf('\'');
    int sec_pos = dms.indexOf('"');
    
    if (deg_pos == -1 || min_pos == -1 || sec_pos == -1) return NAN;
    
    double degrees = dms.substring(0, deg_pos).toFloat();
    double minutes = dms.substring(deg_pos + 1, min_pos).toFloat();
    double seconds = dms.substring(min_pos + 1, sec_pos).toFloat();
    
    double decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);
    
    // Vérifier la direction (N/S pour latitude, E/W pour longitude)
    char direction = dms.charAt(dms.length() - 1);
    if (direction == 'S' || direction == 'W') {
        decimal = -decimal;
    }
    
    return decimal;
}