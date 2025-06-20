// === CODE GPS ROBOT NAVIGATION AMÉLIORE ===
// Navigation GPS sans boussole avec phase d'exploration
// Amélioration de la logique de navigation et gestion des états

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
double initialLat = 0.0;
double initialLng = 0.0;
double currentHeading = 0.0;  // Direction actuelle du robot
bool hasLastPosition = false;
bool hasInitialPosition = false;
unsigned long lastGPSTime = 0;
unsigned long navigationStartTime = 0;

// États de navigation
enum NavigationState {
  IDLE,
  EXPLORING,      // Phase d'exploration initiale
  CORRECTING,     // Phase de correction de trajectoire
  NAVIGATING      // Navigation directe vers la cible
};

NavigationState navState = IDLE;
double lastDistance = 0.0;
double explorationHeading = 0.0;
unsigned long lastMovementTime = 0;

// Paramètres de navigation
const double ARRIVAL_THRESHOLD = 3.0;     // Distance d'arrivée en mètres
const double MIN_SPEED = 120;             // Vitesse minimale PWM
const double MAX_SPEED = 200;             // Vitesse maximale PWM
const double EXPLORATION_SPEED = 130;     // Vitesse d'exploration
const double TURN_THRESHOLD = 25.0;       // Seuil d'angle pour tourner (degrés)
const double MIN_MOVEMENT_DISTANCE = 1.0; // Distance minimale pour détecter un mouvement
const unsigned long EXPLORATION_TIME = 3000; // Temps d'exploration en ms
const unsigned long TURN_TIME = 800;      // Temps de rotation en ms

// Déclarations des fonctions
void goForward(int speed);
void goForward();
void turnLeft();
void turnRight();
void stopMotors();
void navigateToTarget();
void processCommand(String cmd);
double convertDMSToDecimal(String dms);
double calculateDistance(double lat1, double lng1, double lat2, double lng2);
double calculateBearing(double lat1, double lng1, double lat2, double lng2);
void printNavigationState();

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

  Serial.println("=== ROBOT GPS NAVIGATION ===");
  Serial.println("Commandes disponibles :");
  Serial.println("- 'set 48°50'20.3\"N,2°18'44.2\"E' : Définir coordonnées cible");
  Serial.println("- 'go' : Démarrer la navigation");
  Serial.println("- 'stop' : Arrêter la navigation");
  Serial.println("- 'status' : Afficher l'état actuel");
  Serial.println("- 'test' : Test moteurs");
  Serial.println("=============================");
}


const float DISTANCE_SEUIL_CAP = 2.5; // en mètres


// === LOOP ===
void loop() {
  // Lecture GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
    if (gps.location.isUpdated()) {
      double lat = gps.location.lat();
      double lng = gps.location.lng();

      Serial.print("GPS: LAT="); Serial.print(lat, 6);
      Serial.print(" LONG="); Serial.println(lng, 6);

      // Première position GPS
      if (!hasInitialPosition) {
        initialLat = lat;
        initialLng = lng;
        hasInitialPosition = true;
        Serial.println("Position initiale enregistrée");
      }

      // Calcul du mouvement si on a une position précédente
      if (hasLastPosition) {
        double movementDistance = calculateDistance(lastLat, lastLng, lat, lng);
        if (movementDistance > MIN_MOVEMENT_DISTANCE) {
          currentHeading = calculateBearing(lastLat, lastLng, lat, lng);
          Serial.print("Mouvement détecté - Distance: "); Serial.print(movementDistance, 1);
          Serial.print("m, Cap: "); Serial.print(currentHeading, 1); Serial.println("°");
          lastMovementTime = millis();
        }
      }

      // Navigation si activée
      if (targetSet && navigating) {
        navigateToTarget();
      }

      // Sauvegarder la position
      lastLat = lat;
      lastLng = lng;
      hasLastPosition = true;
      lastGPSTime = millis();
    }
  }

  // Commandes série
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toLowerCase();
    processCommand(cmd);
  }

  // Timeout pour arrêter les moteurs si pas de GPS
  if (navigating && (millis() - lastGPSTime > 5000)) {
    Serial.println("ATTENTION: Pas de signal GPS depuis 5s - Arrêt sécuritaire");
    stopMotors();
  }
}

