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

last_ip=""

while true; do
    ip=$(whiptail --inputbox "BPD test utility. Enter the device IP address and press \"OK\" to test functionality. Press \"Cancel\" to exit." 8 78 "$last_ip" --title "Device IP" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus != 0 ]; then
        echo "User cancelled the input. Exiting."
        exit 1
    fi

    if validate_ip "$ip"; then
        last_ip="$ip"
        echo "Valid IP address entered: $ip"
        response=$(curl -s --max-time 5 "http://$ip/press")
        if [ "$response" == "SUCCESS" ]; then
            echo "Button press request to $ip was successful."
            whiptail --msgbox "Button press request was successful." 8 39 --title "Success"
        else
            echo "Button press request to $ip failed."
            whiptail --msgbox "Button press request failed." 8 39 --title "Failure"
        fi
    else
        echo "Invalid IP address entered: $ip"
        whiptail --msgbox "Invalid IP address. Please enter a valid IP address." 8 39 --title "Error"
    fi
done
