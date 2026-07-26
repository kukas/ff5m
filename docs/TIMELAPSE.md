## Local Timelapse Capture

Forge-X can save a JPEG frame every 15 seconds while a print is actively
running. Frames remain on the printer and are never uploaded.

### Requirements

- Enable the [Forge-X camera](/docs/CAMERA.md).
- Keep at least 1 GiB free on `/data`.
- Configure the camera snapshot URL in `mod_data/timelapse.conf` if it differs
  from the default Forge-X endpoint.

### Enable Capture

Run this command in the printer console:

```gcode
SET_MOD PARAM="timelapse" VALUE=1
```

Capture begins automatically with the next print. Pausing a print also pauses
capture, and resuming continues in the same directory. Check the service with:

```gcode
TIMELAPSE_STATUS
```

### Storage

Each print is stored under a timestamped directory:

```text
/data/timelapse/YYYYMMDD-HHMMSS_print-name/frame_000001.jpg
```

The service stops writing when free space falls below `MIN_FREE_KB`, which
defaults to 1 GiB. It does not delete existing captures automatically. Download
or remove completed sessions when they are no longer needed.

Settings are stored in `mod_data/timelapse.conf`:

```cfg
INTERVAL=15
SNAPSHOT_URL=http://127.0.0.1:8080/?action=snapshot
OUTPUT_DIR=/data/timelapse
MIN_FREE_KB=1048576
```

The printer stores JPEG frames rather than encoding video during a print. This
keeps CPU and memory use low on the 128 MiB controller. Encode the frames on
another computer after downloading them.

### Disable Capture

```gcode
SET_MOD PARAM="timelapse" VALUE=0
```
