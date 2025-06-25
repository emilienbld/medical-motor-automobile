// === NAVIGATION GPS + MPU-6500 OPTIMISÉE ===
// Code simple et clair pour navigation autonome
// Objectif: Aller d'un point A à un point B avec GPS + Gyroscope MPU-6500

#include <SoftwareSerial.h>
#include <TinyGPS++.h>
#include <Wire.h>
#include <math.h>

// === CONFIGURATION MATÉRIEL ===
// GPS
static const int RXPin = A2, TXPin = A1;
static const uint32_t GPSBaud = 9600;
TinyGPSPlus gps;
SoftwareSerial gpsSerial(RXPin, TXPin);

// MPU-6500
const int MPU6500_ADDR = 0x68;
float gyro_offset = 0.0;      // Correction du gyroscope
float robot_angle = 0.0;      // Angle actuel du robot (0-360°)
unsigned long last_gyro_time = 0;
bool gyro_ok = false;

// Moteurs TB6612
#define PWMA 5
#define PWMB 6  
#define AIN 7
#define BIN 8
#define STBY 3

// === VARIABLES DE NAVIGATION ===
double target_lat = 0.0, target_lng = 0.0;  // Destination
bool target_set = false;
bool navigating = false;

// Position actuelle
double current_lat = 0.0, current_lng = 0.0;
bool position_valid = false;

// === PARAMÈTRES ===
const double ARRIVAL_DISTANCE = 3.0;     // Distance d'arrivée (mètres)
const double ANGLE_TOLERANCE = 12.0;     // Tolérance d'angle (degrés)
const int FORWARD_SPEED = 150;           // Vitesse d'avance
const int TURN_SPEED = 120;              // Vitesse de rotation

// === FONCTIONS PRINCIPALES ===

void setup() {
  Serial.begin(9600);
  gpsSerial.begin(GPSBaud);
  Wire.begin();
  
  setupMotors();
  setupMPU6500();
  
  Serial.println("=== ROBOT GPS + MPU-6500 NAVIGATION ===");
  Serial.println("Commandes:");
  Serial.println("- set 48°50'18\"N,2°18'41\"E : Définir destination");
  Serial.println("- go : Démarrer navigation");
  Serial.println("- stop : Arrêter");
  Serial.println("- status : État actuel");
  Serial.println("- calibrate : Recalibrer gyroscope");
  Serial.println("- gyro_test : Test gyroscope en temps réel");
  Serial.println("- scan : Scanner composants I2C");
  Serial.println("- test : Test moteurs");
  Serial.println("==========================================");
}

void loop() {
  readGPS();          // Lire position GPS
  readGyroscope();    // Lire gyroscope
  handleCommands();   // Traiter commandes série
  
  if (navigating && target_set && position_valid) {
    navigate();       // Navigation principale
  }
  
  delay(50);          // Pause pour stabilité
}

// === LECTURE CAPTEURS ===

void readGPS() {
  while (gpsSerial.available() > 0) {
    if (gps.encode(gpsSerial.read())) {
      if (gps.location.isValid()) {
        current_lat = gps.location.lat();
        current_lng = gps.location.lng();
        position_valid = true;
        
        Serial.print("GPS: ");
        Serial.print(current_lat, 6);
        Serial.print(", ");
        Serial.print(current_lng, 6);
        if (gyro_ok) {
          Serial.print(" | Angle: ");
          Serial.print(robot_angle, 1);
          Serial.print("°");
        }
        Serial.println();
      }
    }
  }
}

void readGyroscope() {
  if (!gyro_ok) return;
  
  unsigned long now = millis();
  float dt = (now - last_gyro_time) / 1000.0;  // Delta temps en secondes
  
  if (dt > 0.1) {  // Éviter les calculs trop fréquents
    last_gyro_time = now;
    return;
  }
  
  // Lire vitesse de rotation Z (°/s)
  float rotation_speed = readGyroZ() - gyro_offset;
  
  // Intégrer pour obtenir l'angle
  robot_angle += rotation_speed * dt;
  robot_angle = normalizeAngle(robot_angle);
  
  last_gyro_time = now;
}

// === NAVIGATION PRINCIPALE ===

