// === CODE GPS ROBOT NAVIGATION AVEC HISTORIQUE ===
// Navigation GPS avec filtrage des positions pour éviter les "téléportations"
// Utilise les 5 dernières positions pour calculer une direction lissée

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

// === HISTORIQUE DES POSITIONS ===
struct GPSPosition {
  double lat;
  double lng;
  unsigned long timestamp;
  bool valid;
};

const int HISTORY_SIZE = 5;
GPSPosition positionHistory[HISTORY_SIZE];
int historyIndex = 0;
int validPositions = 0;

// Variables pour la navigation
double initialLat = 0.0;
double initialLng = 0.0;
double currentHeading = 0.0;
double smoothedHeading = 0.0;  // Direction lissée
bool hasInitialPosition = false;
unsigned long lastGPSTime = 0;
unsigned long navigationStartTime = 0;

// États de navigation
enum NavigationState {
  IDLE,
  EXPLORING,
  CORRECTING,
  NAVIGATING
};

NavigationState navState = IDLE;
double lastDistance = 0.0;
unsigned long lastMovementTime = 0;

// Paramètres de navigation
const double ARRIVAL_THRESHOLD = 3.0;
const double MIN_SPEED = 120;
const double MAX_SPEED = 200;
const double EXPLORATION_SPEED = 130;
const double TURN_THRESHOLD = 25.0;
const double MIN_MOVEMENT_DISTANCE = 1.0;
const unsigned long EXPLORATION_TIME = 5000; // Augmenté pour plus de données
const unsigned long TURN_TIME = 800;

// === PARAMÈTRES DE FILTRAGE ===
const double MAX_JUMP_DISTANCE = 8.0;    // Distance max acceptable entre 2 positions (en mètres)
const double MIN_SPEED_MPS = 0.1;        // Vitesse minimum en m/s pour considérer un mouvement
const double MAX_SPEED_MPS = 3.0;        // Vitesse maximum en m/s (seuil de téléportation)
const int MIN_POSITIONS_FOR_HEADING = 3; // Nombre minimum de positions pour calculer la direction

// Déclarations des fonctions
void addPositionToHistory(double lat, double lng);
bool isValidMovement(double lat, double lng);
double calculateSmoothedHeading();
double calculateWeightedHeading();
void printPositionHistory();
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

  // Initialiser l'historique
  for (int i = 0; i < HISTORY_SIZE; i++) {
    positionHistory[i].valid = false;
  }

  Serial.println("=== ROBOT GPS NAVIGATION AVEC HISTORIQUE ===");
  Serial.println("Commandes disponibles :");
  Serial.println("- 'set 48°50'20.3\"N,2°18'44.2\"E' : Définir coordonnées cible");
  Serial.println("- 'go' : Démarrer la navigation");
  Serial.println("- 'stop' : Arrêter la navigation");
  Serial.println("- 'status' : Afficher l'état actuel");
  Serial.println("- 'history' : Afficher l'historique des positions");
  Serial.println("- 'test' : Test moteurs");
  Serial.println("============================================");
}

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

      // Vérifier si le mouvement est valide (pas de téléportation)
      if (isValidMovement(lat, lng)) {
        // Ajouter à l'historique
        addPositionToHistory(lat, lng);
        
        // Première position GPS
        if (!hasInitialPosition) {
          initialLat = lat;
          initialLng = lng;
          hasInitialPosition = true;
          Serial.println("Position initiale enregistrée");
        }

        // Calculer la direction lissée si on a assez de données
        if (validPositions >= MIN_POSITIONS_FOR_HEADING) {
          double newSmoothedHeading = calculateSmoothedHeading();
          if (!isnan(newSmoothedHeading)) {
            smoothedHeading = newSmoothedHeading;
            lastMovementTime = millis();
            Serial.print("Direction lissée: "); Serial.print(smoothedHeading, 1); Serial.println("°");
          }
        }

        // Navigation si activée
        if (targetSet && navigating) {
          navigateToTarget();
        }

        lastGPSTime = millis();
      } else {
        Serial.println("⚠️ Mouvement GPS suspect - Position ignorée");
      }
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

// === GESTION DE L'HISTORIQUE ===
void addPositionToHistory(double lat, double lng) {
  positionHistory[historyIndex].lat = lat;
  positionHistory[historyIndex].lng = lng;
  positionHistory[historyIndex].timestamp = millis();
  positionHistory[historyIndex].valid = true;
  
  historyIndex = (historyIndex + 1) % HISTORY_SIZE;
  if (validPositions < HISTORY_SIZE) {
    validPositions++;
  }
  
  Serial.print("Position ajoutée à l'historique ("); 
  Serial.print(validPositions); Serial.println(" positions valides)");
}

