#include <ESP8266WiFi.h>
#include <ESPAsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <Servo.h>

// Replace with your network credentials
const char *ssid = "";
const char *password = "";

// Define static IP settings for 192.168.0.x network
IPAddress local_IP(192, 168, 0, 184); // The static IP address

// Define the turning degrees for the servo
int turningDegrees = 90;

// Define how long the servo stays in the pressed position (in milliseconds)
int pressDuration = 500; // Default: 1 second

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
  Serial.print("Press Duration (ms): ");
  Serial.println(pressDuration);

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
                // Move the servo to the specified angle and keep it for the duration
                servo.write(turningDegrees);  // Move to specified degrees
                Serial.printf("Servo moved to %d degrees\n", turningDegrees);

                delay(pressDuration); // Keep it in the position for the specified duration

                servo.write(0); // Move back to 0 degrees
                Serial.printf("Servo returned to 0 degrees after %d ms\n", pressDuration);

                request->send(200, "text/plain", "SUCCESS");
                Serial.println("Button press request received"); });

    // Define the GET request handling for the areyoualive endpoint
    server.on("/areyoualive", HTTP_GET, [](AsyncWebServerRequest *request)
              { request->send(200, "text/plain", "OK");
                Serial.println("Are you alive request received"); });

    // New endpoint to move servo to a specified angle for a specified duration
    server.on("/test", HTTP_GET, [](AsyncWebServerRequest *request)
              {
                if (request->hasParam("angle") && request->hasParam("duration")) {
                  String angleParam = request->getParam("angle")->value();
                  String durationParam = request->getParam("duration")->value();
                  
                  int angle = angleParam.toInt();
                  int duration = durationParam.toInt();

                  if (angle >= 0 && angle <= 180) {
                    servo.write(angle); // Move the servo to the specified angle
                    Serial.printf("Moving servo to %d degrees\n", angle);

                    delay(duration); // Wait for the specified duration (in milliseconds)

                    servo.write(0); // Return to 0 degrees (initial position)
                    Serial.printf("Returning servo to 0 degrees after %d ms\n", duration);
                    request->send(200, "text/plain", "Servo moved successfully");
                  } else {
                    request->send(400, "text/plain", "Invalid angle. Must be between 0 and 180.");
                  }
                } else {
                  request->send(400, "text/plain", "Missing angle or duration parameter.");
                }
              });

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