void navigate() {
  // 1. Calculer distance et direction vers la cible
  double distance = calculateDistance(current_lat, current_lng, target_lat, target_lng);
  double target_bearing = calculateBearing(current_lat, current_lng, target_lat, target_lng);
  
  Serial.print("Distance: ");
  Serial.print(distance, 1);
  Serial.print("m | Direction cible: ");
  Serial.print(target_bearing, 1);
  Serial.print("° | Angle robot: ");
  Serial.print(robot_angle, 1);
  Serial.println("°");
  
  // 2. Vérifier si on est arrivé
  if (distance <= ARRIVAL_DISTANCE) {
    Serial.println("🎯 ARRIVÉ À DESTINATION!");
    stopMotors();
    navigating = false;
    return;
  }
  
  // 3. Calculer l'erreur d'angle
  double angle_error = target_bearing - robot_angle;
  angle_error = normalizeAngleDiff(angle_error);
  
  // 4. Décider de l'action
  if (abs(angle_error) > ANGLE_TOLERANCE) {
    // Besoin de tourner
    Serial.print("🔄 Rotation nécessaire: ");
    Serial.print(angle_error, 1);
    Serial.println("°");
    
    if (angle_error > 0) {
      turnRight();
    } else {
      turnLeft();
    }
  } else {
    // Direction correcte, avancer
    Serial.println("➡️ Avance vers la cible");
    goForward();
  }
}

// === CALCULS GÉOGRAPHIQUES ===

double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  // Formule de Haversine pour calculer la distance entre 2 points GPS
  const double R = 6371000.0; // Rayon de la Terre en mètres
  
  double dLat = toRadians(lat2 - lat1);
  double dLng = toRadians(lng2 - lng1);
  
  double a = sin(dLat/2) * sin(dLat/2) + 
             cos(toRadians(lat1)) * cos(toRadians(lat2)) * 
             sin(dLng/2) * sin(dLng/2);
             
  double c = 2 * atan2(sqrt(a), sqrt(1-a));
  
  return R * c; // Distance en mètres
}

double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
  // Calcule la direction (bearing) du point 1 vers le point 2
  double dLng = toRadians(lng2 - lng1);
  
  double y = sin(dLng) * cos(toRadians(lat2));
  double x = cos(toRadians(lat1)) * sin(toRadians(lat2)) - 
             sin(toRadians(lat1)) * cos(toRadians(lat2)) * cos(dLng);
             
  double bearing = toDegrees(atan2(y, x));
  
  return normalizeAngle(bearing); // Résultat entre 0-360°
}

// === UTILITAIRES ANGLES ===

double normalizeAngle(double angle) {
  // Normalise un angle entre 0 et 360°
  while (angle >= 360.0) angle -= 360.0;
  while (angle < 0.0) angle += 360.0;
  return angle;
}

double normalizeAngleDiff(double angle_diff) {
  // Normalise une différence d'angle entre -180 et +180°
  while (angle_diff > 180.0) angle_diff -= 360.0;
  while (angle_diff < -180.0) angle_diff += 360.0;
  return angle_diff;
}

double toRadians(double deg) {
  return deg * PI / 180.0;
}

double toDegrees(double rad) {
  return rad * 180.0 / PI;
}

// === COMMANDES SÉRIE ===

void handleCommands() {
  if (!Serial.available()) return;
  
  String cmd = Serial.readStringUntil('\n');
  cmd.trim();
  cmd.toLowerCase();
  
  if (cmd.startsWith("set ")) {
    setTarget(cmd.substring(4));
  }
  else if (cmd == "go") {
    startNavigation();
  }
  else if (cmd == "stop") {
    stopNavigation();
  }
  else if (cmd == "status") {
    printStatus();
  }
  else if (cmd == "calibrate") {
    calibrateMPU6500();
  }
  else if (cmd == "gyro_test") {
    testGyroscope();
  }
  else if (cmd == "scan") {
    scanI2C();
  }
  else if (cmd == "test") {
    testMotors();
  }
  else {
    Serial.println("❓ Commande inconnue");
  }
}

