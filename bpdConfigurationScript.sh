#!/bin/bash
INIT=true

# Function to display help message
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --ssid <SSID>              Set the WLAN SSID."
    echo "  --password <PASSWORD>       Set the WLAN password."
    echo "  --ip <IP_ADDRESS>           Set the static IP address of the device."
    echo "  --pin <SERVO_PIN>           Set the servo pin (D0, D1, D2, D3, D4, D5, D6, D7, D8)."
    echo "  --degrees <TURNING_DEGREES> Set the turning degrees (10-90)."
    echo "  --duration <PRESS_DURATION> Set the press duration in milliseconds (min 100)."
    echo "  --help                      Show this help message."
    exit 0
}

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

# Function to validate pin
validate_pin() {
    local pin="$1"
    case "$pin" in
    D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8) return 0 ;;
    *) return 1 ;;
    esac
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

# Function to collect the WLAN SSID
collect_ssid() {
    while true; do
        ssid=$(whiptail --inputbox "Enter WLAN SSID" 8 39 "${ssid:-}" --title "WLAN SSID" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if [ -z "$ssid" ]; then
            whiptail --msgbox "WLAN SSID cannot be empty" 8 39 --title "Error"
        else
            break
        fi
    done
}

# Function to collect the WLAN password
collect_password() {
    while true; do
        password=$(whiptail --passwordbox "Enter WLAN Password" 8 39 "${password:-}" --title "WLAN Password" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if [ -z "$password" ]; then
            whiptail --msgbox "WLAN Password cannot be empty" 8 39 --title "Error"
        else
            break
        fi
    done

}

# Function to collect and validate the device IP
collect_ip() {
    while true; do
        local_IP=$(whiptail --inputbox "Enter Device IP Address" 8 39 "${local_IP:-}" --title "Device IP" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if ! validate_ip "$local_IP"; then
            whiptail --msgbox "Invalid IP address format" 8 39 --title "Error"
        else
            break
        fi
    done
}

# Function to collect and validate the servo pin
collect_servo_pin() {
    while true; do
        servoPin=$(whiptail --inputbox "Enter Servo PIN (D0, D1, D2, D3, D4, D5, D6, D7, D8)" 8 39 "${servoPin:-D1}" --title "Servo PIN" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if validate_pin "$servoPin"; then
            break
        else
            whiptail --msgbox "Invalid Servo PIN: $servoPin. Must be one of D0, D1, D2, D3, D4, D5, D6, D7, D8." 10 60 --title "Error"
        fi
    done
}

# Function to collect and validate the turning degrees
collect_turning_degrees() {
    while true; do
        turningDegrees=$(whiptail --inputbox "Enter Turning Degrees (10-90, default:33)" 8 39 "${turningDegrees:-33}" --title "Turning Degrees" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if [[ ! "$turningDegrees" =~ ^[0-9]+$ ]] || [ "$turningDegrees" -lt 10 ] || [ "$turningDegrees" -gt 90 ]; then
            whiptail --msgbox "Turning Degrees must be a number between 10 and 90" 8 39 --title "Error"
        else
            break
        fi
    done
}

# Function to collect and validate the press duration
collect_press_duration() {
    while true; do
        pressTime=$(whiptail --inputbox "Enter Press Duration in milliseconds (default:400ms)" 8 39 "${pressTime:-400}" --title "Press Time" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if [[ ! "$pressTime" =~ ^[0-9]+$ ]] || [ "$pressTime" -lt 100 ]; then
            whiptail --msgbox "Press Time must be a number greater than 100ms" 8 39 --title "Error"
        else
            break
        fi
    done
}

# Function to collect all parameters (each with its own validation)
collect_parameters() {
    collect_ssid
    collect_password
    collect_ip
    collect_servo_pin
    collect_turning_degrees
    collect_press_duration
}

collect_parameters_init() {
    if [ -z "$ssid" ]; then
        collect_ssid
    fi

    if [ -z "$password" ]; then
        collect_password
    fi

    if [ -z "$local_IP" ]; then
        collect_ip
    fi

    if [ -z "$servoPin" ]; then
        collect_servo_pin
    fi

    if [ -z "$turningDegrees" ]; then
        collect_turning_degrees
    fi

    if [ -z "$pressTime" ]; then
        collect_press_duration
    fi
}

# Parse command-line arguments and validate them
while [ "$1" != "" ]; do
    case $1 in
    --ssid)
        shift
        ssid="$1"
        ;;
    --password)
        shift
        password="$1"
        ;;
    --ip)
        shift
        local_IP="$1"
        if ! validate_ip "$local_IP"; then
            echo "Invalid IP address format: $local_IP"
            exit 1
        fi
        ;;
    --pin)
        shift
        servoPin="$1"
        if ! validate_pin "$servoPin"; then
            echo "Invalid Servo PIN: $servoPin. Must be one of D0, D1, D2, D3, D4, D5, D6, D7, D8."
            exit 1
        fi
        ;;
    --degrees)
        shift
        turningDegrees="$1"
        if [[ ! "$turningDegrees" =~ ^[0-9]+$ ]] || [ "$turningDegrees" -lt 10 ] || [ "$turningDegrees" -gt 90 ]; then
            echo "Turning Degrees must be a number between 10 and 90"
            exit 1
        fi
        ;;
    --duration)
        shift
        pressTime="$1"
        if [[ ! "$pressTime" =~ ^[0-9]+$ ]] || [ "$pressTime" -lt 100 ]; then
            echo "Press Time must be a number greater than 100ms"
            exit 1
        fi
        ;;
    --help)
        display_help
        ;;
    *)
        echo "Unknown option: $1"
        display_help
        ;;
    esac
    shift
