// === CODE FINAL GPS + NAVIGATION AUTOMATIQUE + MOTEURS ===
// Basé sur TinyGPS++, commande "set" pour entrer cible en DMS, "go" pour navigation auto

#include <SoftwareSerial.h>
#include <TinyGPS++.h>
#include <math.h>

// GPS
static const int RXPin = A2;
static const int TXPin = A1;
static const uint32_t GPSBaud = 9600;
TinyGPSPlus gps;
SoftwareSerial gpsSerial(RXPin, TXPin);

// Moteurs
#define PWMA 5
#define PWMB 6
#define AIN 7
#define BIN 8
#define STBY 3

// Cible
double targetLat = 0.0;
double targetLng = 0.0;
bool targetSet = false;
bool navigating = false;

// === SETUP ===
void setup() {
  Serial.begin(9600);
  gpsSerial.begin(GPSBaud);

  pinMode(PWMA, OUTPUT);
  pinMode(PWMB, OUTPUT);
  pinMode(AIN, OUTPUT);
  pinMode(BIN, OUTPUT);
  pinMode(STBY, OUTPUT);
  stopMotors();

  Serial.println("Entrez :");
  Serial.println("- 'set 48\u00b050'20.3\"N,2\u00b018'44.2\"E'");
  Serial.println("- 'go' pour démarrer");
  Serial.println("- 'stop' pour arrêter");
}

// === LOOP ===
void loop() {
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
    if (gps.location.isUpdated()) {
      double lat = gps.location.lat();
      double lng = gps.location.lng();

      Serial.print("LAT: "); Serial.println(lat, 6);
      Serial.print("LONG: "); Serial.println(lng, 6);

      if (targetSet && navigating) {
        double dist = calculateDistance(lat, lng, targetLat, targetLng);
        double bearing = calculateBearing(lat, lng, targetLat, targetLng);
        Serial.print("Distance: "); Serial.println(dist);
        Serial.print("Direction: "); Serial.println(bearing);

        if (dist > 2.0) {
          goForward();
        } else {
          Serial.println("Arrivé à destination.");
          navigating = false;
          stopMotors();
        }
      } else {
        stopMotors();
      }
    }
  }

  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toLowerCase();
    processCommand(cmd);
  }
}

// === COMMANDES ===
void processCommand(String cmd) {
  if (cmd.startsWith("set ")) {
    String coords = cmd.substring(4);
    int comma = coords.indexOf(',');
    if (comma > 0) {
      String latStr = coords.substring(0, comma);
      String lngStr = coords.substring(comma + 1);
      targetLat = convertDMSToDecimal(latStr);
      targetLng = convertDMSToDecimal(lngStr);
      if (!isnan(targetLat) && !isnan(targetLng)) {
        targetSet = true;
        Serial.print("Cible en décimal: "); Serial.print(targetLat,6); Serial.print(", "); Serial.println(targetLng,6);
      } else {
        Serial.println("Erreur: format invalide.");
      }
    }
  }
  else if (cmd == "go") {
    if (targetSet) {
      navigating = true;
      Serial.println("Navigation activée");
    }
  }
  else if (cmd == "stop") {
    navigating = false;
    stopMotors();
    Serial.println("Navigation stoppée");
  }
  else {
    Serial.println("Commande inconnue.");
  }
}

// === CONVERSIONS ===
double convertDMSToDecimal(String dms) {
  dms.trim();
  int d = dms.indexOf('\u00b0');
  int m = dms.indexOf('\'');
  int s = dms.indexOf('"');
  char dir = dms.charAt(dms.length() - 1);

  if (d == -1 || m == -1 || s == -1) return NAN;

  double deg = dms.substring(0, d).toFloat();
  double min = dms.substring(d + 1, m).toFloat();
  double sec = dms.substring(m + 1, s).toFloat();

  double dec = deg + (min / 60.0) + (sec / 3600.0);
  if (dir == 'S' || dir == 'W') dec = -dec;

  return dec;
}

// === CALCUL GPS ===
double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double R = 6371000.0;
  double dLat = radians(lat2 - lat1);
  double dLng = radians(lng2 - lng1);
  double a = sin(dLat / 2) * sin(dLat / 2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
  double y = sin(radians(lng2 - lng1)) * cos(radians(lat2));
  double x = cos(radians(lat1)) * sin(radians(lat2)) - sin(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2 - lng1));
  return fmod(degrees(atan2(y, x)) + 360.0, 360.0);
}

// === CONTRÔLE DES MOTEURS ===
void goForward() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, 255);
  analogWrite(PWMB, 255);
  Serial.println(">>> AVANCE");
}

void stopMotors() {
  digitalWrite(STBY, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
  Serial.println(">>> STOP");
}