void setTarget(String coords) {
  // Parse "48°50'18"N,2°18'41"E"
  int comma = coords.indexOf(',');
  if (comma == -1) {
    Serial.println("❌ Format invalide. Exemple: 48°50'18\"N,2°18'41\"E");
    return;
  }
  
  String lat_str = coords.substring(0, comma);
  String lng_str = coords.substring(comma + 1);
  
  target_lat = parseDMS(lat_str);
  target_lng = parseDMS(lng_str);
  
  if (isnan(target_lat) || isnan(target_lng)) {
    Serial.println("❌ Coordonnées invalides");
    return;
  }
  
  target_set = true;
  Serial.println("✅ Destination définie:");
  Serial.print("   Latitude: "); Serial.println(target_lat, 6);
  Serial.print("   Longitude: "); Serial.println(target_lng, 6);
  
  if (position_valid) {
    double dist = calculateDistance(current_lat, current_lng, target_lat, target_lng);
    double bearing = calculateBearing(current_lat, current_lng, target_lat, target_lng);
    Serial.print("   Distance: "); Serial.print(dist, 1); Serial.println("m");
    Serial.print("   Direction: "); Serial.print(bearing, 1); Serial.println("°");
  }
}

void startNavigation() {
  if (!target_set) {
    Serial.println("❌ Aucune destination définie");
    return;
  }
  if (!position_valid) {
    Serial.println("❌ Position GPS non disponible");
    return;
  }
  if (!gyro_ok) {
    Serial.println("⚠️ Gyroscope non disponible - Navigation GPS seule");
  }
  
  navigating = true;
  Serial.println("🚀 NAVIGATION DÉMARRÉE");
}

void stopNavigation() {
  navigating = false;
  stopMotors();
  Serial.println("🛑 Navigation arrêtée");
}

void printStatus() {
  Serial.println("=== ÉTAT ACTUEL ===");
  Serial.print("GPS: "); Serial.println(position_valid ? "✅ OK" : "❌ Pas de signal");
  Serial.print("MPU-6500: "); Serial.println(gyro_ok ? "✅ OK" : "❌ Erreur");
  Serial.print("Destination: "); Serial.println(target_set ? "✅ Définie" : "❌ Non définie");
  Serial.print("Navigation: "); Serial.println(navigating ? "🚀 Active" : "⏸️ Arrêtée");
  
  if (position_valid) {
    Serial.print("Position: "); Serial.print(current_lat, 6); 
    Serial.print(", "); Serial.println(current_lng, 6);
  }
  if (gyro_ok) {
    Serial.print("Angle robot: "); Serial.print(robot_angle, 1); Serial.println("°");
    Serial.print("Vitesse rotation: "); Serial.print(readGyroZ() - gyro_offset, 2); Serial.println("°/s");
  }
  if (target_set) {
    Serial.print("Destination: "); Serial.print(target_lat, 6);
    Serial.print(", "); Serial.println(target_lng, 6);
  }
  Serial.println("==================");
}

void testMotors() {
  Serial.println("🔧 Test moteurs:");
  Serial.println("   Avance 2s...");
  goForward();
  delay(2000);
  Serial.println("   Tourne droite 1s...");
  turnRight();
  delay(1000);
  Serial.println("   Tourne gauche 1s...");
  turnLeft();
  delay(1000);
  stopMotors();
  Serial.println("✅ Test terminé");
}

// === FONCTIONS DE TEST ET DIAGNOSTIC ===

void testGyroscope() {
  if (!gyro_ok) {
    Serial.println("❌ Gyroscope non disponible");
    return;
  }
  
  Serial.println("🔄 TEST GYROSCOPE (10 lectures)");
  Serial.println("Tournez le robot pour voir les valeurs changer:");
  
  for (int i = 0; i < 10; i++) {
    float gyro_raw = readGyroZ();
    float gyro_corrected = gyro_raw - gyro_offset;
    
    Serial.print("Lecture "); Serial.print(i+1); Serial.print(": ");
    Serial.print("Brut="); Serial.print(gyro_raw, 2);
    Serial.print("°/s | Corrigé="); Serial.print(gyro_corrected, 2);
    Serial.print("°/s | Angle="); Serial.print(robot_angle, 1); Serial.println("°");
    
    delay(500);
  }
  Serial.println("✅ Test terminé");
}

