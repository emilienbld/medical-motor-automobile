// === NAVIGATION GPS + MPU-9250 AVEC BOUSSOLE ===
// Code optimisé utilisant la boussole intégrée du MPU-9250
// Orientation absolue sans dérive !

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

// MPU-9250
const int MPU9250_ADDR = 0x68;    // Adresse principale
const int MAG_ADDR = 0x0C;        // Adresse magnétomètre interne
float gyro_offset = 0.0;          // Correction gyroscope
float mag_offset_x = 0.0;         // Calibration magnétomètre
float mag_offset_y = 0.0;
float mag_scale_x = 1.0;
float mag_scale_y = 1.0;
float robot_heading = 0.0;        // Direction absolue du robot (0-360°)
bool mpu_ok = false;
bool mag_ok = false;

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
const double ANGLE_TOLERANCE = 8.0;      // Tolérance d'angle (degrés) - plus précis !
const int FORWARD_SPEED = 150;           // Vitesse d'avance
const int TURN_SPEED = 120;              // Vitesse de rotation

// Déclinaison magnétique (à ajuster selon votre région)
// Paris: environ 1° Est (positif)
const float MAGNETIC_DECLINATION = 1.0;

// === FONCTIONS PRINCIPALES ===

void setup() {
  Serial.begin(9600);
  gpsSerial.begin(GPSBaud);
  Wire.begin();
  
  setupMotors();
  setupMPU9250();
  
  Serial.println("=== ROBOT GPS + MPU-9250 NAVIGATION ===");
  Serial.println("Commandes:");
  Serial.println("- set 48°50'18\"N,2°18'41\"E : Définir destination");
  Serial.println("- go : Démarrer navigation");
  Serial.println("- stop : Arrêter");
  Serial.println("- status : État actuel");
  Serial.println("- calibrate : Calibrer la boussole");
  Serial.println("- compass : Afficher direction boussole");
  Serial.println("- test : Test moteurs");
  Serial.println("=======================================");
}

void loop() {
  readGPS();              // Lire position GPS
  readCompass();          // Lire boussole
  handleCommands();       // Traiter commandes série
  
  if (navigating && target_set && position_valid && mag_ok) {
    navigate();           // Navigation principale
  }
  
  delay(100);             // Pause pour stabilité
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
        if (mag_ok) {
          Serial.print(" | Direction: ");
          Serial.print(robot_heading, 1);
          Serial.print("°");
        }
        Serial.println();
      }
    }
  }
}

void readCompass() {
  if (!mag_ok) return;
  
  // Lire magnétomètre
  float mag_x, mag_y, mag_z;
  if (readMagnetometer(mag_x, mag_y, mag_z)) {
    // Appliquer la calibration
    mag_x = (mag_x - mag_offset_x) * mag_scale_x;
    mag_y = (mag_y - mag_offset_y) * mag_scale_y;
    
    // Calculer la direction (0° = Nord, 90° = Est)
    robot_heading = atan2(mag_y, mag_x) * 180.0 / PI;
    
    // Appliquer la déclinaison magnétique
    robot_heading += MAGNETIC_DECLINATION;
    
    // Normaliser entre 0-360°
    robot_heading = normalizeAngle(robot_heading);
  }
}

// === NAVIGATION PRINCIPALE ===

void navigate() {
  // 1. Calculer distance et direction vers la cible
  double distance = calculateDistance(current_lat, current_lng, target_lat, target_lng);
  double target_bearing = calculateBearing(current_lat, current_lng, target_lat, target_lng);
  
  Serial.print("Distance: ");
  Serial.print(distance, 1);
  Serial.print("m | Cible: ");
  Serial.print(target_bearing, 1);
  Serial.print("° | Robot: ");
  Serial.print(robot_heading, 1);
  Serial.println("°");
  
  // 2. Vérifier si on est arrivé
  if (distance <= ARRIVAL_DISTANCE) {
    Serial.println("🎯 ARRIVÉ À DESTINATION!");
    stopMotors();
    navigating = false;
    return;
  }
  
  // 3. Calculer l'erreur d'angle
  double angle_error = target_bearing - robot_heading;
  angle_error = normalizeAngleDiff(angle_error);
  
  Serial.print("Erreur d'angle: ");
  Serial.print(angle_error, 1);
  Serial.print("° | ");
  
  // 4. Décider de l'action
  if (abs(angle_error) > ANGLE_TOLERANCE) {
    // Besoin de tourner
    Serial.print("🔄 Rotation ");
    
    if (angle_error > 0) {
      Serial.println("droite");
      turnRight();
    } else {
      Serial.println("gauche");
      turnLeft();
    }
  } else {
    // Direction correcte, avancer
    Serial.println("➡️ Avance");
    goForward();
  }
}

// === CALCULS GÉOGRAPHIQUES ===

