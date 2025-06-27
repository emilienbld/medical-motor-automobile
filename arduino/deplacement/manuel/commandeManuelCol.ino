#include <WiFiS3.h>
#include <Servo.h>

// ===== CAPTEUR DISTANCE SIMPLE =====
const int trigPin = 13;
const int echoPin = 12;
float lastValidDistance = 999.0;
unsigned long lastMeasure = 0;
const unsigned long measureInterval = 300;

// ===== SERVO SIMPLE =====
Servo scanServo;
int currentAngle = 90;

// ===== CONFIGURATION =====
const char* ssid = "MMA";
const char* password = "12345678";
WiFiServer server(80);

#define PWMA 5
#define PWMB 6  
#define AIN 7
#define BIN 8
#define STBY 3
#define SERVO_PIN 10

const float OBSTACLE_DISTANCE_CM = 30.0;
bool obstacleDetected = false;

// Variables rotation
unsigned long rotationStartTime = 0;
bool isRotating = false;
const unsigned long ROTATION_90_DURATION = 200;

// Optimisation WiFi
unsigned long lastClientTime = 0;
const unsigned long CLIENT_TIMEOUT = 100;

// ===== FONCTIONS CAPTEUR =====
float measureDistance() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 25000);
  
  if (duration > 0) {
    float distance = (duration * 0.034) / 2.0;
    if (distance <= 400) {
      return distance;
    }
  }
  return 999.0;
}

bool updateDistance() {
  unsigned long now = millis();
  if (now - lastMeasure < measureInterval) return false;
  
  float distance = measureDistance();
  
  Serial.print("🔍 Angle ");
  Serial.print(currentAngle);
  Serial.print("° -> ");
  Serial.print(distance);
  Serial.println(" cm");
  
  if (distance < 999.0) {
    lastValidDistance = distance;
  }
  
  lastMeasure = now;
  return true;
}

// ===== FONCTIONS SERVO =====
float scanDirection(int angle) {
  angle = constrain(angle, 0, 180);
  
  Serial.print("🔄 Rotation servo vers ");
  Serial.print(angle);
  Serial.print("°...");
  
  scanServo.write(angle);
  currentAngle = angle;
  delay(1000); // Délai plus long pour être sûr
  
  float distance = measureDistance();
  
  Serial.print(" Distance: ");
  Serial.print(distance);
  Serial.println(" cm");
  
  return distance;
}

bool checkLeftSafe(float threshold = 30.0) {
  Serial.println("👈 Scan GAUCHE (150°)");
  float leftDistance = scanDirection(150);
  bool safe = (leftDistance > threshold);
  
  Serial.print("   Gauche ");
  Serial.print(safe ? "✅ LIBRE" : "❌ BLOQUÉ");
  Serial.print(" (");
  Serial.print(leftDistance);
  Serial.println(" cm)");
  
  return safe;
}

bool checkRightSafe(float threshold = 30.0) {
  Serial.println("👉 Scan DROITE (30°)");
  float rightDistance = scanDirection(30);
  bool safe = (rightDistance > threshold);
  
  Serial.print("   Droite ");
  Serial.print(safe ? "✅ LIBRE" : "❌ BLOQUÉ");
  Serial.print(" (");
  Serial.print(rightDistance);
  Serial.println(" cm)");
  
  return safe;
}

void returnToCenter() {
  if (currentAngle != 90) {
    Serial.println("🎯 Retour au centre (90°)");
    scanServo.write(90);
    currentAngle = 90;
    delay(1000);
  }
}

