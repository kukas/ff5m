#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/output"

cat > "$TMP/bin/wget" <<'EOF'
#!/bin/sh

output=''
url=''

while [ "$#" -gt 0 ]; do
    case "$1" in
        -O)
            output=$2
            shift 2
        ;;
        -T)
            shift 2
        ;;
        -q)
            shift
        ;;
        *)
            url=$1
            shift
        ;;
    esac
done

case "$url" in
    *printer/objects/query*)
        count_file="$TEST_TMP/state-count"
        count=0
        [ -f "$count_file" ] && count=$(cat "$count_file")
        count=$((count + 1))
        printf '%s\n' "$count" > "$count_file"

        if [ "$count" -le 2 ]; then
            printf '%s' '{"result":{"status":{"print_stats":{"filename":"test.gcode","state":"printing"}}}}'
        else
            printf '%s' '{"result":{"status":{"print_stats":{"filename":"test.gcode","state":"complete"}}}}'
        fi
    ;;
    *)
        printf '\377\330\377\300' > "$output"
    ;;
esac
EOF
chmod +x "$TMP/bin/wget"

cat > "$TMP/timelapse.conf" <<EOF
INTERVAL=1
SNAPSHOT_URL=http://127.0.0.1:8080/?action=snapshot
OUTPUT_DIR=$TMP/output
MIN_FREE_KB=0
LOG_FILE=$TMP/timelapse.log
PID_FILE=$TMP/timelapse.pid
EOF

TEST_TMP="$TMP" PATH="$TMP/bin:$PATH" \
    "$ROOT/.shell/timelapse.sh" "$TMP/timelapse.conf" &
pid=$!

sleep 4
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true

frame_count=$(find "$TMP/output" -name 'frame_*.jpg' | wc -l | tr -d ' ')
[ "$frame_count" -eq 2 ]
grep -q 'capture finished:.*2 frames, state=complete' "$TMP/timelapse.log"

echo "timelapse test passed"
