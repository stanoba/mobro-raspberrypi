#!/bin/bash

# ====================================================================================================================
# Modbros Monitoring Service (MoBro) - Raspberry Pi image
# Copyright (C) 2020 ModBros
# Contact: mod-bros.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# ====================================================================================================================

# Directories
LOG_DIR='/home/modbros/mobro-raspberrypi/log'
RESOURCES_DIR='/home/modbros/mobro-raspberrypi/resources'
DATA_DIR='/home/modbros/mobro-raspberrypi/data'

# Files
MOBRO_CONFIG_FILE="$DATA_DIR/mobro_config"
HOSTS_FILE="$DATA_DIR/hosts"
SSIDS_FILE="$DATA_DIR/ssids"
VERSION_FILE="$DATA_DIR/version"
MOBRO_FOUND_FLAG="$DATA_DIR/mobro_found"
LOG_FILE="$LOG_DIR/log.txt"

# Resources
IMAGE_MOBRO="$RESOURCES_DIR/mobro.png"
IMAGE_FOUND="$RESOURCES_DIR/found.png"
IMAGE_NOTFOUND="$RESOURCES_DIR/notfound.png"
IMAGE_CONNECTWIFI="$RESOURCES_DIR/connectwifi.png"
IMAGE_DISCOVERY="$RESOURCES_DIR/discovery.png"
IMAGE_HOTSPOT="$RESOURCES_DIR/hotspot.png"
IMAGE_HOTSPOTCREATION="$RESOURCES_DIR/creatinghotspot.png"
IMAGE_WIFIFAILED="$RESOURCES_DIR/wififailed.png"
IMAGE_WIFISUCCESS="$RESOURCES_DIR/wifisuccess.png"
IMAGE_NOWIFIINTERFACE="$RESOURCES_DIR/nowifiinterface.png"
IMAGE_ETHSUCCESS="$RESOURCES_DIR/ethsuccess.png"
IMAGE_USBSUCCESS="$RESOURCES_DIR/ethsuccess.png"

# Ports
MOBRO_PORT='42100'            # port of the MoBro desktop application

# Global Constants
AP_SSID='MoBro_Configuration' # ssid of the created access point
LOOP_INTERVAL=60              # in seconds
AP_RETRY_WAIT=20              # how long to wait for AP to start/stop before issuing command again (in s)
AP_FAIL_WAIT=90               # how long to wait until AP creation/stopping is considered failed -> reboot (in s)
STARTUP_WIFI_WAIT=45          # seconds to wait for wifi connection on startup (if wifi configured)

# Global Vars
LOOP_COUNTER=0             # counter variable for main loop iterations
CURR_URL=''                # save current chromium Url
CURR_IMAGE=''              # save currently displayed image
NETWORK_MODE=''            # save current network mode (eth|wifi|usb)
SCREENSAVER=0              # flag if screensaver is active
LAST_CONNECTED=$(date +%s) # timestamp (epoch seconds) of last successful connection check

# ====================================================================================================================
# Functions
# ====================================================================================================================

log() {
    local temp date
    temp=$(sudo vcgencmd measure_temp)
    date=$(date "+%d.%m.%y %T")
    echo "$date [$LOOP_COUNTER][${temp:5:-4}][$1] $2" >>$LOG_FILE
}

prop() {
    grep "$1" "$2" | cut -d '=' -f2
}

wait_window() {
    until [[ $(xdotool search --onlyvisible --class "$1" | wc -l) -gt 0 ]]; do
        log "helper" "waiting for $1 to become available.."
        sleep 3
    done
}

stop_process() {
    log "helper" "stopping process: $1"
    sudo pkill "$1" 2>>$LOG_FILE
    for i in {4..0}; do
        if [[ $(pgrep -fc "$1") -eq 0 ]]; then
            return
        fi
        sleep 2
    done
    log "helper" "killing process: $1"
    sudo pkill -9 "$1" 2>>$LOG_FILE
    sleep_pi 1 2
}

stop_chrome() {
    stop_process "chromium"
    CURR_URL=''
}

stop_feh() {
    stop_process "feh"
    CURR_IMAGE=''
}

sleep_pi() {
    if [[ $(nproc --all) -gt 1 ]]; then
        sleep "$1"
    else
        sleep "$2"
    fi
}

