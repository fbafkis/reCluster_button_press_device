#!/bin/bash

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

# Function to generate the ESP32 code with the provided parameters
generate_code() {
    local ssid="$1"
    local password="$2"
    local local_IP="$3"
    local servoPin="$4"
    local turningDegrees="$5"

    cat <<EOF > esp32_code.ino


# Function to upload the code to the ESP32
upload_code() {
    local port="$1"
    arduino-cli compile --fqbn esp32:esp32:esp32 esp32_code.ino
    if [ $? -ne 0 ]; then
        whiptail --msgbox "Compilation failed" 8 39 --title "Error"
        exit 1
    fi

    arduino-cli upload -p "$port" --fqbn esp32:esp32:esp32 esp32_code.ino
    if [ $? -ne 0 ]; then
        whiptail --msgbox "Upload failed" 8 39 --title "Error"
        exit 1
    fi

    whiptail --msgbox "Upload successful" 8 39 --title "Success"
}

# Function to read from the serial port and check messages
check_serial() {
    local port="$1"
    local timeout="$2"

    # Start background process to read from serial port
    (cat < "$port" & ) | {
        local start_time=$(date +%s)
        while true; do
            read -t 1 line
            local elapsed=$(( $(date +%s) - $start_time ))
            if [ "$elapsed" -ge "$timeout" ]; then
                echo "Timeout reached"
                return 1
            fi
            if [[ "$line" == *"STA Failed to configure"* ]]; then
                echo "STA Failed to configure"
                return 2
            elif [[ "$line" == *"Failed to connect to WiFi"* ]]; then
                echo "Failed to connect to WiFi"
                return 3
            elif [[ "$line" == *"Connected to WiFi"* ]]; then
                echo "Connected to WiFi"
                return 0
            fi
        done
    }
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

# Function to check servo status
check_servo_status() {
    local ip="$1"
    local response

    response=$(curl -s --max-time 5 "http://$ip/servostatus")
    echo "$response"
    if [[ "$response" == *"Servo moved successfully"* ]]; then
        return 0
    else
        return 1
    fi
}

# Main script loop
while true; do
    ssid=$(whiptail --inputbox "Enter WLAN SSID" 8 39 --title "WLAN SSID" 3>&1 1>&2 2>&3)
    if [ -z "$ssid" ]; then
        whiptail --msgbox "WLAN SSID cannot be empty" 8 39 --title "Error"
        continue
    fi

    password=$(whiptail --passwordbox "Enter WLAN Password" 8 39 --title "WLAN Password" 3>&1 1>&2 2>&3)
    if [ -z "$password" ]; then
        whiptail --msgbox "WLAN Password cannot be empty" 8 39 --title "Error"
        continue
    fi

    local_IP=$(whiptail --inputbox "Enter Device IP Address" 8 39 --title "Device IP" 3>&1 1>&2 2>&3)
    if ! validate_ip "$local_IP"; then
        whiptail --msgbox "Invalid IP address format" 8 39 --title "Error"
        continue
    fi

    servoPin=$(whiptail --inputbox "Enter Servo PIN" 8 39 --title "Servo PIN" 3>&1 1>&2 2>&3)
    if [ -z "$servoPin" ]; then
        whiptail --msgbox "Servo PIN cannot be empty" 8 39 --title "Error"
        continue
    fi

    turningDegrees=$(whiptail --inputbox "Enter Turning Degrees (10-90)" 8 39 --title "Turning Degrees" 3>&1 1>&2 2>&3)
    if [[ ! "$turningDegrees" =~ ^[0-9]+$ ]] || [ "$turningDegrees" -lt 10 ] || [ "$turningDegrees" -gt 90 ]; then
        whiptail --msgbox "Turning Degrees must be a number between 10 and 90" 8 39 --title "Error"
        continue
    fi

    generate_code "$ssid" "$password" "$local_IP" "$servoPin" "$turningDegrees"

    port=$(arduino-cli board list | grep "tty" | awk '{print $1}')
    if [ -z "$port" ]; then
        whiptail --msgbox "No serial port found" 8 39 --title "Error"
        exit 1
    fi

    upload_code "$port"

    whiptail --msgbox "Device configuration:\nWLAN SSID: $ssid\nWLAN Password: $password\nDevice IP: $local_IP\nServo PIN: $servoPin\nTurning Degrees: $turningDegrees" 12 50 --title "Device Configuration"

    result=$(check_serial "$port" 60)
    if [ "$result" -eq 2 ]; then
        whiptail --msgbox "STA Failed to configure" 8 39 --title "Error"
    elif [ "$result" -eq 3 ]; then
        whiptail --msgbox "Failed to connect to WiFi" 8 39 --title "Error"
    elif [ "$result" -eq 0 ]; then
        if check_device "$local_IP"; then
            whiptail --msgbox "Device is reachable and ready" 8 39 --title "Success"
            if test_device "$local_IP"; then
                whiptail --msgbox "Device functionality test succeeded" 8 39 --title "Success"
                if check_servo_status "$local_IP"; then
                    whiptail --msgbox "Servo moved successfully" 8 39 --title "Success"
                else
                    whiptail --msgbox "Servo did not move" 8 39 --title "Error"
                fi
            else
                whiptail --msgbox "Device functionality test failed" 8 39 --title "Error"
            fi
        else
            whiptail --msgbox "Failed to contact device over WiFi" 8 39 --title "Error"
        fi
    fi

    if (whiptail --title "Repeat" --yesno "Do you want to configure again?" 8 39); then
        continue
    else
        break
    fi
done
