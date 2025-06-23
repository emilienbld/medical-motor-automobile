#include <WiFiS3.h>

// Configuration WiFi
const char* ssid = "MMA";  // Nom du réseau WiFi
const char* password = "12345678";  // Mot de passe (minimum 8 caractères)
WiFiServer server(80);

// Configuration des moteurs
#define PWMA 5    // Right motor power
#define PWMB 6    // Left motor power
#define AIN 7     // Right motor direction
#define BIN 8     // Left motor direction
#define STBY 3    // Motor enable/disable

char command = 0;

void setup() {
  // Configuration des pins moteurs
  pinMode(PWMA, OUTPUT);
  pinMode(PWMB, OUTPUT);
  pinMode(AIN, OUTPUT);
  pinMode(BIN, OUTPUT);
  pinMode(STBY, OUTPUT);
  pinMode(LED_BUILTIN, OUTPUT);

  Serial.begin(9600);
  Serial.println("=== Démarrage Robot MMA v2.2 (Moteurs corrigés) ===");
  
  // Désactiver les moteurs au démarrage
  digitalWrite(STBY, LOW);
  stopMotors();
  
  // Créer le point d'accès WiFi
  Serial.print("Création du point d'accès MMA... ");
  WiFi.beginAP(ssid, password);
  
  // Attendre que l'AP soit prêt
  delay(2000);
  
  // Afficher les informations de connexion
  IPAddress IP = WiFi.localIP();
  Serial.println("OK!");
  Serial.println("================================");
  Serial.print("Nom du WiFi (SSID): ");
  Serial.println(ssid);
  Serial.print("Mot de passe: ");
  Serial.println(password);
  Serial.print("Adresse IP: ");
  Serial.println(IP);
  Serial.println("================================");
  
  // Démarrer le serveur web
  server.begin();
  Serial.println("Serveur web démarré sur port 80");
  Serial.println("\nPrêt pour la connexion!");
  Serial.println("Contrôles disponibles:");
  Serial.println("- Application Flutter (WiFi)");
  Serial.println("- Terminal série (Z/Q/S/D/X)");
  Serial.println("- Mouvements diagonaux supportés");
  Serial.println("- Rotations corrigées");
  
  // Faire clignoter la LED pour indiquer que c'est prêt
  for(int i = 0; i < 5; i++) {
    digitalWrite(LED_BUILTIN, HIGH);
    delay(100);
    digitalWrite(LED_BUILTIN, LOW);
    delay(100);
  }
}

void loop() {
  // PARTIE 1: Gestion des connexions WiFi
  WiFiClient client = server.available();
  
  if (client) {
    digitalWrite(LED_BUILTIN, HIGH); // LED ON = client connecté
    Serial.println("\n--- Client connecté ---");
    
    String request = "";
    boolean currentLineIsBlank = true;
    
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        request += c;
        
        if (c == '\n' && currentLineIsBlank) {
          // On a reçu toute la requête HTTP
          processHTTPRequest(request, client);
          break;
        }
        
        if (c == '\n') {
          currentLineIsBlank = true;
        } else if (c != '\r') {
          currentLineIsBlank = false;
        }
      }
    }
    
    delay(10);
    client.stop();
    digitalWrite(LED_BUILTIN, LOW);
    Serial.println("--- Client déconnecté ---");
  }
  
  // PARTIE 2: Contrôle via le terminal série
  if (Serial.available() > 0) {
    command = Serial.read();
    Serial.print("Commande série: ");
    Serial.println(command);
    handleCommand(command);
  }
}

