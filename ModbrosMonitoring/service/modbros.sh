#!/bin/bash

# ==========================================================
# Modbros Monitoring Service - Raspberry Pi
#
# systemd service
# (intended for and tested only on clean Raspbian Stretch)
#
# Created with <3 in Austria by: (c) ModBros 2019
# Contact: mod-bros.com
# ==========================================================

# Files
HOSTS_FILE='/home/modbros/ModbrosMonitoring/data/hosts.txt'
WIFI_FILE='/home/modbros/ModbrosMonitoring/data/wifi.txt'
VERSION_FILE='/home/modbros/ModbrosMonitoring/data/version.txt'
MOBRO_FOUND_FLAG='/home/modbros/ModbrosMonitoring/data/mobro_found.txt'
NETWORKS_FILE='/home/modbros/ModbrosMonitoring/web/modbros/networks'

# Resources
MODBROS_LOGO='/home/modbros/ModbrosMonitoring/resources/modbros.png'

# Directories
LOG_DIR='/home/modbros/ModbrosMonitoring/log'

# URLs (local pages)
URL_MODBROS='http://localhost/local/index.php'             # page 1
URL_HOTSPOT='http://localhost/local/hotspot.php'           # page 2
URL_CONNECT_WIFI='http://localhost/local/connectwifi.php'  # page 3
URL_CONNECT_MOBRO='http://localhost/local/connecting.php'  # page 4
URL_NOTFOUND='http://localhost/local/notfound.php'         # page 5

# Ports
MOBRO_PORT='42100'               # port of the MoBro desktop application

# Global Vars
AP_SSID='ModBros_Configuration'  # SSID of the created access point
AP_PW='modbros123'               # password of the created access point
LOOP_INTERVAL=5                  # in seconds
CHECK_INTERVAL_HOTSPOT=60        # in loops (60x5=300s -> every 5 minutes)
CHECK_INTERVAL_BACKGROUND=10     # in loops
HOTSPOT_COUNTER=0                # counter variable for connection retry in hotspot mode
BACKGROUND_COUNTER=0             # counter variable for background alive check in wifi mode
LAST_CHECKED_WIFI=''             # remember timestamp of last checked wifi credentials
CURR_PAGE='1'                    # save currently active page
CURR_MODE='local'                # save currently active mode
CURR_MOBRO_URL=''                # save current MoBro Url
NUM_CORES=$(nproc --all)         # number of available cores


# versions
PI_VERSION=$(cat /proc/device-tree/model)           # pi version (e.g. Raspberry Pi 3 Model B Plus Rev 1.3)
SERVICE_VERSION=$(cat "$VERSION_FILE" | sed -n 1p)  # service version number


# ==========================================================
# Functions
# ==========================================================

log() {
    LOG_DATE=$(date "+%m%d%Y %T");
    TEMP=$(sudo vcgencmd measure_temp)
    echo "$LOG_DATE | $TEMP : [$1] $2" >> "$LOG_DIR/log.txt"
}

wait_window() {
    until [[ $(xdotool search --onlyvisible --class "$1" | wc -l) -gt 0 ]]; do
        log "helper" "waiting for $1 to become available.."
        sleep 2
    done
}

sleep_cpu() {
    CPU_USAGE=$(top -b -d1 -n1|grep -i "Cpu(s)"|head -c21|cut -d ' ' -f3|cut -d '%' -f1)
    until [[ $(echo "$CPU_USAGE>20.0" | bc) -eq 0 ]]; do
        log "helper" "cpu usage currently at $CPU_USAGE. waiting for it to come down..."
        sleep 2
    done
}

stop_process() {
    log "helper" "stopping processes: $@"
    # clean up previously running apps; gracefully at first then harshly
    sudo killall -TERM $@ 2>/dev/null;
    sleep_pi 1 2
    sudo killall -9 $@ 2>/dev/null;
    sleep_pi 1 2
}

sleep_pi() {
    if [[ ${NUM_CORES} -gt 1 ]]; then
        sleep $1
    else
        sleep $2
    fi
}

show_logo() {
    log "feh" "showing logo $1"
    feh \
        --fullscreen \
        --hide-pointer \
        --no-menus \
        --zoom fill \
        --image-bg "white" \
        $1 &>> "$LOG_DIR/log.txt" &
}

init_x() {
    log "init_x" "starting x server"
    sudo xinit \
        /bin/sh -c "exec /usr/bin/matchbox-window-manager -use_titlebar no -use_cursor no" \
        -- -nocursor \
        &>> "$LOG_DIR/log.txt" &
}