show_image() {
    if [[ $(pgrep -fc chromium) -gt 0 ]]; then
        stop_chrome
        sleep_pi 1 2
    fi
    if [[ $(pgrep -fc feh) -gt 0 ]]; then
        if [[ $CURR_IMAGE == "$1" ]]; then
            # already showing requested image
            return
        fi
        stop_feh
    fi
    CURR_IMAGE="$1"
    log "feh" "switching to image $1"
    feh \
        --fullscreen \
        --hide-pointer \
        --no-menus \
        --scale-down \
        --auto-zoom \
        --image-bg "white" \
        "$1" &>>$LOG_FILE &

    sleep "${2:-1}"
}

show_page_chrome() {
    if [[ $(pgrep -fc chromium) -gt 0 ]]; then
        if [[ $CURR_URL == "$1" ]]; then
            # already showing requested page
            return
        fi
        stop_chrome
    fi
    stop_feh
    CURR_URL="$1"
    log "chromium" "switching to: '$1'"
    # check-for-update-interval flag can be removed once chromium is fixed
    # temporary workaround for: https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=264399
    chromium-browser "$1" \
        --noerrdialogs \
        --incognito \
        --check-for-update-interval=2592000 \
        --kiosk \
        &>>$LOG_FILE &
    wait_window "chromium"
}

show_mobro() {
    local name version uuid resolution url
    name=$(cat /proc/device-tree/model)                                  # pi version name (e.g. Raspberry Pi 3 Model B Plus Rev 1.3)
    version=$(sed -n 1p <$VERSION_FILE)                                  # service version number
    resolution=$(xdpyinfo | awk '/dimensions/{print $2}') # current display resolution
    uuid=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2) # get pi serial number as unique ID
    url="http://$1:$MOBRO_PORT?version=$version&uuid=$uuid&resolution=$resolution&device=pi&name=$name"
    SCREENSAVER=0
    LAST_CONNECTED=$(date +%s)
    show_page_chrome "$url"
}

show_screensaver() {
    if [[ $SCREENSAVER == 0 ]]; then
        log "screensaver" "activating screensaver: $1"
    fi
    SCREENSAVER=1
    show_page_chrome "http://localhost/screensavers/$1"
}

search_ssids() {
    log "search_ssids" "scanning for wireless networks"
    sudo iwlist wlan0 scan | grep -i essid: | sed 's/^.*"\(.*\)"$/\1/' 2>>$LOG_FILE 1>$SSIDS_FILE
    log "search_ssids" "detected wifi networks in range:"
    cat $SSIDS_FILE &>>$LOG_FILE
}

create_access_point() {
    log "create_access_point" "creating access point"

    show_image $IMAGE_HOTSPOTCREATION

    # scan for available wifi networks
    # (we can't do that once we the access point is up)
    search_ssids

    # create access point
    create_access_point_call
    sleep_pi 2 5

    local ap_create_counter ap_retry ap_fail
    ap_create_counter=1
    ap_retry=$((AP_RETRY_WAIT / 5))
    ap_fail=$((AP_FAIL_WAIT / 5))
    until is_access_point_open; do
        ap_create_counter=$((ap_create_counter + 1))
        if [[ $ap_create_counter -gt $ap_fail ]]; then
            log "create_access_point" "failed to create access point multiple times - rebooting.."
            sudo shutdown -r now
        fi
        if [[ $((ap_create_counter % ap_retry)) -eq 0 ]]; then
            log "create_access_point" "failed to create access point - trying again"
            create_access_point_call
        fi
        log "create_access_point" "waiting for access point.."
        sleep 5
    done

    log "create_access_point" "access point up"
    show_image $IMAGE_HOTSPOT
}

create_access_point_call() {
    sudo create_ap \
        -w 2 \
        -m none \
        --isolate-clients \
        --freq-band 2.4 \
        --driver nl80211 \
        --no-virt \
        --daemon \
        -g 192.168.4.1 \
        wlan0 $AP_SSID \
        &>>$LOG_FILE
}