// Fonction SIMPLIFIÉE pour traiter les requêtes HTTP
void processHTTPRequest(String request, WiFiClient& client) {
  Serial.println("Requête reçue:");
  
  // Extraire le path de la requête
  int firstSpace = request.indexOf(' ');
  int secondSpace = request.indexOf(' ', firstSpace + 1);
  String path = request.substring(firstSpace + 1, secondSpace);
  
  Serial.print("Path: ");
  Serial.println(path);
  
  // Traiter les commandes de mouvement du joystick
  if (path.startsWith("/move?dir=")) {
    // Extraire la direction
    int dirStart = path.indexOf("dir=") + 4;
    int dirEnd = path.indexOf("&", dirStart);
    if (dirEnd == -1) dirEnd = path.length();
    String direction = path.substring(dirStart, dirEnd);
    
    // IGNORER le paramètre speed pour éviter les problèmes
    Serial.print("Direction: ");
    Serial.println(direction);
    
    // Convertir la direction en commande SIMPLE (vitesse fixe)
    if (direction == "forward") {
      Serial.println("-> Commande: AVANCER");
      forward();
    } 
    else if (direction == "backward") {
      Serial.println("-> Commande: RECULER");
      backward();
    } 
    else if (direction == "left") {
      Serial.println("-> Commande: GAUCHE");
      left();
    } 
    else if (direction == "right") {
      Serial.println("-> Commande: DROITE");
      right();
    }
    // Mouvements diagonaux SIMPLES
    else if (direction == "forward_right") {
      Serial.println("-> Commande: AVANCER-DROITE");
      forwardRight();
    }
    else if (direction == "forward_left") {
      Serial.println("-> Commande: AVANCER-GAUCHE");
      forwardLeft();
    }
    else if (direction == "backward_right") {
      Serial.println("-> Commande: RECULER-DROITE");
      backwardRight();
    }
    else if (direction == "backward_left") {
      Serial.println("-> Commande: RECULER-GAUCHE");
      backwardLeft();
    }
    else if (direction == "stop") {
      Serial.println("-> Commande: STOP");
      stopMotors();
    }
    else {
      Serial.print("-> Commande inconnue: ");
      Serial.println(direction);
    }
    
    // Réponse HTTP OK
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: text/plain");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println("OK");
  }
  // Page de test/status
  else if (path == "/" || path == "/status") {
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: text/html; charset=utf-8");
    client.println("Connection: close");
    client.println();
    client.println("<!DOCTYPE HTML>");
    client.println("<html>");
    client.println("<head>");
    client.println("<title>Robot MMA v2.2 Corrigé</title>");
    client.println("<meta name='viewport' content='width=device-width, initial-scale=1'>");
    client.println("<style>");
    client.println("body { font-family: Arial; text-align: center; margin: 20px; background: #f0f0f0; }");
    client.println("h1 { color: #333; }");
    client.println(".status { background: #4CAF50; color: white; padding: 15px; border-radius: 8px; margin: 10px; }");
    client.println(".feature { background: #2196F3; color: white; padding: 10px; border-radius: 5px; margin: 5px; }");
    client.println("</style>");
    client.println("</head>");
    client.println("<body>");
    client.println("<h1>🤖 Robot MMA v2.2 Corrigé</h1>");
    client.println("<div class='status'>✓ Serveur actif et prêt</div>");
    client.println("<p><strong>IP:</strong> 192.168.4.1</p>");
    client.println("<div class='feature'>✅ Rotations corrigées</div>");
    client.println("<div class='feature'>✅ Mouvements 8 directions</div>");
    client.println("<div class='feature'>✅ Consommation optimisée</div>");
    client.println("<p>Utilisez l'application Flutter pour contrôler le robot</p>");
    client.println("</body>");
    client.println("</html>");
  }
  else {
    // 404 Not Found
    client.println("HTTP/1.1 404 Not Found");
    client.println("Connection: close");
    client.println();
  }
}