start_chrome() {
    log "chromium" "starting browser"
    chromium-browser \
        --allow-insecure-localhost \
        --no-wifi \
        --no-default-browser-check \
        --no-service-autorun \
        --disable-infobars \
        --noerrdialogs \
        --incognito \
        --kiosk \
        ${URL_MODBROS} \
        ${URL_HOTSPOT} \
        ${URL_CONNECT_WIFI} \
        ${URL_CONNECT_MOBRO} \
        ${URL_NOTFOUND} \
        &>> "$LOG_DIR/log.txt" &
    sleep_pi 5 15
    sleep_cpu
    wait_window "chromium"
}

show_mobro() {
    log "chromium" "switching to MoBro application on '$1'"
    chromium-browser \
        --no-default-browser-check \
        --no-service-autorun \
        --disable-infobars \
        --noerrdialogs \
        --incognito \
        --kiosk \
        --app=$1 \
        &>> "$LOG_DIR/log.txt" &
    sleep_cpu
    wait_window "chromium"
}

show_page() {
    case "$1" in
        [1-5])
            if [[ $(ps ax | grep chromium | grep -v "grep" | wc -l) -eq 0 ]]; then
                start_chrome
            elif [[ "$CURR_MODE" != "local" ]]; then
                stop_process "chromium-browser"
                start_chrome
            fi
            CURR_MODE='local'
            if [[ "$CURR_PAGE" != "$1" ]]; then
                log "chromium" "switching to local page $1"
                CURR_PAGE="$1"
                xdotool windowactivate $(xdotool search --onlyvisible --class chromium | head -1) &>> "$LOG_DIR/log.txt"
                xdotool key "ctrl+$1" &>> "$LOG_DIR/log.txt"
                if [[ "$1" != "1" ]]; then
                    # reload if not index page
                    xdotool key "ctrl+F5"
                fi
            fi
            if [[ $(ps ax | grep feh | grep -v "grep" | wc -l) -gt 0 ]]; then
                stop_process "feh"
            fi
            ;;
        *)
            if [[ "$CURR_MODE" != "mobro" || "$CURR_PAGE" != "$1" ]]; then
                if [[ $(ps ax | grep feh | grep -v "grep" | wc -l) -eq 0 ]]; then
                    show_logo ${MODBROS_LOGO}
                fi
                stop_process "chromium-browser"
                show_mobro "$1"
                stop_process "feh"
            fi
            CURR_MODE='mobro'
            CURR_PAGE="$1"
            ;;
    esac
}

create_access_point() {
    log "create_access_point" "creating access point"

    # scan for available wifi networks
    sudo ifconfig wlan0 up
    sleep_pi 2 5
    sudo iwlist wlan0 scan | grep -i essid: | sed 's/^.*"\(.*\)"$/\1/' > "$NETWORKS_FILE"

    show_page 2

    # create access point
    sudo create_ap \
        -w 2 \
        -m none \
        --isolate-clients \
        --freq-band 2.4 \
        --driver nl80211 \
        --no-virt \
        --daemon \
        -g 192.168.4.1 \
        wlan0 $AP_SSID $AP_PW \
        &>> "$LOG_DIR/log.txt"

    until [[ $(create_ap --list-running | grep wlan0 | wc -l) -gt 0 ]]; do
        log "create_access_point" "waiting for access point.."
        sleep 2
    done
    log "create_access_point" "access point up"
}

connect_wifi() {
    log "connect_wifi" "connecting to wifi: $1 $2"
    show_page 3

    # stop access point
    sudo create_ap --stop wlan0 &>> "$LOG_DIR/log.txt"
    sleep 2

    until [[ $(create_ap --list-running | grep wlan0 | wc -l) -eq 0 ]]; do
        log "connect_wifi" "waiting for access point to stop.."
        sleep 2
    done

    # configure wifi
    sudo cp -f /home/modbros/ModbrosMonitoring/config/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf

    sudo sed -i -e "s/SSID_PLACEHOLDER/$1/g" /etc/wpa_supplicant/wpa_supplicant.conf
    sudo sed -i -e "s/PW_PLACEHOLDER/$2/g" /etc/wpa_supplicant/wpa_supplicant.conf

    sudo systemctl restart dhcpcd.service
    sudo systemctl restart networking.service

    # wait for connection
    for i in {1..15}
    do
        if [[ $(iwgetid wlan0 --raw) ]]; then
            break;
        fi
        sleep 2
    done

    if [[ $(iwgetid wlan0 --raw) ]]; then
        log "connect_wifi" "connected"
        show_page 4
        sleep_pi 5 10
        service_discovery
    else
        log "connect_wifi" "not connected"
        create_access_point
    fi
}