done

detect_serial_port() {
    echo "SERIAL PORT DETECTION - Detecting serial port..."
    port=$(arduino-cli board list | grep "tty" | awk '{print $1}')
    if [ -z "$port" ]; then
        whiptail --msgbox "No serial port found. Check the USB connection and make sure the serial port is not busy or invisible." 10 60 --title "Serial Port Error"
        choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 --nocancel \
            "1" "Try again to detect serial port" \
            "2" "Start over installation" \
            "3" "Cancel and exit" 3>&1 1>&2 2>&3)

        case $choice in
        1)
            detect_serial_port
            ;;
        2)
            main
            ;;
        3)
            exit 1
            ;;
        esac
    fi
    echo "SERIAL PORT DETECTION - Serial port detected: $port"
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
            echo "LIBRARY INSTALLATION - Library $lib is already installed."
        fi
    done

    echo "LIBRARY INSTALLATION - All required libraries are installed."
}

# Function to generate the ESP8266 code with the provided parameters
generate_code() {
    local ssid="$1"
    local password="$2"
    local local_IP="$3"
    local servoPin="$4"
    local turningDegrees="$5"
    local pressTime="$6"

    # Convert IP address format from dot to comma
    local_IP_comma=$(echo $local_IP | tr '.' ',')

    # Convert the servo pin to GPIO number if necessary
    gpio_pin=$(convert_pin "$servoPin")

    # Create a directory for the sketch
    mkdir -p esp8266_code

    cat <<EOF >esp8266_code/esp8266_code.ino
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

// Define how long the servo stays in the pressed position (in milliseconds)
int pressDuration = $pressTime; // Default: 400ms

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
    local output_file="$2"

    # Ensure the serial port is configured correctly
    stty -F "$port" 115200

    # Open the serial port and listen for 60 seconds
    exec 3<>"$port"

    # Record the output for 60 seconds
    END=$((SECONDS + 60))
    while [ $SECONDS -lt $END ]; do
        cat <&3 >>"$output_file"
        if [ $? -ne 0 ]; then
            echo "RECORDING SERIAL PORT - Error reading from serial port. Serial port may have been disconnected."
            return 1
        fi
    done

    # Close the serial port
    exec 3<&-
}

# Function to check the recorded serial output for error messages
check_serial_output() {
    echo "SERIAL OUTPUT CHECKING - Looking for error messages inside the board serial output..."
    local output_file="$1"

    if [ ! -s "$output_file" ]; then
        return 4 # No data read from the serial port
    fi

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

# Function to check if the device is reachable by sending a GET request to /areyoualive
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

# Function to test the device by sending a GET request to /press
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

# Function to handle restart option dialogs with larger size
handle_restart_option() {
    local message="$1"
    if (whiptail --title "Restart Installation" --yesno "$message" 12 60); then
        main
    else
        exit 1
    fi
}

# Function to repeat the test only if the user chooses
test_motor() {
    local ip="$1"
    local retry=true  # Variabile per gestire la ripetizione del test

    while $retry; do
        whiptail --msgbox "Look at the motor. Testing motor functionality now..." 8 39 --title "Motor Test"
        
        if test_device "$ip"; then
            if (whiptail --title "Motor Movement" --yesno "Did the motor move?" 8 39); then
                echo "DEVICE TESTING - Motor movement confirmed by user."
                retry=false  # Test riuscito, non ripetere più il ciclo
            else
                whiptail --title "Retry" --msgbox "Check the cable connections and configuration." 10 60
                choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 \
                    "1" "Try again to test the motor" \
                    "2" "Start over installation" \
                    "3" "Cancel and exit" 3>&1 1>&2 2>&3)

                case $choice in
                1)
                    retry=true  # Ripetere il test
                    ;;
                2)
                    main  # Ripartire dall'inizio dell'installazione
                    ;;
                3)
                    exit 1  # Terminare lo script
                    ;;
                esac
            fi
        else
            echo "DEVICE TESTING - Motor test failed."

            whiptail --title "Retry" --msgbox "It was not possible to contact the device to test it." 10 60
            choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 \
                "1" "Try again to test the device" \
                "2" "Start over installation" \
                "3" "Cancel and exit" 3>&1 1>&2 2>&3)

            case $choice in
            1)
                retry=true  # Ripetere il test
                ;;
            2)
                main  # Ripartire dall'inizio dell'installazione
                ;;
            3)
                exit 1  # Terminare lo script
                ;;
            esac
        fi
    done
}


