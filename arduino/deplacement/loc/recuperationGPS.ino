#include <SoftwareSerial.h>
#include <TinyGPS++.h>
#include <math.h>

static const int RXPin = A2;
static const int TXPin = A1;
static const uint32_t GPSBaud = 9600;

TinyGPSPlus gps;
SoftwareSerial gpsSerial(RXPin, TXPin);

// Coordonnées cibles en décimal
double targetLat = 0.0;
double targetLng = 0.0;
bool targetSet = false;

void setup() {
  Serial.begin(9600);
  gpsSerial.begin(GPSBaud);
  Serial.println("Software Serial started at 9600 baud rate");
  Serial.println("Commandes disponibles:");
  Serial.println("- 'set 48°50'20.3\"N,2°18'44.2\"E' pour définir une cible");
  Serial.println("- 'clear' pour effacer la cible");
  Serial.println("- 'target' pour afficher la cible actuelle");
  Serial.println("");
}

void loop() {
  while (gpsSerial.available() > 0){
    gps.encode(gpsSerial.read());
    if (gps.location.isUpdated()) {
      Serial.print("LAT: ");
      Serial.println(gps.location.lat(), 6);
      Serial.print("LONG: "); 
      Serial.println(gps.location.lng(), 6);
      Serial.print("SPEED (km/h) = "); 
      Serial.println(gps.speed.kmph()); 
      Serial.print("ALT (m)= "); 
      Serial.println(gps.altitude.meters());
      Serial.print("HDOP = "); 
      Serial.println(gps.hdop.value() / 100.0); 
      Serial.print("Satellites = "); 
      Serial.println(gps.satellites.value()); 
      Serial.print("Time in UTC: ");
      Serial.println(String(gps.date.year()) + "/" + String(gps.date.month()) + "/" + String(gps.date.day()) + "," + String(gps.time.hour()) + ":" + String(gps.time.minute()) + ":" + String(gps.time.second()));
      
      if (targetSet && gps.location.isValid()) {
        double distance = calculateDistance(gps.location.lat(), gps.location.lng(), targetLat, targetLng);
        Serial.print("Distance vers cible: ");
        Serial.print(distance, 2);
        Serial.println(" mètres");

        double bearing = calculateBearing(gps.location.lat(), gps.location.lng(), targetLat, targetLng);
        Serial.print("Direction vers cible: ");
        Serial.print(bearing, 1);
        Serial.println(" degrés");
      }

      Serial.println("");
    }
  }

  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    processCommand(command);
  }
}

void processCommand(String command) {
  command.trim();
  command.toLowerCase();

  if (command.startsWith("set ")) {
    String coords = command.substring(4);
    int commaIndex = coords.indexOf(',');
    
    if (commaIndex > 0) {
      String latStr = coords.substring(0, commaIndex);
      String lngStr = coords.substring(commaIndex + 1);
      latStr.trim(); lngStr.trim();

      // Conversion DMS → décimal
      targetLat = dmsToDecimal(latStr);
      targetLng = dmsToDecimal(lngStr);

      if (targetLat != 0.0 || targetLng != 0.0) {
        targetSet = true;
        Serial.print("Coordonnées cibles définies (décimal): ");
        Serial.print(targetLat, 6);
        Serial.print(", ");
        Serial.println(targetLng, 6);
      } else {
        Serial.println("Erreur: coordonnées invalides");
      }
    } else {
      Serial.println("Erreur: format incorrect. Utilisez 'set lat,lng'");
    }
  }
  else if (command == "clear") {
    targetSet = false;
    targetLat = 0.0;
    targetLng = 0.0;
    Serial.println("Coordonnées cibles effacées");
  }
  else if (command == "target") {
    if (targetSet) {
      Serial.print("Coordonnées cibles actuelles: ");
      Serial.print(targetLat, 6);
      Serial.print(", ");
      Serial.println(targetLng, 6);
    } else {
      Serial.println("Aucune coordonnée cible définie");
    }
  }
  else {
    Serial.println("Commande inconnue. Utilisez 'set lat,lng', 'clear' ou 'target'");
  }
}

// Convertit une chaîne DMS comme 48°50'20.3"N en décimal
double dmsToDecimal(String dms) {
  dms.trim();

  int degIndex = dms.indexOf('°');
  int minIndex = dms.indexOf('\'');
  int secIndex = dms.indexOf('\"');

  if (degIndex == -1 || minIndex == -1 || secIndex == -1) {
    return 0.0;
  }

  int deg = dms.substring(0, degIndex).toInt();
  int min = dms.substring(degIndex + 1, minIndex).toInt();
  double sec = dms.substring(minIndex + 1, secIndex).toFloat();
  char hemisphere = dms.charAt(dms.length() - 1);

  double decimal = deg + (min / 60.0) + (sec / 3600.0);
  if (hemisphere == 'S' || hemisphere == 'W') {
    decimal = -decimal;
  }

  return decimal;
}

// Distance en mètres via la formule de Haversine
double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double R = 6371000;

  double lat1Rad = radians(lat1);
  double lat2Rad = radians(lat2);
  double deltaLatRad = radians(lat2 - lat1);
  double deltaLngRad = radians(lng2 - lng1);

  double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
             cos(lat1Rad) * cos(lat2Rad) *
             sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

// Azimut (direction en degrés)
double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
  double lat1Rad = radians(lat1);
  double lat2Rad = radians(lat2);
  double deltaLngRad = radians(lng2 - lng1);

  double y = sin(deltaLngRad) * cos(lat2Rad);
  double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);

  double bearingRad = atan2(y, x);
  double bearingDeg = degrees(bearingRad);

  return fmod(bearingDeg + 360.0, 360.0);
}