// === NAVIGATION INTELLIGENTE ===
void navigateToTarget() {
  if (!gps.location.isValid()) return;

  double currentLat = gps.location.lat();
  double currentLng = gps.location.lng();
  double distanceToTarget = calculateDistance(currentLat, currentLng, targetLat, targetLng);
  double bearingToTarget = calculateBearing(currentLat, currentLng, targetLat, targetLng);

  Serial.print("Distance cible: "); Serial.print(distanceToTarget, 1); Serial.print("m");
  Serial.print(" - Direction cible: "); Serial.print(bearingToTarget, 1); Serial.println("°");

  // Vérification d'arrivée
  if (distanceToTarget <= ARRIVAL_THRESHOLD) {
    Serial.println("🎯 ARRIVÉ À DESTINATION!");
    navigating = false;
    navState = IDLE;
    stopMotors();
    return;
  }

  // Machine à états pour la navigation
  switch (navState) {
    case IDLE:
      // Démarrage de la navigation
      navState = EXPLORING;
      navigationStartTime = millis();
      lastDistance = distanceToTarget;
      Serial.println("🔍 PHASE EXPLORATION - Avance pour déterminer l'orientation");
      goForward(EXPLORATION_SPEED);
      break;

    case EXPLORING:
      // Phase d'exploration - avancer pour comprendre l'orientation
      if (millis() - navigationStartTime > EXPLORATION_TIME) {
        if (hasLastPosition && (millis() - lastMovementTime < 2000)) {
          // On a détecté un mouvement, analyser la direction
          explorationHeading = currentHeading;
          
          // Calculer l'erreur d'angle
          double angleDiff = bearingToTarget - explorationHeading;
          while (angleDiff > 180) angleDiff -= 360;
          while (angleDiff < -180) angleDiff += 360;

          Serial.print("🧭 Direction actuelle: "); Serial.print(explorationHeading, 1);
          Serial.print("° - Erreur: "); Serial.print(angleDiff, 1); Serial.println("°");

          if (abs(angleDiff) < TURN_THRESHOLD) {
            // Direction correcte, continuer tout droit
            navState = NAVIGATING;
            Serial.println("✅ Direction correcte - Navigation directe");
          } else {
            // Correction nécessaire
            navState = CORRECTING;
            Serial.print("🔄 Correction nécessaire - Rotation ");
            Serial.println(angleDiff > 0 ? "droite" : "gauche");
            
            if (angleDiff > 0) {
              turnRight();
            } else {
              turnLeft();
            }
            navigationStartTime = millis(); // Reset timer pour la rotation
          }
        } else {
          // Pas de mouvement détecté, continuer l'exploration
          Serial.println("⚠️ Mouvement GPS insuffisant - Continue exploration");
          goForward(EXPLORATION_SPEED);
          navigationStartTime = millis(); // Prolonge l'exploration
        }
      }
      break;

    case CORRECTING:
      // Phase de correction - tourner puis reprendre l'exploration
      if (millis() - navigationStartTime > TURN_TIME) {
        navState = EXPLORING;
        navigationStartTime = millis();
        lastDistance = distanceToTarget;
        Serial.println("🔍 Reprise exploration après correction");
        goForward(EXPLORATION_SPEED);
      }
      break;

    case NAVIGATING:
      // Navigation directe avec ajustements fins
      if (hasLastPosition && (millis() - lastMovementTime < 3000)) {
        double angleDiff = bearingToTarget - currentHeading;
        while (angleDiff > 180) angleDiff -= 360;
        while (angleDiff < -180) angleDiff += 360;

        if (abs(angleDiff) > TURN_THRESHOLD * 1.5) {
          // Déviation importante, retour en mode correction
          Serial.println("🔄 Déviation détectée - Retour en correction");
          navState = CORRECTING;
          navigationStartTime = millis();
          
          if (angleDiff > 0) {
            turnRight();
          } else {
            turnLeft();
          }
        } else {
          // Navigation avec vitesse adaptée à la distance
          int speed = map(constrain(distanceToTarget, 3, 50), 3, 50, MIN_SPEED, MAX_SPEED);
          goForward(speed);
          
          // Ajustement fin de direction si nécessaire
          if (abs(angleDiff) > 10) {
            Serial.print("🎯 Ajustement fin: "); Serial.print(angleDiff, 1); Serial.println("°");
          }
        }
      } else {
        // Pas de mouvement récent, avancer prudemment
        goForward(MIN_SPEED);
      }
      break;
  }

  printNavigationState();
  lastDistance = distanceToTarget;
}