bool isValidMovement(double lat, double lng) {
  // Première position toujours acceptée
  if (validPositions == 0) return true;
  
  // Trouver la dernière position valide
  int lastIndex = (historyIndex - 1 + HISTORY_SIZE) % HISTORY_SIZE;
  if (!positionHistory[lastIndex].valid) return true;
  
  double lastLat = positionHistory[lastIndex].lat;
  double lastLng = positionHistory[lastIndex].lng;
  unsigned long lastTime = positionHistory[lastIndex].timestamp;
  
  double distance = calculateDistance(lastLat, lastLng, lat, lng);
  unsigned long timeDiff = millis() - lastTime;
  double speed = distance / (timeDiff / 1000.0); // m/s
  
  Serial.print("Vérification mouvement - Distance: "); Serial.print(distance, 1);
  Serial.print("m, Vitesse: "); Serial.print(speed, 2); Serial.println("m/s");
  
  // Rejeter si distance trop grande (téléportation)
  if (distance > MAX_JUMP_DISTANCE) {
    Serial.println("❌ Téléportation détectée - Distance trop grande");
    return false;
  }
  
  // Rejeter si vitesse irréaliste
  if (speed > MAX_SPEED_MPS) {
    Serial.println("❌ Vitesse irréaliste détectée");
    return false;
  }
  
  return true;
}

double calculateSmoothedHeading() {
  if (validPositions < 2) return NAN;
  
  // Méthode 1: Direction entre la première et dernière position valide
  int firstValidIndex = -1;
  int lastValidIndex = -1;
  
  // Trouver la première position valide
  for (int i = 0; i < HISTORY_SIZE; i++) {
    if (positionHistory[i].valid) {
      if (firstValidIndex == -1) firstValidIndex = i;
      lastValidIndex = i;
    }
  }
  
  if (firstValidIndex == -1 || firstValidIndex == lastValidIndex) return NAN;
  
  double bearing = calculateBearing(
    positionHistory[firstValidIndex].lat, positionHistory[firstValidIndex].lng,
    positionHistory[lastValidIndex].lat, positionHistory[lastValidIndex].lng
  );
  
  // Vérifier que la distance totale est suffisante
  double totalDistance = calculateDistance(
    positionHistory[firstValidIndex].lat, positionHistory[firstValidIndex].lng,
    positionHistory[lastValidIndex].lat, positionHistory[lastValidIndex].lng
  );
  
  if (totalDistance < MIN_MOVEMENT_DISTANCE * 2) {
    Serial.println("Distance totale insuffisante pour calcul direction");
    return NAN;
  }
  
  Serial.print("Calcul direction sur "); Serial.print(totalDistance, 1); Serial.println("m");
  return bearing;
}

double calculateWeightedHeading() {
  // Méthode alternative: moyenne pondérée des directions récentes
  if (validPositions < 2) return NAN;
  
  double sumX = 0, sumY = 0;
  int segments = 0;
  
  for (int i = 0; i < HISTORY_SIZE - 1; i++) {
    if (positionHistory[i].valid && positionHistory[i + 1].valid) {
      double bearing = calculateBearing(
        positionHistory[i].lat, positionHistory[i].lng,
        positionHistory[i + 1].lat, positionHistory[i + 1].lng
      );
      
      // Pondération : plus récent = plus important
      double weight = 1.0 + (i * 0.5);
      sumX += cos(radians(bearing)) * weight;
      sumY += sin(radians(bearing)) * weight;
      segments++;
    }
  }
  
  if (segments == 0) return NAN;
  
  double avgBearing = degrees(atan2(sumY, sumX));
  if (avgBearing < 0) avgBearing += 360;
  
  return avgBearing;
}

void printPositionHistory() {
  Serial.println("=== HISTORIQUE DES POSITIONS ===");
  for (int i = 0; i < HISTORY_SIZE; i++) {
    if (positionHistory[i].valid) {
      Serial.print("Position "); Serial.print(i); Serial.print(": ");
      Serial.print(positionHistory[i].lat, 6); Serial.print(", ");
      Serial.print(positionHistory[i].lng, 6);
      Serial.print(" ("); Serial.print(millis() - positionHistory[i].timestamp);
      Serial.println("ms ago)");
    }
  }
  Serial.print("Direction lissée actuelle: "); Serial.println(smoothedHeading, 1);
  Serial.println("===============================");
}

