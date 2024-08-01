#!/bin/bash

ERROR_THROWN=false

# Check if arduino-cli is installed
if ! command -v arduino-cli &> /dev/null
then
    echo "arduino-cli could not be found"
    whiptail --msgbox "The arduino-cli tool is required but it's not installed. Please install arduino-cli and try again." 8 78 --title "arduino-cli Not Found"
    exit 1
fi

# Function to validate IP address
validate_ip() {
    local ip="$1"
    local valid_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ $ip =~ $valid_ip_regex ]]; then
        for octet in $(echo $ip | tr "." " "); do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to convert pin names to GPIO numbers
convert_pin() {
    case "$1" in
        D0) echo 16 ;;
        D1) echo 5 ;;
        D2) echo 4 ;;
        D3) echo 0 ;;
        D4) echo 2 ;;
        D5) echo 14 ;;
        D6) echo 12 ;;
        D7) echo 13 ;;
        D8) echo 15 ;;
        *) echo "$1" ;; # If it's already a number, just return it
    esac
}

# Function to install required libraries
install_libraries() {
    echo "LIBRARY INSTALLATION - Checking and installing required libraries..."

    required_libs=("ESPAsyncTCP" "ESPAsyncWebServer" "Servo")

    for lib in "${required_libs[@]}"; do
        if ! arduino-cli lib list | grep -q "$lib"; then
            echo "Installing library: $lib"
            arduino-cli lib install "$lib"
            if [ $? -ne 0 ]; then
                whiptail --msgbox "Failed to install library: $lib" 8 39 --title "Error"
                echo "LIBRARY INSTALLATION - ERROR: Failed to install library: $lib."
                exit 1
            fi
        else
            echo "Library $lib is already installed."
        fi
    done

    echo "LIBRARY INSTALLATION - All required libraries are installed."
}

# Function to generate the ESP8266 code with the provided parameters
generate_code() {

    echo "BOARD CODE GENERATION - Starting board code generation..."

    local ssid="$1"
    local password="$2"
    local local_IP="$3"
    local servoPin="$4"
    local turningDegrees="$5"

    # Convert IP address format from dot to comma
    local_IP_comma=$(echo $local_IP | tr '.' ',')

    # Convert the servo pin to GPIO number if necessary
    gpio_pin=$(convert_pin "$servoPin")

    # Create a directory for the sketch
    mkdir -p esp8266_code

    cat <<EOF > esp8266_code/esp8266_code.ino
#include <ESP8266WiFi.h>
#include <ESPAsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <Servo.h>

// Replace with your network credentials
const char *ssid = "$ssid";
const char *password = "$password";

// Define static IP settings for 192.168.0.x network
IPAddress local_IP($local_IP_comma); // The static IP address

// Define the turning degrees for the servo
int turningDegrees = $turningDegrees;

// Create AsyncWebServer object on port 80
AsyncWebServer server(80);

// Create a servo object
Servo servo;

// Define the servo pin
const int servoPin = $gpio_pin; // Adjust according to your setup

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
EOF

    echo "BOARD CODE GENERATION - Board code generation completed."
}

# Function to upload the code to the ESP8266
upload_code() {
    echo "FIRMWARE COMPILATION - Starting firmware compilation..."
    local port="$1"
    arduino-cli compile --fqbn esp8266:esp8266:generic esp8266_code
    if [ $? -ne 0 ]; then
        whiptail --msgbox "Firmware compilation failed" 8 39 --title "Error"
            echo "FIRMWARE COMPILATION - ERROR: Firmware compilation failed."
        exit 1
    fi
    echo "FIRMWARE COMPILATION - Firmware compilation completed successfully."

    echo "FIRMWARE UPLOADING - Starting firmware uploading on the board..."
    arduino-cli upload -p "$port" --fqbn esp8266:esp8266:generic esp8266_code
    if [ $? -ne 0 ]; then
        whiptail --msgbox "Firmware upload failed" 8 39 --title "Error"
        echo "FIRMWARE UPLOADING - ERROR: Firmware upload failed."
        exit 1
    fi
    echo "FIRMWARE UPLOADING - Firmware uploading completed successfully."
}