void scanI2C() {
  Serial.println("🔍 SCAN I2C - Recherche de tous les composants:");
  
  int devices = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    byte error = Wire.endTransmission();
    
    if (error == 0) {
      Serial.print("Composant trouvé à l'adresse 0x");
      if (addr < 16) Serial.print("0");
      Serial.print(addr, HEX);
      
      // Identifier les composants connus
      if (addr == 0x68) Serial.print(" (MPU-6500)");
      else if (addr == 0x77) Serial.print(" (BMP280/BME280)");
      else Serial.print(" (Inconnu)");
      
      Serial.println();
      devices++;
    }
  }
  
  if (devices == 0) {
    Serial.println("❌ Aucun composant I2C trouvé");
  } else {
    Serial.print("✅ "); Serial.print(devices); Serial.println(" composant(s) trouvé(s)");
  }
}

// === CONVERSION DMS VERS DÉCIMAL ===

double parseDMS(String dms) {
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

// === CONTRÔLE MPU-6500 ===

void setupMPU6500() {
  Serial.print("Initialisation MPU-6500... ");
  
  Wire.beginTransmission(MPU6500_ADDR);
  Wire.write(0x6B);  // PWR_MGMT_1
  Wire.write(0);     // Réveiller le capteur
  byte error = Wire.endTransmission(true);
  
  if (error == 0) {
    // Vérifier l'ID du composant
    Wire.beginTransmission(MPU6500_ADDR);
    Wire.write(0x75);  // WHO_AM_I
    Wire.endTransmission(false);
    Wire.requestFrom(MPU6500_ADDR, 1, true);
    
    if (Wire.available()) {
      byte who_am_i = Wire.read();
      Serial.print("ID=0x"); Serial.print(who_am_i, HEX); Serial.print(" ");
      
      if (who_am_i == 0x70) {  // MPU-6500 ID
        // Configuration gyroscope ±250°/s
        Wire.beginTransmission(MPU6500_ADDR);
        Wire.write(0x1B);
        Wire.write(0x00);
        Wire.endTransmission(true);
        
        gyro_ok = true;
        last_gyro_time = millis();
        Serial.println("✅ OK");
        
        // Calibration automatique
        calibrateMPU6500();
      } else {
        gyro_ok = false;
        Serial.println("❌ ID incorrect");
      }
    } else {
      gyro_ok = false;
      Serial.println("❌ Pas de réponse ID");
    }
  } else {
    gyro_ok = false;
    Serial.println("❌ Pas de connexion I2C");
  }
}

void calibrateMPU6500() {
  if (!gyro_ok) return;
  
  Serial.print("Calibration gyroscope (ne pas bouger)... ");
  
  float sum = 0;
  int samples = 500;
  
  for (int i = 0; i < samples; i++) {
    sum += readGyroZ();
    delay(2);
  }
  
  gyro_offset = sum / samples;
  robot_angle = 0.0;  // Reset de l'angle
  
  Serial.print("✅ Terminé (offset: ");
  Serial.print(gyro_offset, 2);
  Serial.println("°/s)");
}

float readGyroZ() {
  if (!gyro_ok) return 0.0;
  
  Wire.beginTransmission(MPU6500_ADDR);
  Wire.write(0x47);  // GYRO_ZOUT_H
  Wire.endTransmission(false);
  Wire.requestFrom(MPU6500_ADDR, 2, true);
  
  int16_t raw = Wire.read() << 8 | Wire.read();
  return raw / 131.0;  // Conversion en °/s (sensibilité ±250°/s)
}

// === CONTRÔLE MOTEURS ===

void setupMotors() {
  pinMode(PWMA, OUTPUT);
  pinMode(PWMB, OUTPUT);
  pinMode(AIN, OUTPUT);
  pinMode(BIN, OUTPUT);
  pinMode(STBY, OUTPUT);
  stopMotors();
}

void goForward() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);   // Moteur A en avant
  digitalWrite(BIN, HIGH);   // Moteur B en avant
  analogWrite(PWMA, FORWARD_SPEED);
  analogWrite(PWMB, FORWARD_SPEED);
}

void turnRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);   // Moteur A en avant
  digitalWrite(BIN, LOW);    // Moteur B en arrière
  analogWrite(PWMA, TURN_SPEED);
  analogWrite(PWMB, TURN_SPEED);
}

void turnLeft() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);    // Moteur A en arrière
  digitalWrite(BIN, HIGH);   // Moteur B en avant
  analogWrite(PWMA, TURN_SPEED);
  analogWrite(PWMB, TURN_SPEED);
}

void stopMotors() {
  digitalWrite(STBY, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
}