double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  // Formule de Haversine
  const double R = 6371000.0; // Rayon de la Terre en mètres
  
  double dLat = toRadians(lat2 - lat1);
  double dLng = toRadians(lng2 - lng1);
  
  double a = sin(dLat/2) * sin(dLat/2) + 
             cos(toRadians(lat1)) * cos(toRadians(lat2)) * 
             sin(dLng/2) * sin(dLng/2);
             
  double c = 2 * atan2(sqrt(a), sqrt(1-a));
  
  return R * c;
}

double calculateBearing(double lat1, double lng1, double lat2, double lng2) {
  // Calcule la direction du point 1 vers le point 2
  double dLng = toRadians(lng2 - lng1);
  
  double y = sin(dLng) * cos(toRadians(lat2));
  double x = cos(toRadians(lat1)) * sin(toRadians(lat2)) - 
             sin(toRadians(lat1)) * cos(toRadians(lat2)) * cos(dLng);
             
  double bearing = toDegrees(atan2(y, x));
  
  return normalizeAngle(bearing);
}

// === UTILITAIRES ANGLES ===

double normalizeAngle(double angle) {
  while (angle >= 360.0) angle -= 360.0;
  while (angle < 0.0) angle += 360.0;
  return angle;
}

double normalizeAngleDiff(double angle_diff) {
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

// === FONCTIONS MPU-9250 ===

void setupMPU9250() {
  Serial.print("Initialisation MPU-9250... ");
  
  // Réveiller le MPU-9250
  Wire.beginTransmission(MPU9250_ADDR);
  Wire.write(0x6B);  // PWR_MGMT_1
  Wire.write(0x00);  // Réveiller
  byte error = Wire.endTransmission(true);
  
  if (error != 0) {
    Serial.println("❌ Erreur MPU-9250");
    mpu_ok = false;
    return;
  }
  
  // Configuration du gyroscope
  Wire.beginTransmission(MPU9250_ADDR);
  Wire.write(0x1B);  // GYRO_CONFIG
  Wire.write(0x00);  // ±250°/s
  Wire.endTransmission(true);
  
  mpu_ok = true;
  Serial.println("✅ OK");
  
  // Initialiser le magnétomètre
  setupMagnetometer();
  
  if (mag_ok) {
    Serial.println("🧭 Calibration de la boussole recommandée (commande 'calibrate')");
  }
}

void setupMagnetometer() {
  Serial.print("Initialisation magnétomètre... ");
  
  // Activer le mode bypass pour accéder au magnétomètre
  Wire.beginTransmission(MPU9250_ADDR);
  Wire.write(0x37);  // INT_PIN_CFG
  Wire.write(0x02);  // BYPASS_EN
  Wire.endTransmission(true);
  
  delay(10);
  
  // Configurer le magnétomètre AK8963
  Wire.beginTransmission(MAG_ADDR);
  Wire.write(0x0A);  // CNTL1
  Wire.write(0x16);  // Mode continu 16-bit
  byte error = Wire.endTransmission(true);
  
  if (error == 0) {
    mag_ok = true;
    Serial.println("✅ OK");
  } else {
    mag_ok = false;
    Serial.println("❌ Erreur");
  }
}

bool readMagnetometer(float &mag_x, float &mag_y, float &mag_z) {
  if (!mag_ok) return false;
  
  // Vérifier si les données sont prêtes
  Wire.beginTransmission(MAG_ADDR);
  Wire.write(0x02);  // ST1
  Wire.endTransmission(false);
  Wire.requestFrom(MAG_ADDR, 1, true);
  
  if (Wire.available() && (Wire.read() & 0x01)) {
    // Lire les 6 bytes de données + ST2
    Wire.beginTransmission(MAG_ADDR);
    Wire.write(0x03);  // HXL
    Wire.endTransmission(false);
    Wire.requestFrom(MAG_ADDR, 7, true);
    
    if (Wire.available() >= 7) {
      int16_t raw_x = Wire.read() | (Wire.read() << 8);
      int16_t raw_y = Wire.read() | (Wire.read() << 8);
      int16_t raw_z = Wire.read() | (Wire.read() << 8);
      Wire.read(); // ST2
      
      // Conversion en µT (micro Tesla)
      mag_x = raw_x * 0.15;  // Sensibilité 16-bit
      mag_y = raw_y * 0.15;
      mag_z = raw_z * 0.15;
      
      return true;
    }
  }
  
  return false;
}

void calibrateCompass() {
  if (!mag_ok) {
    Serial.println("❌ Magnétomètre non disponible");
    return;
  }
  
  Serial.println("🧭 CALIBRATION DE LA BOUSSOLE");
  Serial.println("Faites tourner le robot lentement sur 360° pendant 20 secondes...");
  Serial.println("Démarrage dans 3 secondes...");
  delay(3000);
  
  float min_x = 1000, max_x = -1000;
  float min_y = 1000, max_y = -1000;
  
  unsigned long start_time = millis();
  int samples = 0;
  
  while (millis() - start_time < 20000) {  // 20 secondes
    float mag_x, mag_y, mag_z;
    if (readMagnetometer(mag_x, mag_y, mag_z)) {
      if (mag_x < min_x) min_x = mag_x;
      if (mag_x > max_x) max_x = mag_x;
      if (mag_y < min_y) min_y = mag_y;
      if (mag_y > max_y) max_y = mag_y;
      
      samples++;
      
      // Affichage du progrès
      if (samples % 10 == 0) {
        int progress = ((millis() - start_time) * 100) / 20000;
        Serial.print("Progrès: ");
        Serial.print(progress);
        Serial.print("% | X: ");
        Serial.print(mag_x, 1);
        Serial.print(" | Y: ");
        Serial.println(mag_y, 1);
      }
    }
    delay(50);
  }
  
  // Calculer les offsets et échelles
  mag_offset_x = (max_x + min_x) / 2.0;
  mag_offset_y = (max_y + min_y) / 2.0;
  
  float range_x = max_x - min_x;
  float range_y = max_y - min_y;
  float avg_range = (range_x + range_y) / 2.0;
  
  mag_scale_x = avg_range / range_x;
  mag_scale_y = avg_range / range_y;
  
  Serial.println("✅ Calibration terminée!");
  Serial.print("Offset X: "); Serial.print(mag_offset_x, 2);
  Serial.print(" | Y: "); Serial.println(mag_offset_y, 2);
  Serial.print("Scale X: "); Serial.print(mag_scale_x, 3);
  Serial.print(" | Y: "); Serial.println(mag_scale_y, 3);
  Serial.println("Calibration sauvegardée pour cette session.");
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
    calibrateCompass();
  }
  else if (cmd == "compass") {
    showCompass();
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
  if (!mag_ok) {
    Serial.println("❌ Boussole non disponible");
    return;
  }
  
  navigating = true;
  Serial.println("🚀 NAVIGATION DÉMARRÉE");
}

void stopNavigation() {
  navigating = false;
  stopMotors();
  Serial.println("🛑 Navigation arrêtée");
}

void showCompass() {
  if (!mag_ok) {
    Serial.println("❌ Boussole non disponible");
    return;
  }
  
  Serial.println("🧭 AFFICHAGE BOUSSOLE (10 lectures)");
  for (int i = 0; i < 10; i++) {
    float mag_x, mag_y, mag_z;
    if (readMagnetometer(mag_x, mag_y, mag_z)) {
      Serial.print("Direction: ");
      Serial.print(robot_heading, 1);
      Serial.print("° | Mag X: ");
      Serial.print(mag_x, 1);
      Serial.print(" | Y: ");
      Serial.print(mag_y, 1);
      Serial.print(" | Z: ");
      Serial.println(mag_z, 1);
    }
    delay(500);
  }
}

void printStatus() {
  Serial.println("=== ÉTAT ACTUEL ===");
  Serial.print("GPS: "); Serial.println(position_valid ? "✅ OK" : "❌ Pas de signal");
  Serial.print("MPU-9250: "); Serial.println(mpu_ok ? "✅ OK" : "❌ Erreur");
  Serial.print("Boussole: "); Serial.println(mag_ok ? "✅ OK" : "❌ Erreur");
  Serial.print("Destination: "); Serial.println(target_set ? "✅ Définie" : "❌ Non définie");
  Serial.print("Navigation: "); Serial.println(navigating ? "🚀 Active" : "⏸️ Arrêtée");
  
  if (position_valid) {
    Serial.print("Position: "); Serial.print(current_lat, 6); 
    Serial.print(", "); Serial.println(current_lng, 6);
  }
  if (mag_ok) {
    Serial.print("Direction robot: "); Serial.print(robot_heading, 1); Serial.println("°");
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

// === CONVERSION DMS VERS DÉCIMAL ===

double parseDMS(String dms) {
  dms.trim();
  
  int deg_pos = dms.indexOf('°');
  int min_pos = dms.indexOf('\'');
  int sec_pos = dms.indexOf('"');
  
  if (deg_pos == -1 || min_pos == -1 || sec_pos == -1) return NAN;
  
  double degrees = dms.substring(0, deg_pos).toFloat();
  double minutes = dms.substring(deg_pos + 1, min_pos).toFloat();
  double seconds = dms.substring(min_pos + 1, sec_pos).toFloat();
  
  double decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);
  
  char direction = dms.charAt(dms.length() - 1);
  if (direction == 'S' || direction == 'W') {
    decimal = -decimal;
  }
  
  return decimal;
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
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, FORWARD_SPEED);
  analogWrite(PWMB, FORWARD_SPEED);
}

void turnRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, LOW);
  analogWrite(PWMA, TURN_SPEED);
  analogWrite(PWMB, TURN_SPEED);
}

void turnLeft() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, TURN_SPEED);
  analogWrite(PWMB, TURN_SPEED);
}

void stopMotors() {
  digitalWrite(STBY, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
}