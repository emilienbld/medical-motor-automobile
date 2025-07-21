#ifndef CONFIG_H
#define CONFIG_H

// ===== PINS CONFIGURATION =====
#define TRIG_PIN 13
#define ECHO_PIN 12
#define SERVO_PIN 10
#define PWMA 5
#define PWMB 6  
#define AIN 7
#define BIN 8
#define STBY 3

// ===== DISTANCE SENSOR CONFIGURATION =====
const unsigned long MEASURE_INTERVAL = 300;
const float MAX_VALID_DISTANCE = 400.0;
const float INVALID_DISTANCE = 999.0;
const unsigned long PULSE_TIMEOUT = 25000;

// ===== OBSTACLE DETECTION =====
const float OBSTACLE_DISTANCE_CM = 30.0;

// ===== SERVO CONFIGURATION =====
const int SERVO_CENTER = 90;
const int SERVO_LEFT = 150;
const int SERVO_RIGHT = 30;
const int SERVO_MIN = 0;
const int SERVO_MAX = 180;
const unsigned long SERVO_DELAY = 1000;

// ===== MOTOR CONFIGURATION =====
const int MOTOR_SPEED_NORMAL = 200;
const int MOTOR_SPEED_TURN = 220;
const int MOTOR_SPEED_CURVE = 140;
const unsigned long ROTATION_90_DURATION = 200;

// ===== WIFI CONFIGURATION =====
#define WIFI_SSID "MMA"
#define WIFI_PASSWORD "12345678"
const int WIFI_PORT = 80;
const unsigned long CLIENT_TIMEOUT = 100;

// ===== GPS CONFIGURATION =====
const int GPS_RX_PIN = A2;
const int GPS_TX_PIN = A1;
const unsigned long GPS_BAUD = 9600;

// ===== MPU-6500 CONFIGURATION =====
const int MPU6500_ADDR = 0x68;
const int GYRO_SAMPLES_CALIBRATION = 500;
const unsigned long MIN_GYRO_INTERVAL = 10; 


const double ARRIVAL_DISTANCE = 3.0;     
const double ANGLE_TOLERANCE = 6.0;       
const int FORWARD_SPEED = 150;            
const int MIN_TURN_SPEED = 100;           
const int MAX_TURN_SPEED = 180;           


const unsigned long SERIAL_BAUD = 115200; 



#endif