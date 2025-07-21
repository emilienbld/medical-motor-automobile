#include "wifi_handler.h"
#include "robot_controller.h"

WiFiHandler::WiFiHandler(RobotController* robotController) 
    : server(WIFI_PORT), lastClientTime(0), robot(robotController) {
}

void WiFiHandler::init() {
    WiFi.beginAP(WIFI_SSID, WIFI_PASSWORD);
    delay(1000);
    
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    server.begin();
    Serial.println("✅ Serveur WiFi démarré");
}

void WiFiHandler::handleClients() {
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

void WiFiHandler::processCommand(String request, WiFiClient& client) {
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
        client.print(robot->getDistance());
        client.print(",\"obstacle\":");
        client.print(robot->isObstacleDetected() ? "true" : "false");
        client.print(",\"gps_valid\":");
        client.print(robot->isGPSValid() ? "true" : "false");
        if (robot->isGPSValid()) {
            client.print(",\"latitude\":");
            client.print(robot->getGPSLatitude(), 6);
            client.print(",\"longitude\":");
            client.print(robot->getGPSLongitude(), 6);
        }
        client.print(",\"gyro_ok\":");
        client.print(robot->isGyroOK() ? "true" : "false");
        if (robot->isGyroOK()) {
            client.print(",\"angle\":");
            client.print(robot->getRobotAngle(), 1);
        }
        client.print(",\"navigating\":");
        client.print(robot->isNavigating() ? "true" : "false");
        client.println("}");
        return;
    }
    
    // Traitement des commandes par le robot
    bool blocked = false;
    
    // Bloquer les mouvements manuels si navigation GPS active
    if (robot->isNavigating() && (cmd == "forward" || cmd == "backward" || cmd == "left" || cmd == "right" || 
                                 cmd == "forward_left" || cmd == "forward_right" || cmd == "backward_left" || cmd == "backward_right")) {
        Serial.println("❌ MOUVEMENT BLOQUÉ - Navigation GPS active");
        blocked = true;
    } else {
        blocked = robot->processMovementCommand(cmd);
    }
    
    Serial.print("🎮 Commande WiFi: " + cmd);
    Serial.print(" | Bloquée: ");
    Serial.println(blocked ? "OUI" : "NON");
    
    quickResponse(client, blocked ? "BLOCKED" : "OK");
}

void WiFiHandler::quickResponse(WiFiClient& client, String response) {
    client.println("HTTP/1.1 200 OK");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    client.println(response);
}