# Function to record the serial output for a minute
record_serial_output() {
    local port="$1"
    local duration="$2"
    local output_file="$3"

    # Ensure the serial port is configured correctly
    stty -F "$port" 115200

    # Open the serial port and listen for 60 seconds
    exec 3<>"$port"

    # Record the output for 60 seconds
    END=$((SECONDS+60))
    while [ $SECONDS -lt $END ]; do
      cat <&3 >> "$output_file"
    done

    # Close the serial port
    exec 3<&-
}

# Function to check the recorded serial output for error messages
check_serial_output() {
    echo "SERIAL OUTPUT CHECKING - Looking for error messages inside the board serial output..."
    local output_file="$1"

    if grep -q "STA Failed to configure" "$output_file"; then
        return 2
    elif grep -q "Failed to connect to WiFi" "$output_file"; then
        return 3
    elif grep -q "Connected to WiFi" "$output_file"; then
        return 0
    else
        return 1
    fi
}

# Function to check device reachability
check_device() {
    local ip="$1"
    local response

    response=$(curl -s --max-time 5 "http://$ip/areyoualive")
    if [ "$response" == "OK" ]; then
        return 0
    else
        return 1
    fi
}

# Function to test device functionality
test_device() {
    local ip="$1"
    local response

    response=$(curl -s --max-time 5 "http://$ip/press")
    if [ "$response" == "SUCCESS" ]; then
        return 0
    else
        return 1
    fi
}

# Main function

