#include <ESP8266WiFi.h>
#include <ESPAsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <Servo.h>

// Replace with your network credentials
const char *ssid = "fbnet2.4Ghz";
const char *password = "lichenesecco1lichenesecco1";

// Define static IP settings for 192.168.0.x network
IPAddress local_IP(192, 168, 0, 184); // The static IP address

// Define the turning degrees for the servo
int turningDegrees = 90;

// Create AsyncWebServer object on port 80
AsyncWebServer server(80);

// Create a servo object
Servo servo;

// Define the servo pin
const int servoPin = D1; // Adjust according to your setup

void setup()
{
  // Start the Serial Monitor
  Serial.begin(115200);

  // Set up the servo
  servo.attach(servoPin);

  Serial.println();
  Serial.println("CONFIGURATION PARAMETERS:");
  Serial.println("WLAN SSID: " + String(ssid));
  Serial.println("WLAN Password: " + String(password));
  Serial.print("Device IP: ");
  Serial.println(local_IP);
  Serial.print("Servo PIN: ");
  Serial.println(servoPin);
  Serial.print("Turning Degrees: ");
  Serial.println(turningDegrees);

  // Setting the servo to start position
  servo.write(0); // Move back to 0 degrees

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  unsigned long startAttemptTime = millis();

  // Wait for connection or timeout after 60 seconds
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 60000)
  {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }

  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("Failed to connect to WiFi");
  }
  else
  {
    // Set static IP address only after connection
    if (!WiFi.config(local_IP, WiFi.gatewayIP(), WiFi.subnetMask()))
    {
      Serial.println("STA Failed to configure");
    }

    Serial.println("Connected to WiFi");

    // Define the GET request handling for the servo
    server.on("/press", HTTP_GET, [](AsyncWebServerRequest *request)
              {
                // Move the servo
                servo.write(turningDegrees);   // Move to specified degrees
                delay(500);                    // Wait for half second
                servo.write(0);                // Move back to 0 degrees
                request->send(200, "text/plain", "SUCCESS");
                Serial.println("Button press request received"); });

    // Define the GET request handling for the areyoualive endpoint
    server.on("/areyoualive", HTTP_GET, [](AsyncWebServerRequest *request)
              { request->send(200, "text/plain", "OK");
                Serial.println("Are you alive request received"); });

    // Start server
    server.begin();
    Serial.println("Server started");

    Serial.print("Device IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("Gateway IP: ");
    Serial.println(WiFi.gatewayIP());
    Serial.print("Subnet Mask: ");
    Serial.println(WiFi.subnetMask());
  }
}

void loop()
{
  // Continuously check WiFi status
  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("WiFi connection lost, attempting to reconnect...");
    WiFi.begin(ssid, password);
    unsigned long startAttemptTime = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 60000)
    {
      delay(1000);
      Serial.println("Reconnecting to WiFi...");
    }

    if (WiFi.status() == WL_CONNECTED)
    {
      Serial.println("Reconnected to WiFi");
      Serial.print("Device IP: ");
      Serial.println(WiFi.localIP());
    }
    else
    {
      Serial.println("Failed to reconnect to WiFi");
    }
  }
}
