#!/bin/sh

CFG_PATH="${1:-/opt/config/mod_data/timelapse.conf}"
STATE_URL='http://127.0.0.1:7125/printer/objects/query?print_stats'
LOG_FILE=/data/logFiles/timelapse.log
PID_FILE=/run/timelapse.pid

INTERVAL=15
SNAPSHOT_URL='http://127.0.0.1:8080/?action=snapshot'
OUTPUT_DIR=/data/timelapse
MIN_FREE_KB=1048576

[ -f "$CFG_PATH" ] && . "$CFG_PATH"

mkdir -p "$OUTPUT_DIR" "$(dirname "$LOG_FILE")"
trap 'rm -f "$PID_FILE"; exit 0' INT TERM EXIT

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

safe_name() {
    printf '%s' "$1" \
        | sed 's/\.gcode$//' \
        | tr -c 'A-Za-z0-9._-' '_' \
        | cut -c1-80
}

free_kb() {
    df -k "$OUTPUT_DIR" | awk 'NR == 2 { print $4 }'
}

session=''
frame=0
last_state=''
space_warning=0
snapshot_warning=0

log "service started; interval=${INTERVAL}s"

while :; do
    status=$(wget -q -T 5 -O - "$STATE_URL" 2>/dev/null)
    state=$(printf '%s' "$status" \
        | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')

    if [ "$state" = printing ]; then
        if [ -z "$session" ]; then
            filename=$(printf '%s' "$status" \
                | sed -n 's/.*"filename":"\([^"]*\)".*/\1/p')
            name=$(safe_name "${filename:-print}")
            session="$OUTPUT_DIR/$(date '+%Y%m%d-%H%M%S')_${name}"
            mkdir -p "$session"
            printf '%s\n' "$filename" > "$session/print-name.txt"
            frame=0
            log "capture started: $session"
        fi

        free=$(free_kb)
        if [ -n "$free" ] && [ "$free" -ge "$MIN_FREE_KB" ]; then
            space_warning=0
            frame=$((frame + 1))
            target=$(printf '%s/frame_%06d.jpg' "$session" "$frame")
            temp="${target}.tmp"

            if wget -q -T 10 -O "$temp" "$SNAPSHOT_URL" && [ -s "$temp" ]; then
                mv "$temp" "$target"
                snapshot_warning=0
            else
                rm -f "$temp"
                frame=$((frame - 1))
                if [ "$snapshot_warning" -eq 0 ]; then
                    log "snapshot failed"
                    snapshot_warning=1
                fi
            fi
        elif [ "$space_warning" -eq 0 ]; then
            log "capture paused: less than ${MIN_FREE_KB} KiB free"
            space_warning=1
        fi
    else
        case "$state" in
            complete|cancelled|canceled|error|standby)
                if [ -n "$session" ]; then
                    log "capture finished: $session ($frame frames, state=$state)"
                    session=''
                    frame=0
                    space_warning=0
                    snapshot_warning=0
                fi
            ;;
        esac
    fi

    if [ "$state" != "$last_state" ]; then
        log "printer state: ${state:-unavailable}"
        last_state="$state"
    fi

    sleep "$INTERVAL"
done