try_ip() {
    # $1 = IP, $2 = key
    log "service_discovery" "Trying IP: $1 with key: $2"
    if [[ $(curl -o /dev/null --silent --max-time 5 --connect-timeout 2 --write-out '%{http_code}' "$1:$MOBRO_PORT/discover?key=$2") -eq 200 ]]; then
        # found MoBro application -> done
        log "service_discovery" "MoBro application found on IP $1"
        show_page "http://$1:$MOBRO_PORT?version=$SERVICE_VERSION&name=$PI_VERSION"

        # write found (use file as kind of global variable)
        # -> this function is started in a sub process!
        echo "1" > "${MOBRO_FOUND_FLAG}"

        # write to file to find it faster on next boot
        echo "$1" > "${HOSTS_FILE}"
    fi
}

service_discovery() {
    # search available IPs on the network
    log "service_discovery" "starting service discovery"

    echo "0" > "${MOBRO_FOUND_FLAG}"
    sudo arp-scan --interface=wlan0 --localnet --retry=3 --timeout=500 --backoff=2 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" 2>> "$LOG_DIR/log.txt" 1>> "${HOSTS_FILE}"
    KEY=$(cat "$WIFI_FILE" | sed -n 3p)         # 3rd line contains MoBro connection key

    while read IP; do
        try_ip "$IP" "$KEY"
        if [[ $(cat "$MOBRO_FOUND_FLAG") -eq 1 ]]; then
            # found MoBro application -> done
            return
        fi
    done < "${HOSTS_FILE}"

    # fallback: get current IP of pi to try all host in range
    PI_IP=$(ifconfig wlan0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' 2>> "$LOG_DIR/log.txt")
    if ! [[ -z ${PI_IP} ]]; then
        PI_IP_1=$(echo "$PI_IP" | cut -d . -f 1)
        PI_IP_2=$(echo "$PI_IP" | cut -d . -f 2)
        PI_IP_3=$(echo "$PI_IP" | cut -d . -f 3)
        log "service_discovery" "trying all IPs in range $PI_IP_1.$PI_IP_2.$PI_IP_3.X"

        PI_IP_4=0
        while [[ ${PI_IP_4} -lt 255 ]]; do
            for j in $(seq $NUM_CORES)
            do
                try_ip "$PI_IP_1.$PI_IP_2.$PI_IP_3.$PI_IP_4" "$KEY" &
                pids[${j}]=$! # remember pids of started sub processes
                if [[ PI_IP_4 -ge 255 ]]; then
                    break;
                fi
                PI_IP_4=$((PI_IP_4 + 1))
            done

            # wait for all started checks to finish
            for pid in ${pids[*]}; do
                wait $pid
            done
            unset $pids

            # no need to continue if found
            if [[ $(cat "$MOBRO_FOUND_FLAG") -eq 1 ]]; then
                return
            fi
        done
    fi

    if [[ $(cat "$MOBRO_FOUND_FLAG") -ne 1 ]]; then
        # couldn't find application -> delete IPs
        log "service_discovery" "no MoBro application found"
        truncate -s 0 "${HOSTS_FILE}"
        show_page 5
    fi
}

hotspot_check() {
    UPDATED=$(cat "$WIFI_FILE" | sed -n 4p)        # 4th line contains updated timestamp
    if ! [[ -z ${UPDATED} ]]; then
        if [[ ${UPDATED} != ${LAST_CHECKED_WIFI} ]]; then
            SSID=$(cat "$WIFI_FILE" | sed -n 1p)   # 1st line contains SSID
            PW=$(cat "$WIFI_FILE" | sed -n 2p)     # 2nd line contains PW
            if ! [[ -z ${SSID} || -z ${PW} ]]; then
                # if there is new access data -> instantly try connecting
                LAST_CHECKED_WIFI=${UPDATED}
                HOTSPOT_COUNTER=0
                log "hotspot_check" "new credentials found. trying to connect with $SSID and $PW"
                connect_wifi "$SSID" "$PW"
                return
            fi
        fi
    fi

    HOTSPOT_COUNTER=$((HOTSPOT_COUNTER+1))
    if [[ ${HOTSPOT_COUNTER} -ge ${CHECK_INTERVAL_HOTSPOT} ]]; then
        log "hotspot_check" "start hotspot check"
        HOTSPOT_COUNTER=0
        if ! [[ -z ${SSID} || -z ${PW} ]]; then
            # wifi configured -> try again
            log "hotspot_check" "trying again to connect with $SSID and $PW"
            connect_wifi "$SSID" "$PW"
        fi
    else
        log "hotspot_check" "skipping hotspot check"
    fi
}

background_check() {
    BACKGROUND_COUNTER=$((BACKGROUND_COUNTER+1))
    if [[ ${BACKGROUND_COUNTER} -ge ${CHECK_INTERVAL_BACKGROUND} ]]; then
        log "background_check" "starting background check"
        BACKGROUND_COUNTER=0
        if [[ $(cat "$MOBRO_FOUND_FLAG") -ne 1 ]]; then
            show_page 4
        fi
        service_discovery
    else
        log "background_check" "skipping background check"
    fi
}


# ==========================================================
# Startup Sequence
# ==========================================================

# copy log files to preserve the previous 5 starts
mv -f "$LOG_DIR/log_3.txt" "$LOG_DIR/log_4.txt" 2>/dev/null
mv -f "$LOG_DIR/log_2.txt" "$LOG_DIR/log_3.txt" 2>/dev/null
mv -f "$LOG_DIR/log_1.txt" "$LOG_DIR/log_2.txt" 2>/dev/null
mv -f "$LOG_DIR/log_0.txt" "$LOG_DIR/log_1.txt" 2>/dev/null
cp -f "$LOG_DIR/log.txt" "$LOG_DIR/log_0.txt" 2>/dev/null

# clear current log
echo '' > "$LOG_DIR/log.txt"

log "Startup" "starting service"

# env vars
export DISPLAY=:0

# reset flag
echo "0" > "${MOBRO_FOUND_FLAG}"

# disable dnsmasq and hostapd
log "Startup" "disabling services: dnsmasq, hostapd"
sudo systemctl stop dnsmasq &>> "$LOG_DIR/log.txt"
sudo systemctl disable dnsmasq.service &>> "$LOG_DIR/log.txt"
sudo systemctl stop hostapd &>> "$LOG_DIR/log.txt"
sudo systemctl disable hostapd.service &>> "$LOG_DIR/log.txt"

# start x
init_x

# show background
show_logo ${MODBROS_LOGO}

# wait for CPU usage to come down
sleep_cpu

# check if wifi is configured
# (skip if no network set - e.g. first boot)
if [[ $(cat "$WIFI_FILE" | wc -l) -ge 4 ]]; then

    # scan for available networks to check if configured one is in range
    sudo iwlist wlan0 scan | grep -i essid: | sed 's/^.*"\(.*\)"$/\1/' > "$NETWORKS_FILE"
    WAIT_WIFI=1
    if [[ $(cat "$NETWORKS_FILE" | wc -l) -ge 1 ]]; then # check if scan returned anything first
        SSID=$(cat "$WIFI_FILE" | sed -n 1p) # SSID of configured network
        if [[ $(cat "$NETWORKS_FILE" | grep "$SSID" | wc -l) -eq 0 ]]; then
            log "Startup" "configured wifi network not in range"
            WAIT_WIFI=0
        fi
        unset ${SSID}
    fi

    if [[ ${WAIT_WIFI} -eq 1 ]]; then
        log "Startup" "waiting for wifi connection..."
        for i in {1..15}
        do
            if [[ $(iwgetid wlan0 --raw) ]]; then
                break;
            fi
            sleep 2
        done
    fi
    unset ${WAIT_WIFI}
fi

if [[ $(iwgetid wlan0 --raw) ]]; then
    log "Startup" "connected to wifi"
    IP=$(cat "$HOSTS_FILE" | sed -n 1p)   # get 1st host if present (from last successful connection)
    KEY=$(cat "$WIFI_FILE" | sed -n 3p)   # 3rd line contains MoBro connection key
    if ! [[ -z ${IP} || -z ${KEY} ]]; then
        log "Startup" "found previously used host - checking"
        try_ip "$IP" "$KEY"
        if [[ $(cat "$MOBRO_FOUND_FLAG") -eq 1 ]]; then
            log "Startup" "found previously used host - success"
        else
            log "Startup" "previous host invalid, continuing"
        fi
    fi

    if [[ $(cat "$MOBRO_FOUND_FLAG") -ne 1 ]]; then
        # no previous present or no longer valid -> start service discovery
        log "Startup" "no previous or invalid - starting search"
        show_page 4
        service_discovery
    fi
else
    log "Startup" "no wifi connection"
    # not connected to wifi -> start hotspot
    create_access_point
fi


# ==========================================================
# Main Loop
# ==========================================================

log "Main" "Entering main loop"
while true; do
    if [[ $(create_ap --list-running | grep wlan0 | wc -l) -eq 0 ]]; then
        # no hotspot running
        log "Main" "no hotspot"
        if ! [[ $(iwgetid wlan0 --raw) ]]; then
            log "Main" "no wifi"
            create_access_point
        else
            log "Main" "wifi connected"
            # we're connected - keep checking in background (page still response / page becomes available)
            background_check
        fi
    else
        log "Main" "hotspot up"
        # check for new wifi data + if hotspot open too long, try to connect to wifi again
        hotspot_check
    fi
    sleep ${LOOP_INTERVAL}
done

log "Main" "unexpected shutdown"