// === AFFICHAGE ÉTAT ===
void printNavigationState() {
  Serial.print("État: ");
  switch (navState) {
    case IDLE: Serial.print("IDLE"); break;
    case EXPLORING: Serial.print("EXPLORATION"); break;
    case CORRECTING: Serial.print("CORRECTION"); break;
    case NAVIGATING: Serial.print("NAVIGATION"); break;
  }
  Serial.println();
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
        Serial.println("✅ Cible définie:");
        Serial.print("   Décimal: "); Serial.print(targetLat, 6); 
        Serial.print(", "); Serial.println(targetLng, 6);
        
        if (hasInitialPosition) {
          double dist = calculateDistance(initialLat, initialLng, targetLat, targetLng);
          double bearing = calculateBearing(initialLat, initialLng, targetLat, targetLng);
          Serial.print("   Distance: "); Serial.print(dist, 1); Serial.println(" m");
          Serial.print("   Direction: "); Serial.print(bearing, 1); Serial.println("°");
        }
      } else {
        Serial.println("❌ Erreur: Format de coordonnées invalide");
        Serial.println("   Format attendu: 48°50'18\"N,2°18'41\"E");
      }
    }
  }
  else if (cmd == "go") {
    if (targetSet) {
      navigating = true;
      navState = IDLE;  // Reset de l'état
      hasLastPosition = false;  // Reset pour recalculer la direction
      Serial.println("🚀 NAVIGATION DÉMARRÉE");
      Serial.print("Cible: "); Serial.print(targetLat, 6); 
      Serial.print(", "); Serial.println(targetLng, 6);
    } else {
      Serial.println("❌ Aucune cible définie. Utilisez 'set' d'abord.");
    }
  }
  else if (cmd == "stop") {
    navigating = false;
    navState = IDLE;
    stopMotors();
    Serial.println("🛑 Navigation arrêtée");
  }
  else if (cmd == "status") {
    Serial.println("=== ÉTAT ACTUEL ===");
    Serial.print("Cible définie: "); Serial.println(targetSet ? "Oui" : "Non");
    if (targetSet) {
      Serial.print("Coordonnées: "); Serial.print(targetLat, 6); 
      Serial.print(", "); Serial.println(targetLng, 6);
    }
    Serial.print("Navigation: "); Serial.println(navigating ? "Active" : "Inactive");
    printNavigationState();
    Serial.print("GPS valide: "); Serial.println(gps.location.isValid() ? "Oui" : "Non");
    if (gps.location.isValid()) {
      Serial.print("Position: "); Serial.print(gps.location.lat(), 6);
      Serial.print(", "); Serial.println(gps.location.lng(), 6);
    }
    Serial.println("==================");
  }
  else if (cmd == "test") {
    Serial.println("🔧 Test moteurs - Avance 2s");
    goForward(150);
    delay(2000);
    stopMotors();
    Serial.println("Test terminé");
  }
  else if (cmd == "testleft") {
    Serial.println("🔧 Test rotation gauche");
    turnLeft();
    delay(1000);
    stopMotors();
  }
  else if (cmd == "testright") {
    Serial.println("🔧 Test rotation droite");
    turnRight();
    delay(1000);
    stopMotors();
  }
  else {
    Serial.println("❓ Commande inconnue. Tapez 'status' pour voir l'état.");
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

// === CALCULS GPS ===
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
// double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
//   double y = sin(radians(lng2 - lng1)) * cos(radians(lat2));
//   double x = cos(radians(lat1)) * sin(radians(lat2)) -
//              sin(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2 - lng1));
//   return fmod(degrees(atan2(y, x)) + 360.0, 360.0);
// }


// === CONTRÔLE MOTEURS ===
void goForward() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, MAX_SPEED);
  analogWrite(PWMB, MAX_SPEED);
}

void goForward(int speed) {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, speed);
  analogWrite(PWMB, speed);
}

void turnLeft() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);   // Moteur A en arrière
  digitalWrite(BIN, HIGH);  // Moteur B en avant
  analogWrite(PWMA, MIN_SPEED);
  analogWrite(PWMB, MIN_SPEED);
}

void turnRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);  // Moteur A en avant
  digitalWrite(BIN, LOW);   // Moteur B en arrière
  analogWrite(PWMA, MIN_SPEED);
  analogWrite(PWMB, MIN_SPEED);
}

void stopMotors() {
  digitalWrite(STBY, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
}