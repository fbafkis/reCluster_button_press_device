#!/bin/bash

# Function to send a GET request to the /test endpoint
send_request() {
    local ip="$1"
    local angle="$2"
    local press_time="$3"

    # Send the GET request using curl
    response=$(curl -s -G "http://$ip/test" --data-urlencode "angle=$angle" --data-urlencode "duration=$press_time")

    if [ "$response" == "Servo moved successfully" ]; then
        whiptail --msgbox "Request successful: Servo moved to $angle degrees for $press_time ms" 10 60 --title "Success"
    else
        whiptail --msgbox "Request failed." 10 60 --title "Error"
    fi
}

# Initialize default values for IP, angle, and press time
ip_address=""
angle="33"
press_time="400"

while true; do
    # First dialog to get IP address
    ip_address=$(whiptail --inputbox "Enter the IP address of the ESP8266" 10 60 "$ip_address" --title "IP Address" 3>&1 1>&2 2>&3)

    # Check if the Cancel button was pressed
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Second dialog to get the angle
    angle=$(whiptail --inputbox "Enter the angle (0-180 degrees)" 10 60 "$angle" --title "Angle" 3>&1 1>&2 2>&3)

    # Check if the Cancel button was pressed
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Third dialog to get the press time
    press_time=$(whiptail --inputbox "Enter the press duration in milliseconds" 10 60 "$press_time" --title "Press Duration" 3>&1 1>&2 2>&3)

    # Check if the Cancel button was pressed
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Send the request to the /test endpoint
    send_request "$ip_address" "$angle" "$press_time"
done