# Main function to execute the configuration
main() {
    echo "PARAMETERS COLLECTION - Collecting parameters..."
    if [ "$INIT" = true ]; then
        collect_parameters_init
        INIT=false
    else
        collect_parameters
    fi

    detect_serial_port
    install_libraries
    generate_code "$ssid" "$password" "$local_IP" "$servoPin" "$turningDegrees" "$pressTime"
    upload_code "$port"

    serial_output_file="serial_output.txt"
    echo "SERIAL PORT MONITORING - Monitoring board serial port output for 60 seconds...hold on"
    rm -rf "$serial_output_file"
    record_serial_output "$port" "$serial_output_file"
    if [ $? -ne 0 ]; then
        choice=$(whiptail --title "Serial Port Disconnected" --menu "The serial port was disconnected. What would you like to do?" 15 60 3 --nocancel \
            "1" "Restart from firmware compilation and upload" \
            "2" "Start over installation" \
            "3" "Cancel and exit" 3>&1 1>&2 2>&3)

        case $choice in
        1)
            
            detect_serial_port
            ;;
        2)
            main
            ;;
        3)
            exit 1
            ;;
        esac
    fi
    echo "SERIAL PORT MONITORING - Serial port monitoring completed."

    check_serial_output "$serial_output_file"
    result=$?
    if [ "$result" -eq 1 ]; then
        echo "SERIAL PORT CHECKING - Serial port output error."
        whiptail --msgbox "Serial port output error." 8 39 --title "Serial Port Error"
        choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 --nocancel \
            "1" "Try again to reupload the firmware" \
            "2" "Start over installation" \
            "3" "Cancel and exit" 3>&1 1>&2 2>&3)
        case $choice in
        1)
            
            upload_code
            ;;
        2)
            main
            ;;
        3)
            exit 1
            ;;
        esac
    elif [ "$result" -eq 2 ]; then
        echo "SERIAL PORT CHECKING - Device network error: STA Failed to configure. Check network settings."
        handle_restart_option "Device network error: STA Failed to configure. Check network settings. Do you want to restart the installation?"
    elif [ "$result" -eq 3 ]; then
        echo "SERIAL PORT CHECKING - Device network error: failed to connect to WiFi. Check network settings."
        handle_restart_option "Device network error: failed to connect to WiFi. Check network settings. Do you want to restart the installation?"
    elif [ "$result" -eq 4 ]; then
        whiptail --msgbox "No output was read from the serial port. There may be an issue with the connection." 8 39 --title "Serial Port Error"
        choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 --nocancel \
            "1" "Try again to reupload the firmware" \
            "2" "Start over installation" \
            "3" "Cancel and exit" 3>&1 1>&2 2>&3)
        case $choice in
        1)
            
            upload_code
            ;;
        2)
            main
            ;;
        3)
            exit 1
            ;;
        esac
    elif [ "$result" -eq 0 ]; then
        echo "DEVICE TESTING - Testing device functionality over WiFi..."
        if check_device "$local_IP"; then
            test_motor "$local_IP"
        else
            whiptail --msgbox "Device network error: Unable to contact the device over WiFi. Check network settings and WiFi status." 8 39 --title "Network Error"
            choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 --nocancel \
                "1" "Try again to contact the device" \
                "2" "Start over installation" \
                "3" "Cancel and exit" 3>&1 1>&2 2>&3)
            case $choice in
            1)
                check_device
                ;;
            2)
                main
                ;;
            3)
                exit 1
                ;;
            esac
        fi
    else
        whiptail --msgbox "It was not possible to get the board status." 8 39 --title "Device status not available"
        choice=$(whiptail --title "What would you like to do?" --menu "Choose an option:" 15 60 3 --nocancel \
            "1" "Try again to reupload the firmware" \
            "2" "Start over installation" \
            "3" "Cancel and exit" 3>&1 1>&2 2>&3)
        case $choice in
        1)
            upload_code
            ;;
        2)
            main
            ;;
        3)
            exit 1
            ;;
        esac
    fi
}

# Start from the main function
main
