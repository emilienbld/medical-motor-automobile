#ifndef WIFI_HANDLER_H
#define WIFI_HANDLER_H

#include <Arduino.h>
#include <WiFiS3.h>
#include "config.h"

class RobotController; // Forward declaration

class WiFiHandler {
private:
    WiFiServer server;
    unsigned long lastClientTime;
    RobotController* robot;
    
    void quickResponse(WiFiClient& client, String response);
    
public:
    WiFiHandler(RobotController* robotController);
    void init();
    void handleClients();
    void processCommand(String request, WiFiClient& client);
};

#endif