// === NAVIGATION INTELLIGENTE ===
void navigateToTarget() {
  if (!gps.location.isValid() || validPositions == 0) return;

  // Utiliser la dernière position valide de l'historique
  int lastIndex = (historyIndex - 1 + HISTORY_SIZE) % HISTORY_SIZE;
  double currentLat = positionHistory[lastIndex].lat;
  double currentLng = positionHistory[lastIndex].lng;
  
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
      navState = EXPLORING;
      navigationStartTime = millis();
      lastDistance = distanceToTarget;
      Serial.println("🔍 PHASE EXPLORATION - Collecte de données GPS");
      goForward(EXPLORATION_SPEED);
      break;

    case EXPLORING:
      if (millis() - navigationStartTime > EXPLORATION_TIME) {
        if (validPositions >= MIN_POSITIONS_FOR_HEADING && 
            (millis() - lastMovementTime < 3000)) {
          
          // Calculer l'erreur d'angle avec la direction lissée
          double angleDiff = bearingToTarget - smoothedHeading;
          while (angleDiff > 180) angleDiff -= 360;
          while (angleDiff < -180) angleDiff += 360;

          Serial.print("🧭 Direction lissée: "); Serial.print(smoothedHeading, 1);
          Serial.print("° - Erreur: "); Serial.print(angleDiff, 1); Serial.println("°");

          if (abs(angleDiff) < TURN_THRESHOLD) {
            navState = NAVIGATING;
            Serial.println("✅ Direction correcte - Navigation directe");
          } else {
            navState = CORRECTING;
            Serial.print("🔄 Correction nécessaire - Rotation ");
            Serial.println(angleDiff > 0 ? "droite" : "gauche");
            
            if (angleDiff > 0) {
              turnRight();
            } else {
              turnLeft();
            }
            navigationStartTime = millis();
          }
        } else {
          Serial.println("⚠️ Données GPS insuffisantes - Continue exploration");
          goForward(EXPLORATION_SPEED);
          navigationStartTime = millis();
        }
      }
      break;

    case CORRECTING:
      if (millis() - navigationStartTime > TURN_TIME) {
        navState = EXPLORING;
        navigationStartTime = millis();
        lastDistance = distanceToTarget;
        Serial.println("🔍 Reprise exploration après correction");
        goForward(EXPLORATION_SPEED);
      }
      break;

    case NAVIGATING:
      if (validPositions >= MIN_POSITIONS_FOR_HEADING && 
          (millis() - lastMovementTime < 3000)) {
        
        double angleDiff = bearingToTarget - smoothedHeading;
        while (angleDiff > 180) angleDiff -= 360;
        while (angleDiff < -180) angleDiff += 360;

        if (abs(angleDiff) > TURN_THRESHOLD * 1.5) {
          Serial.println("🔄 Déviation importante détectée - Retour en correction");
          navState = CORRECTING;
          navigationStartTime = millis();
          
          if (angleDiff > 0) {
            turnRight();
          } else {
            turnLeft();
          }
        } else {
          int speed = map(constrain(distanceToTarget, 3, 50), 3, 50, MIN_SPEED, MAX_SPEED);
          goForward(speed);
          
          if (abs(angleDiff) > 10) {
            Serial.print("🎯 Ajustement fin: "); Serial.print(angleDiff, 1); Serial.println("°");
          }
        }
      } else {
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
  Serial.print(" - Positions valides: "); Serial.println(validPositions);
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
      }
    }
  }
  else if (cmd == "go") {
    if (targetSet) {
      navigating = true;
      navState = IDLE;
      // Réinitialiser l'historique pour une navigation fraîche
      for (int i = 0; i < HISTORY_SIZE; i++) {
        positionHistory[i].valid = false;
      }
      validPositions = 0;
      historyIndex = 0;
      Serial.println("🚀 NAVIGATION DÉMARRÉE - Historique réinitialisé");
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
  else if (cmd == "history") {
    printPositionHistory();
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
    Serial.print("Positions dans l'historique: "); Serial.println(validPositions);
    if (validPositions > 0) {
      Serial.print("Direction lissée: "); Serial.print(smoothedHeading, 1); Serial.println("°");
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
  digitalWrite(AIN, LOW);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, MIN_SPEED);
  analogWrite(PWMB, MIN_SPEED);
}

void turnRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, LOW);
  analogWrite(PWMA, MIN_SPEED);
  analogWrite(PWMB, MIN_SPEED);
}

void stopMotors() {
  digitalWrite(STBY, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
}