is_access_point_open() {
    if [[ $(create_ap --list-running | grep wlan0 -c) -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

set_mobro_found() {
    echo "1" >$MOBRO_FOUND_FLAG
    echo "$1" >$HOSTS_FILE
}

is_mobro_found() {
    if [[ $(cat $MOBRO_FOUND_FLAG) -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

try_ip_static() {
    local response_code
    response_code=$(curl -o /dev/null --silent --connect-timeout 5 --retry 2 --write-out '%{http_code}' "$1:$MOBRO_PORT/discover")
    if [[ $response_code == 403 || $response_code == 200 ]]; then
        # 403 -> mobro is there but wrong connection key.
        # since we're going for static ip, we don't need to match the key
        set_mobro_found "$1"
        return 0
    else
        return 1
    fi
}

try_ip() {
    # $1 = IP, $2 = key
    if [[ $(curl -o /dev/null --silent --max-time 5 --connect-timeout 3 --write-out '%{http_code}' "$1:$MOBRO_PORT/discover?key=$2") -eq 200 ]]; then
        # 200 -> mobro is there and we're using the correct connection key
        set_mobro_found "$1"
        return 0
    else
        return 1
    fi
}

service_discovery() {

    echo "0" >$MOBRO_FOUND_FLAG
    if [[ $SCREENSAVER == 0 ]]; then
        show_image $IMAGE_DISCOVERY 2
    fi

    local mode ip key interface
    mode=$(prop 'discovery_mode' $MOBRO_CONFIG_FILE)
    key=$(prop 'discovery_key' $MOBRO_CONFIG_FILE)
    ip=$(prop 'discovery_ip' $MOBRO_CONFIG_FILE)
    case $NETWORK_MODE in
    "wifi") interface='wlan0' ;;
    "eth") interface='eth0' ;;
    "usb") interface='usb0' ;;
    esac

    # check if static ip is configured
    if [[ $mode == "manual" ]]; then
        log "service_discovery" "configured to use static ip. trying: $ip"
        if try_ip_static "$ip"; then
            log "service_discovery" "MoBro application found on static IP $ip"
            set_mobro_found "$ip"
            show_image $IMAGE_FOUND 5
            show_mobro "$ip"
        else
            log "service_discovery" "no MoBro application found on static ip $ip"
            if [[ $SCREENSAVER == 0 ]]; then
                show_image $IMAGE_NOTFOUND
            fi
        fi
        return
    fi

    log "service_discovery" "configured to automatic discovery using connection key"
    # check previous host if configured
    ip=$(sed -n 1p <$HOSTS_FILE) # get 1st host if present (from last successful connection)
    if ! [[ -z $ip || -z $key ]]; then
        log "service_discovery" "checking previous host on $ip with key '$key'"
        try_ip "$ip" "$key"
    fi

    if ! is_mobro_found; then
        # search available IPs on the network via arp scan
        log "service_discovery" "performing arp scan"
        sudo arp-scan \
            --interface="$interface" \
            --localnet \
            --retry=3 \
            --timeout=500 \
            --backoff=2 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" \
            2>>$LOG_FILE 1>>"$HOSTS_FILE"

        while read -r ip; do
            log "service_discovery" "trying IP: $ip with key: $key"
            try_ip "$ip" "$key" &
            pids[$j]=$! # remember pids of started sub processes
            if is_mobro_found; then
                break # no need to continue if found
            fi
        done <$HOSTS_FILE

        for pid in ${pids[*]}; do
            # wait for all started checks to finish
            wait $pid
        done
        unset pids
    fi

    if ! is_mobro_found; then
        # fallback: get current ip of pi to try all host in range
        log "service_discovery" "fallback"
        local pi_ip
        pi_ip=$(ifconfig "$interface" | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' 2>>$LOG_FILE)
        if [[ -n $pi_ip ]]; then
            local pi_ip_1 pi_ip_2 pi_ip_3 pi_ip_4
            pi_ip_1=$(echo "$pi_ip" | cut -d . -f 1)
            pi_ip_2=$(echo "$pi_ip" | cut -d . -f 2)
            pi_ip_3=$(echo "$pi_ip" | cut -d . -f 3)
            pi_ip_4=0
            log "service_discovery" "trying all IPs in range $pi_ip_1.$pi_ip_2.$pi_ip_3.X"

            local num_cores
            num_cores=$(nproc --all)
            while [[ $pi_ip_4 -lt 255 ]]; do
                for j in $(seq $((5 * num_cores))); do
                    try_ip "$pi_ip_1.$pi_ip_2.$pi_ip_3.$pi_ip_4" "$key" &
                    pids[$j]=$! # remember pids of started sub processes
                    if [[ pi_ip_4 -ge 255 ]]; then
                        break
                    fi
                    pi_ip_4=$((pi_ip_4 + 1))
                done

                # wait for all started checks to finish
                for pid in ${pids[*]}; do
                    wait $pid
                done
                unset

                if is_mobro_found; then
                    break # no need to continue if found
                fi
            done
        fi
    fi

    if is_mobro_found; then
        # found MoBro application
        log "service_discovery" "MoBro application found on IP $ip"
        show_image $IMAGE_FOUND 5
        show_mobro "$(sed -n 1p <$HOSTS_FILE)"
    else
        # couldn't find application -> delete IPs
        log "service_discovery" "no MoBro application found"
        truncate -s 0 $HOSTS_FILE
        if [[ $SCREENSAVER == 0 ]]; then
            show_image $IMAGE_NOTFOUND 5
        fi
    fi
}

check_screensaver() {
    # check if screensaver is configured
    local screensaver
    screensaver=$(prop 'display_screensaver' $MOBRO_CONFIG_FILE)
    if [[ -z $screensaver || $screensaver == "disabled" ]]; then
        # no screensaver configured
        return
    fi

    # screensaver configured -> check delay
    local delay
    delay=$(prop 'display_delay' $MOBRO_CONFIG_FILE)
    if [[ -n $delay ]]; then
        local diff, now
        now=$(date +%s)
        diff=$((now - LAST_CONNECTED))
        delay=$((delay * 60))
        log "screensaver" "delay: $diff/$delay"
        if [[ $diff -gt $delay ]]; then
            # delay reached -> show
            show_screensaver "$screensaver"
        fi
    else
        # no delay -> just show screensaver
        show_screensaver "$screensaver"
    fi
}

background_check() {
    # check if host is still reachable
    # if we made a successful connection the IP will be in the hosts file
    local ip
    ip=$(sed -n 1p <$HOSTS_FILE)
    if [[ -z $ip ]]; then
        log "background_check" "no previous host found. starting discovery"
        check_screensaver
        service_discovery
        return
    fi

    # try multiple times to make sure we didn't just drop connection for a few seconds
    local response_code
    response_code=$(curl -o /dev/null --silent --connect-timeout 5 --retry 5 --write-out '%{http_code}' "$ip:$MOBRO_PORT/discover")
    if [[ $response_code == 403 || $response_code == 200 ]]; then
        # reachable
        log "background_check" "MoBro on $ip reachable"
        show_mobro "$ip"
        return
    fi

    # we lost connection
    log "background_check" "MoBro on $ip no longer reachable (code $response_code)"
    if [[ $SCREENSAVER == 0 ]]; then
        show_image $IMAGE_NOTFOUND 10
    fi

    # check if we need to show screensaver
    check_screensaver

    # start searching again
    service_discovery
}

wifi_check() {
    # check if wifi is configured
    # (skip if no network set - e.g. first boot)
    local mode
    mode=$(prop 'network_mode' $MOBRO_CONFIG_FILE)
    if [[ -z "$mode" ]]; then
        log "startup" "no previous network configuration found"
        create_access_point
        return
    fi

    show_image $IMAGE_CONNECTWIFI
    # check if configured network is in range
    log "startup" "scanning for wireless networks"
    search_ssids
    local wait_wifi ssid
    wait_wifi=1
    if [[ $(wc -l <$SSIDS_FILE) -ge 1 ]]; then # check if scan returned anything first
        ssid=$(prop 'network_ssid' $MOBRO_CONFIG_FILE)
        if [[ $(grep "$ssid" -c <$SSIDS_FILE) -eq 0 ]]; then
            wait_wifi=0
        fi
    fi

    if [[ $wait_wifi -ne 1 ]]; then
        # previous wifi not reachable
        log "startup" "configured wifi network '$ssid' not in range"
        show_image $IMAGE_WIFIFAILED 10
        create_access_point
        return
    fi

    log "startup" "waiting for wifi connection to network '$ssid'..."
    local wifi_connected wifi_connect_count
    wifi_connected=0
    wifi_connect_count=0
    until [[ $wifi_connect_count -ge $STARTUP_WIFI_WAIT ]]; do
        if [[ $(iwgetid wlan0 --raw) ]]; then
            wifi_connected=1
            break
        fi
        sleep 5
        wifi_connect_count=$((wifi_connect_count + 5))
    done

    if [[ $wifi_connected -ne 1 ]]; then
        log "startup" "couldn't connect to wifi network '$ssid'"
        show_image $IMAGE_WIFIFAILED 10
        create_access_point
        return
    fi

    log "startup" "connected to wifi network '$ssid'"
    show_image $IMAGE_WIFISUCCESS 3

    # search network for application
    service_discovery
}

# ====================================================================================================================
# Startup Sequence
# ====================================================================================================================

# copy log files to preserve the previous 10 starts
for i in {8..0}; do
    mv -f "$LOG_DIR/log_$i.txt" "$LOG_DIR/log_$((i + 1)).txt" 2>/dev/null
done
cp -f $LOG_FILE "$LOG_DIR/log_0.txt" 2>/dev/null

# clear current log
echo '' >$LOG_FILE

log "startup" "starting service"

# env vars
export DISPLAY=:0

# reset flag
echo "0" >$MOBRO_FOUND_FLAG

# disable dnsmasq and hostapd
log "startup" "disabling services: dnsmasq, hostapd"
{
    sudo systemctl stop
    sudo systemctl disable dnsmasq.service
    sudo systemctl stop hostapd
    sudo systemctl disable hostapd.service
} &>>$LOG_FILE

# determine and set network mode
if [[ $(grep up /sys/class/net/*/operstate | grep usb0 -c) -gt 0 ]]; then
    log "startup" "network mode set to USB ETHERNET"
    NETWORK_MODE='usb'
elif [[ $(grep up /sys/class/net/*/operstate | grep eth0 -c) -gt 0 ]]; then
    log "startup" "network mode set to ETHERNET"
    NETWORK_MODE='eth'
else
    log "startup" "network mode set to WIFI"
    NETWORK_MODE='wifi'
fi

# start x
log "startup" "starting x server"
sudo xinit \
    /bin/sh -c "exec /usr/bin/matchbox-window-manager -use_titlebar no -use_cursor no" \
    -- -nocursor \
    &>>$LOG_FILE &

# wait for x server
sleep 2
NO_SCREEN_FOUND=0
while ! xset q &>/dev/null; do
    log "startup" "waiting for X.."
    if [[ $(grep -c "no screens found" $LOG_FILE) -gt 0 ]]; then
        NO_SCREEN_FOUND=1
        stop_process "xinit"
        break
    fi
    sleep 5
done
sleep_pi 2 5

# handle case if no connected display is found
if [[ $NO_SCREEN_FOUND == 1 ]]; then
    log "startup" "no screen found. skipping X and waiting for display configuration"
    if [[ $NETWORK_MODE == "wifi" ]]; then
        search_ssids
        log "startup" "creating access point"
        create_access_point_call
    fi
    while true; do
        sleep 60
    done
fi

# show background
show_image $IMAGE_MOBRO 7

# disabling screen blanking
log "startup" "disable blank screen"
{
    sudo xset s off
    sudo xset -dpms
    sudo xset s noblank
} &>>$LOG_FILE

case $NETWORK_MODE in
"wifi")
    # check for wifi interface
    if [[ $(ifconfig -a | grep wlan -c) -lt 1 ]]; then
        log "startup" "no wifi interface detected, aborting"
        show_image $IMAGE_NOWIFIINTERFACE
        while true; do
            sleep 60
        done
    fi
    # unblock the wifi interface
    log "startup" "unblocking wifi interface"
    sudo rfkill unblock 0 &>>$LOG_FILE
    # try to connect to wifi (if previously configured)
    # and try to connect to mobro
    wifi_check
    ;;
"eth")
    show_image $IMAGE_ETHSUCCESS 3
    # search network for application
    service_discovery
    ;;
"usb")
    show_image $IMAGE_USBSUCCESS 3
    # search network for application
    service_discovery
    ;;
esac

# ====================================================================================================================
# Main Loop
# ====================================================================================================================

log "main" "Entering main loop"
while true; do
    sleep $LOOP_INTERVAL
    LOOP_COUNTER=$((LOOP_COUNTER + 1))

    case $NETWORK_MODE in
    "wifi")
        if ! is_access_point_open; then
            # no hotspot running
            if ! [[ $(iwgetid wlan0 --raw) ]]; then
                create_access_point
            else
                # we're connected - keep checking in background if the PC is still available
                background_check
            fi
        fi
        ;;
    "eth")
        background_check
        ;;
    "usb")
        background_check
        ;;
    esac

done

log "main" "unexpected shutdown"