void setup() {
  pinMode(PWMA, OUTPUT);
  pinMode(PWMB, OUTPUT);
  pinMode(AIN, OUTPUT);
  pinMode(BIN, OUTPUT);
  pinMode(STBY, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  Serial.begin(115200);
  Serial.println("=== Robot MMA v5.0 SERVO SIMPLE ===");
  
  // INITIALISATION SERVO
  Serial.println("🤖 Initialisation servo...");
  scanServo.attach(SERVO_PIN);
  scanServo.write(90);
  currentAngle = 90;
  delay(1000);
  Serial.println("✅ Servo attaché sur pin " + String(SERVO_PIN));
  
  digitalWrite(STBY, LOW);
  stopMotors();
  
  // Test servo
  Serial.println("\n🔄 Test scan 180°:");
  for(int angle = 30; angle <= 150; angle += 30) {
    scanDirection(angle);
    delay(500);
  }
  
  returnToCenter();
  Serial.println("✅ Servo scanner opérationnel !");
  
  WiFi.beginAP(ssid, password);
  delay(1000);
  
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  server.begin();
  Serial.println("✅ Robot prêt avec détection 180° !");
}

void loop() {
  checkRotationTimeout();
  
  // Mise à jour distance
  if (updateDistance()) {
    bool wasObstacle = obstacleDetected;
    float currentDist = lastValidDistance;
    obstacleDetected = (currentDist <= OBSTACLE_DISTANCE_CM && currentDist > 0);
    
    if (obstacleDetected != wasObstacle) {
      Serial.print(">>> CHANGEMENT: ");
      Serial.println(obstacleDetected ? "🚨 OBSTACLE DÉTECTÉ" : "✅ VOIE LIBRE");
    }
  }
  
  // Arrêt sécurité
  if (obstacleDetected && !isRotating) {
    Serial.println("🛑 ARRÊT SÉCURITÉ");
    stopMotors();
  }
  
  handleWiFiClients();
  
  if (Serial.available()) {
    handleSerialCommand();
  }
}

void handleWiFiClients() {
  WiFiClient client = server.available();
  if (!client) return;
  
  lastClientTime = millis();
  
  String request = "";
  while (client.connected() && (millis() - lastClientTime < CLIENT_TIMEOUT)) {
    if (client.available()) {
      request += client.readStringUntil('\n');
      break;
    }
  }
  
  processCommand(request, client);
  client.stop();
}

void processCommand(String request, WiFiClient& client) {
  int dirPos = request.indexOf("dir=");
  if (dirPos == -1) {
    quickResponse(client, "INVALID");
    return;
  }
  
  String cmd = request.substring(dirPos + 4);
  int endPos = cmd.indexOf(' ');
  if (endPos != -1) cmd = cmd.substring(0, endPos);
  
  if (cmd == "status") {
    client.println("HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\nConnection: close\n");
    client.print("{\"distance\":");
    client.print(lastValidDistance);
    client.print(",\"obstacle\":");
    client.print(obstacleDetected ? "true" : "false");
    client.println("}");
    return;
  }
  
  // SCAN AUTOMATIQUE
  bool blocked = false;
  
  if (cmd.indexOf("forward") != -1 && obstacleDetected) {
    blocked = true;
  }
  
  if (cmd == "left" || cmd == "forward_left" || cmd == "backward_left") {
    Serial.println("🔍 SCAN GAUCHE automatique...");
    if (!checkLeftSafe(OBSTACLE_DISTANCE_CM)) {
      Serial.println("❌ MOUVEMENT GAUCHE BLOQUÉ - Obstacle détecté !");
      blocked = true;
    }
    returnToCenter();
  }
  else if (cmd == "right" || cmd == "forward_right" || cmd == "backward_right") {
    Serial.println("🔍 SCAN DROITE automatique...");
    if (!checkRightSafe(OBSTACLE_DISTANCE_CM)) {
      Serial.println("❌ MOUVEMENT DROITE BLOQUÉ - Obstacle détecté !");
      blocked = true;
    }
    returnToCenter();
  }
  
  Serial.print("🎮 Commande: " + cmd);
  Serial.print(" | Bloquée: ");
  Serial.println(blocked ? "OUI" : "NON");
  
  if (!blocked) {
    executeMovement(cmd);
  }
  
  quickResponse(client, blocked ? "BLOCKED" : "OK");
}

void quickResponse(WiFiClient& client, String response) {
  client.println("HTTP/1.1 200 OK");
  client.println("Access-Control-Allow-Origin: *");
  client.println("Connection: close");
  client.println();
  client.println(response);
}

void executeMovement(String cmd) {
  if (cmd == "forward") forward();
  else if (cmd == "backward") backward();
  else if (cmd == "left") rotateLeft90();
  else if (cmd == "right") rotateRight90();
  else if (cmd == "forward_right") forwardRight();
  else if (cmd == "forward_left") forwardLeft();
  else if (cmd == "backward_right") backwardRight();
  else if (cmd == "backward_left") backwardLeft();
  else if (cmd == "stop") {
    stopMotors();
    isRotating = false;
  }
}

void checkRotationTimeout() {
  if (isRotating && (millis() - rotationStartTime >= ROTATION_90_DURATION)) {
    stopMotors();
    isRotating = false;
  }
}

void handleSerialCommand() {
  char cmd = Serial.read();
  bool blocked = false;
  
  Serial.print("💻 COMMANDE SÉRIE: ");
  Serial.print(cmd);
  
  switch (cmd) {
    case 'z':
      if (!obstacleDetected) {
        Serial.println(" -> FORWARD autorisé");
        forward(); 
      } else {
        Serial.println(" -> FORWARD BLOQUÉ");
        blocked = true;
      }
      break;
    case 's': 
      Serial.println(" -> BACKWARD");
      backward(); 
      break;
    case 'q': 
      Serial.println(" -> LEFT avec scan...");
      if (checkLeftSafe(OBSTACLE_DISTANCE_CM)) {
        returnToCenter();
        rotateLeft90();
      } else {
        returnToCenter();
        Serial.println("❌ ROTATION GAUCHE BLOQUÉE");
        blocked = true;
      }
      break;
    case 'd': 
      Serial.println(" -> RIGHT avec scan...");
      if (checkRightSafe(OBSTACLE_DISTANCE_CM)) {
        returnToCenter();
        rotateRight90();
      } else {
        returnToCenter();
        Serial.println("❌ ROTATION DROITE BLOQUÉE");
        blocked = true;
      }
      break;
    case 'x': 
      Serial.println(" -> STOP");
      stopMotors(); 
      isRotating = false; 
      break;
    case 'i':
      Serial.print(" -> INFO: Distance ");
      Serial.print(lastValidDistance); 
      Serial.println("cm");
      break;
    case 'r':
      Serial.println(" -> SCAN 180°");
      for(int angle = 30; angle <= 150; angle += 30) {
        scanDirection(angle);
        delay(300);
      }
      returnToCenter();
      break;
    default:
      Serial.println(" -> INCONNUE");
      break;
  }
  
  if (blocked) Serial.println("❌ COMMANDE BLOQUÉE PAR SÉCURITÉ");
}

// ===== FONCTIONS MOTEUR =====
void forward() {
  isRotating = false;
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, 200);
  analogWrite(PWMB, 200);
}

void backward() {
  isRotating = false;
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);
  digitalWrite(BIN, LOW);
  analogWrite(PWMA, 200);
  analogWrite(PWMB, 200);
}

void rotateLeft90() {
  isRotating = true;
  rotationStartTime = millis();
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, LOW);
  analogWrite(PWMA, 220);
  analogWrite(PWMB, 220);
}

void rotateRight90() {
  isRotating = true;
  rotationStartTime = millis();
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, 220);
  analogWrite(PWMB, 220);
}

void forwardRight() {
  isRotating = false;
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, 140);
  analogWrite(PWMB, 200);
}

void forwardLeft() {
  isRotating = false;
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);
  digitalWrite(BIN, HIGH);
  analogWrite(PWMA, 200);
  analogWrite(PWMB, 140);
}

void backwardRight() {
  isRotating = false;
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);
  digitalWrite(BIN, LOW);
  analogWrite(PWMA, 140);
  analogWrite(PWMB, 200);
}

void backwardLeft() {
  isRotating = false;
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);
  digitalWrite(BIN, LOW);
  analogWrite(PWMA, 200);
  analogWrite(PWMB, 140);
}

void stopMotors() {
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
  digitalWrite(STBY, LOW);
}