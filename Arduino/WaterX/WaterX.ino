#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include "icons.h"

#define VERSION "0.1.1"
#define SERIAL_NUM "IOT-HA-20250000" // Generated from 'https://www.barcodeocean.com/serial-number-generator' 

#define trigPin D5
#define echoPin D6
#define buzzerPin D7

#define SOUND_VELOCITY 0.034
#define MAX_DEPTH_CM 43.18  

#define BUZZER_ON_TIME 100
#define BUZZER_OFF_TIME 200

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

const char* ssid = "POGO";          
const char* password = "MjAwMzA1";   
ESP8266WebServer server(65500);

long duration;
float distanceCm;
int waterPercent;
String waterStatus;
unsigned long lastBuzzerTime = 0;
bool buzzerState = false;

void setup() {
  Serial.begin(115200);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(buzzerPin, OUTPUT);
  
  // Initialize display
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.display();

  // Connect to WiFi network
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  server.on("/api/readings", handleReadings);
  server.on("/api/status", handleStatus);
  server.onNotFound(handleNotFound);
  
  server.begin();
  Serial.println("Web server started");
}

void loop() {
  server.handleClient();
  
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  duration = pulseIn(echoPin, HIGH);
  distanceCm = duration * SOUND_VELOCITY / 2;


  waterPercent = constrain(100 - (distanceCm / MAX_DEPTH_CM * 100), 0, 100);

  display.clearDisplay();
  
  display.drawBitmap(0, 0, water_drop, ICON_WIDTH, ICON_HEIGHT, SSD1306_WHITE);
  display.setCursor(12, 0);
  display.setTextSize(1);
  display.println("WaterX");
  
  display.drawBitmap(0, 10, wifi_icon, ICON_WIDTH, ICON_HEIGHT, SSD1306_WHITE);
  display.setCursor(12, 10);
  display.print("IP: ");
  display.println(WiFi.localIP());
  
  display.setCursor(0, 20);
  display.print("Dist: ");
  display.print(distanceCm, 1);
  display.println("cm");
  
  display.setCursor(0, 32);
  display.print("Level: ");
  display.print(waterPercent);
  display.print("%");
  
  if (waterPercent < 50) {
    display.drawBitmap(80, 32, tank_low, ICON_WIDTH, ICON_HEIGHT, SSD1306_WHITE);
    display.setCursor(0, 48);
    display.print("LOW WATER");
    
    waterStatus = "LOW";

    digitalWrite(buzzerPin, LOW);
    Serial.println(" - LOW WATER");
  } else if (waterPercent < 70) {
    display.drawBitmap(80, 32, tank_med, ICON_WIDTH, ICON_HEIGHT, SSD1306_WHITE);
    display.setCursor(0, 48);
    display.print("MEDIUM WATER");
    
    waterStatus = "MEDIUM";

    digitalWrite(buzzerPin, HIGH);
    delay(100);
    digitalWrite(buzzerPin, LOW);
    Serial.println(" - MEDIUM WATER");
  } else {
    display.drawBitmap(80, 32, tank_high, ICON_WIDTH, ICON_HEIGHT, SSD1306_WHITE);
    display.setCursor(0, 48);
    display.print("HIGH WATER");
    display.drawBitmap(70, 48, warning, ICON_WIDTH, ICON_HEIGHT, SSD1306_WHITE);
    
    waterStatus = "HIGH";
    
    if (millis() - lastBuzzerTime > (buzzerState ? BUZZER_ON_TIME : BUZZER_OFF_TIME)) {
      buzzerState = !buzzerState;
      digitalWrite(buzzerPin, buzzerState ? HIGH : LOW);
      lastBuzzerTime = millis();
    }
    Serial.println(" - HIGH WATER - FLOOD ALERT");
  }
  
  display.display();

  delay(1000);
}

void handleReadings() {
  String json = "{";
  json += "\"distance\":" + String(distanceCm, 2) + ",";
  json += "\"waterLevel\":" + String(waterPercent) + ",";
  json += "\"status\":\"" + waterStatus + "\",";
  json += "\"timestamp\":" + String(millis()) + ",";
  json += "\"maxDepth\":" + String(MAX_DEPTH_CM, 2);
  json += "}";
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

void handleStatus() {
  String json = "{";
  json += "\"device\":\"WaterX\",";
  json += "\"version\":\"" + String(VERSION) + "\",";
  json += "\"iconsVersion\":\"" + String(ICONS_VERSION) + "\",";
  json += "\"serial_num\":\"" + String(SERIAL_NUM) + "\",";
  json += "\"uptime\":" + String(millis());
  json += "}";
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

void handleNotFound() {
  String response = "API endpoints: /api/readings, /api/status\n\n";
  response += " __      __         __              ____  ___\n";
  response += "/  \\    /  \\_____ _/  |_  __________\\   \\/  /\n";
  response += "\\   \\/\\/   /\\__  \\\\   __\\/ __ \\_  __ \\     / \n";
  response += " \\        /  / __ \\|  | \\  ___/|  | \\/     \\ \n";
  response += "  \\__/\\  /  (____  /__|  \\___  >__| /___/\\  \\\n";
  response += "       \\/        \\/          \\/           \\_/\n";
  response += "                                 By: AlienWolfX\n";
  response += "                                 Version: v" + String(VERSION) + "\n";
  
  server.send(404, "text/plain", response);
}
