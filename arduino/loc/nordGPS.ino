// === CODE FINAL GPS + NAVIGATION AUTOMATIQUE + MOTEURS ===
// Basé sur TinyGPS++, commande "set" pour entrer cible en DMS, "go" pour navigation auto
// Navigation par vecteurs GPS avec correction de trajectoire

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

// Cible et navigation
double targetLat = 0.0;
double targetLng = 0.0;
bool targetSet = false;
bool navigating = false;

// Variables pour la navigation par vecteurs
double lastLat = 0.0;
double lastLng = 0.0;
double currentHeading = 0.0;  // Direction actuelle du robot
bool hasLastPosition = false;
unsigned long lastGPSTime = 0;

// Paramètres de navigation
const double ARRIVAL_THRESHOLD = 2.0;  // Distance d'arrivée en mètres
const double MIN_SPEED = 100;  // Vitesse minimale PWM
const double MAX_SPEED = 255;  // Vitesse maximale PWM
const double TURN_THRESHOLD = 30.0;  // Seuil d'angle pour tourner (degrés)

// Déclarations des fonctions
void goForward(int speed);
void goForward();
void turnLeft();
void turnRight();
void stopMotors();
void navigateToTarget(double targetBearing, double distance);
void processCommand(String cmd);
double convertDMSToDecimal(String dms);
double calculateDistance(double lat1, double lng1, double lat2, double lng2);
double calculateBearing(double lat1, double lng1, double lat2, double lng2);

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
  Serial.println("- 'set 48°50'20.3\"N,2°18'44.2\"E'");
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

      // Calculer la direction actuelle du robot si on a une position précédente
      if (hasLastPosition && (millis() - lastGPSTime > 1000)) {
        currentHeading = calculateBearing(lastLat, lastLng, lat, lng);
        Serial.print("Direction robot: "); Serial.println(currentHeading);
      }

      if (targetSet && navigating) {
        double dist = calculateDistance(lat, lng, targetLat, targetLng);
        double bearingToTarget = calculateBearing(lat, lng, targetLat, targetLng);
        
        Serial.print("Distance: "); Serial.print(dist); Serial.println(" m");
        Serial.print("Direction cible: "); Serial.print(bearingToTarget); Serial.println("°");

        if (dist > ARRIVAL_THRESHOLD) {
          // Navigation par vecteurs GPS
          Serial.println("--- Début navigation ---");
          navigateToTarget(bearingToTarget, dist);
          Serial.println("--- Fin navigation ---");
        } else {
          Serial.println("Arrivé à destination.");
          navigating = false;
          stopMotors();
        }
      } else if (navigating) {
        Serial.println("Navigation active mais pas de cible ou pas de signal GPS");
        stopMotors();
      }

      // Sauvegarder la position pour le calcul de direction
      lastLat = lat;
      lastLng = lng;
      hasLastPosition = true;
      lastGPSTime = millis();
    }
  }

  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toLowerCase();
    processCommand(cmd);
  }
}

// === NAVIGATION PAR VECTEURS ===
void navigateToTarget(double targetBearing, double distance) {
  Serial.print("Navigation - hasLastPosition: "); Serial.println(hasLastPosition);
  
  if (!hasLastPosition) {
    // Si on n'a pas encore de direction, avancer doucement pour établir une direction
    Serial.println("Pas de direction établie, avance pour calculer direction");
    goForward(MIN_SPEED);
    return;
  }

  // Calculer la différence d'angle entre direction actuelle et direction cible
  double angleDiff = targetBearing - currentHeading;
  
  // Normaliser l'angle entre -180 et 180
  while (angleDiff > 180) angleDiff -= 360;
  while (angleDiff < -180) angleDiff += 360;

  Serial.print("Direction robot: "); Serial.println(currentHeading);
  Serial.print("Direction cible: "); Serial.println(targetBearing);
  Serial.print("Diff angle: "); Serial.println(angleDiff);

  // Décider de l'action à prendre
  if (abs(angleDiff) < TURN_THRESHOLD) {
    // Direction OK, avancer
    int speed = map(constrain(distance, 2, 50), 2, 50, MIN_SPEED, MAX_SPEED);
    Serial.print("Avance avec vitesse: "); Serial.println(speed);
    goForward(speed);
  } else if (angleDiff > 0) {
    // Tourner à droite
    Serial.println("Tourne à droite");
    turnRight();
  } else {
    // Tourner à gauche
    Serial.println("Tourne à gauche");
    turnLeft();
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
      hasLastPosition = false;  // Reset pour recalculer la direction
      Serial.println("Navigation activée");
      Serial.print("Cible: "); Serial.print(targetLat, 6); Serial.print(", "); Serial.println(targetLng, 6);
    } else {
      Serial.println("Aucune cible définie. Utilisez 'set' d'abord.");
    }
  }
  else if (cmd == "stop") {
    navigating = false;
    stopMotors();
    Serial.println("Navigation stoppée");
  }

  else if (cmd == "test") {
    Serial.println("Test moteurs:");
    goForward(150);
    delay(2000);
    stopMotors();
  }
  else if (cmd == "testleft") {
    Serial.println("Test rotation gauche:");
    turnLeft();
    stopMotors();
  }
  else if (cmd == "testright") {
    Serial.println("Test rotation droite:");
    turnRight();
    stopMotors();
  }
  
  else {
    Serial.println("Commande inconnue.");
  }
}

// === CONVERSIONS ===
double convertDMSToDecimal(String dms) {
  dms.trim();
  int d = dms.indexOf('°');
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
  analogWrite(PWMA, MAX_SPEED);
  analogWrite(PWMB, MAX_SPEED);
  Serial.println(">>> AVANCE");
}

void goForward(int speed) {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, speed);
  analogWrite(PWMB, speed);
  Serial.print(">>> AVANCE ("); Serial.print(speed); Serial.println(")");
}

void turnLeft() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);   // Moteur A en arrière
  digitalWrite(BIN, HIGH);  // Moteur B en avant
  analogWrite(PWMA, MIN_SPEED);
  analogWrite(PWMB, MIN_SPEED);
  Serial.println(">>> TOURNE GAUCHE");
  delay(500);  // Ajustez selon votre robot
}

void turnRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);  // Moteur A en avant
  digitalWrite(BIN, LOW);   // Moteur B en arrière
  analogWrite(PWMA, MIN_SPEED);
  analogWrite(PWMB, MIN_SPEED);
  Serial.println(">>> TOURNE DROITE");
  delay(500);  // Ajustez selon votre robot
}

void stopMotors() {
  digitalWrite(STBY, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
  Serial.println(">>> STOP");
}