configure() {
    ERROR_THROWN=false
    echo "PARAMETERS COLLECTION - Collecting parameters from user input..."
    while true; do
        ssid=$(whiptail --inputbox "Enter WLAN SSID" 8 39 --title "WLAN SSID" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            exit 1
        fi
        if [ -z "$ssid" ]; then
            whiptail --msgbox "WLAN SSID cannot be empty" 8 39 --title "Error"
        else
            break
        fi
    done

    while true; do
        password=$(whiptail --passwordbox "Enter WLAN Password" 8 39 --title "WLAN Password" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            exit 1
        fi
        if [ -z "$password" ]; then
            whiptail --msgbox "WLAN Password cannot be empty" 8 39 --title "Error"
        else
            break
        fi
    done

    while true; do
        local_IP=$(whiptail --inputbox "Enter Device IP Address" 8 39 --title "Device IP" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            exit 1
        fi
        if ! validate_ip "$local_IP"; then
            whiptail --msgbox "Invalid IP address format" 8 39 --title "Error"
        else
            break
        fi
    done

    while true; do
        servoPin=$(whiptail --inputbox "Enter Servo PIN (default: D1)" 8 39 "D1" --title "Servo PIN" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            exit 1
        fi
        if [ -z "$servoPin" ]; then
            whiptail --msgbox "Servo PIN cannot be empty" 8 39 --title "Error"
        else
            break
        fi
    done

    while true; do
        turningDegrees=$(whiptail --inputbox "Enter Turning Degrees (10-90, default:20)" 8 39 "20" --title "Turning Degrees" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            exit 1
        fi
        if [[ ! "$turningDegrees" =~ ^[0-9]+$ ]] || [ "$turningDegrees" -lt 10 ] || [ "$turningDegrees" -gt 90 ]; then
            whiptail --msgbox "Turning Degrees must be a number between 10 and 90" 8 39 --title "Error"
        else
            break
        fi
    done
    echo "PARAMETERS COLLECTION - Parameters collection completed."

    install_libraries

    generate_code "$ssid" "$password" "$local_IP" "$servoPin" "$turningDegrees"

    echo "SERIAL PORT DETECTION - Detecting serial port..."
    port=$(arduino-cli board list | grep "tty" | awk '{print $1}')
    if [ -z "$port" ]; then
        whiptail --msgbox "No serial port found" 8 39 --title "Error"
            echo "SERIAL PORT DETECTION - ERROR: No serial port found."
        exit 1
    fi
    echo "SERIAL PORT DETECTION - Serial port detected: $port"

    upload_code "$port"

    serial_output_file="serial_output.txt"
    echo "SERIAL PORT MONITORING - Monitoring board serial port output for 60 seconds...hold on"
    rm -rf "$serial_output_file"
    record_serial_output "$port" "60s" "$serial_output_file"
    echo "SERIAL PORT MONITORING - Serial port monitoring completed."
    echo "SERIAL PORT MONITORING - Serial port output:"
    echo
    cat "$serial_output_file"
    echo
    echo "SERIAL PORT MONITORING - Serial port output end."

    check_serial_output "$serial_output_file"
    result=$?
    echo "SERIAL OUTPUT CHECKING - Control completed."

    if [ "$result" -eq 1 ]; then
        whiptail --msgbox "No error messages found in the serial output" 8 39 --title "Success"
    elif [ "$result" -eq 2 ]; then
        whiptail --msgbox "Board reported \"STA Failed to configure\"" 8 39 --title "Error"
        echo "SERIAL OUTPUT CHECKING - ERROR: board reported \"STA Failed to configure\"."
        ERROR_THROWN=true
    elif [ "$result" -eq 3 ]; then
        whiptail --msgbox "Failed to connect to WiFi" 8 39 --title "Error"
        echo "SERIAL OUTPUT CHECKING - ERROR: board reported \"Failed to connect to WiFi\"."
        ERROR_THROWN=true
    elif [ "$result" -eq 0 ]; then
        echo "DEVICE REACHABILITY CHECK OVER WIFI - Trying to contact the device via WiFi..."
        if check_device "$local_IP"; then
            echo "DEVICE REACHABILITY CHECK OVER WIFI - Device is reachable and ready."
            whiptail --msgbox "Device is reachable and ready. Now the device functionality will be tested. Check visually if the servo motor moves." 12 50 --title "Success"
            echo "DEVICE FUNCTIONALITY CHECK OVER WIFI - Testing functionality... check if the servo moves."
            if test_device "$local_IP"; then
                whiptail --msgbox "Device functionality test succeeded" 8 39 --title "Success"
                echo "DEVICE FUNCTIONALITY CHECK OVER WIFI - Device functionality test succeeded."
            else
                whiptail --msgbox "Device functionality test failed" 8 39 --title "Error"
                echo "DEVICE FUNCTIONALITY CHECK OVER WIFI - ERROR: device functionality test failed."
                ERROR_THROWN=true
            fi
        else
            whiptail --msgbox "Failed to contact device over WiFi" 8 39 --title "Error"
            echo "DEVICE REACHABILITY CHECK OVER WIFI - ERROR: failed to contact device over WiFi."
            ERROR_THROWN=true
        fi
    else
        whiptail --msgbox "It was not possible to get board status from serial port check: $result" 8 39 --title "Error"
        echo "SERIAL OUTPUT CHECKING -It was not possible to get board status from serial port check: $result."
        ERROR_THROWN=true
    fi
    whiptail --msgbox "Device configuration recap:WLAN SSID: $ssid\nWLAN Password: $password\nDevice IP: $local_IP\nServo PIN: $servoPin\nTurning Degrees: $turningDegrees" 12 50 --title "Device Configuration"
    echo
    echo "DEVICE CONFIGURATION RECAP:" 
    echo "WLAN SSID: $ssid"
    echo "WLAN Password: $password"
    echo "Device IP: $local_IP"
    echo "Servo PIN: $servoPin"
    echo "Turning Degrees: $turningDegrees"

    if $ERROR_THROWN; then
        if (whiptail --title "Repeat" --yesno "Errors have been thrown from the board. Do you want to start over the configuration?" 8 39); then
            configure
        else
            exit 1
        fi
    fi
}

configure