// Fonction de gestion des commandes (pour terminal série)
void handleCommand(char cmd) {
  digitalWrite(STBY, HIGH); // Activer les moteurs

  switch (cmd) {
    case 'z':  // Avancer
      forward();  
      break;
    case 's':  // Reculer
      backward();
      break;
    case 'd':  // Tourner droite
      right();
      break;
    case 'q':  // Tourner gauche
      left();
      break;
    case 'x':  // Stop
      stopMotors();
      break;
    // Raccourcis pour diagonales
    case '1':  // Avancer-droite
      forwardRight();
      break;
    case '2':  // Avancer-gauche
      forwardLeft();
      break;
    case '3':  // Reculer-droite
      backwardRight();
      break;
    case '4':  // Reculer-gauche
      backwardLeft();
      break;
    default:
      Serial.println("Commande inconnue");
      Serial.println("Commandes disponibles: Z(avant) S(arrière) Q(gauche) D(droite) X(stop)");
      Serial.println("Diagonales: 1(av-droite) 2(av-gauche) 3(ar-droite) 4(ar-gauche)");
      break;
  }
}

// ===== FONCTIONS DE MOUVEMENT CORRIGÉES (UNE SEULE VERSION) =====

void forward() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);  // Moteur droit AVANT
  digitalWrite(BIN, HIGH);  // Moteur gauche AVANT
  analogWrite(PWMA, 200);   // Même vitesse
  analogWrite(PWMB, 200);   // Même vitesse
  Serial.println(">>> AVANCER (vitesse stable)");
}

void backward() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);   // Moteur droit ARRIÈRE
  digitalWrite(BIN, LOW);   // Moteur gauche ARRIÈRE
  analogWrite(PWMA, 200);
  analogWrite(PWMB, 200);
  Serial.println(">>> RECULER (vitesse stable)");
}

void left() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);  // Moteur droit AVANT (rapide)
  digitalWrite(BIN, LOW);   // Moteur gauche ARRIÈRE (ou stop)
  analogWrite(PWMA, 200);   // Droit rapide
  analogWrite(PWMB, 100);   // Gauche lent
  Serial.println(">>> GAUCHE (rotation)");
}

void right() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);   // Moteur droit ARRIÈRE (ou stop)  
  digitalWrite(BIN, HIGH);  // Moteur gauche AVANT (rapide)
  analogWrite(PWMA, 100);   // Droit lent
  analogWrite(PWMB, 200);   // Gauche rapide
  Serial.println(">>> DROITE (rotation)");
}

// ===== FONCTIONS DIAGONALES CORRIGÉES (comme avant mais avec nouvelles rotations) =====

void forwardRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);  // Moteur droit AVANT
  digitalWrite(BIN, HIGH);  // Moteur gauche AVANT
  analogWrite(PWMA, 140);   // Moteur droit ralenti pour tourner (0.7 * 200)
  analogWrite(PWMB, 200);   // Moteur gauche pleine puissance
  Serial.println(">>> AVANCER-DROITE (vitesse stable)");
}

void forwardLeft() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, HIGH);  // Moteur droit AVANT
  digitalWrite(BIN, HIGH);  // Moteur gauche AVANT
  analogWrite(PWMA, 200);   // Moteur droit pleine puissance
  analogWrite(PWMB, 140);   // Moteur gauche ralenti pour tourner (0.7 * 200)
  Serial.println(">>> AVANCER-GAUCHE (vitesse stable)");
}

void backwardRight() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);   // Moteur droit ARRIÈRE
  digitalWrite(BIN, LOW);   // Moteur gauche ARRIÈRE
  analogWrite(PWMA, 140);   // Moteur droit ralenti
  analogWrite(PWMB, 200);   // Moteur gauche pleine puissance
  Serial.println(">>> RECULER-DROITE (vitesse stable)");
}

void backwardLeft() {
  digitalWrite(STBY, HIGH);
  digitalWrite(AIN, LOW);   // Moteur droit ARRIÈRE
  digitalWrite(BIN, LOW);   // Moteur gauche ARRIÈRE
  analogWrite(PWMA, 200);   // Moteur droit pleine puissance
  analogWrite(PWMB, 140);   // Moteur gauche ralenti
  Serial.println(">>> RECULER-GAUCHE (vitesse stable)");
}

void stopMotors() {
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);
  digitalWrite(STBY, LOW);
  Serial.println(">>> STOP");
}