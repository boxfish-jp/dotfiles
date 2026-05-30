#!/usr/bin/env bash 
# @vicinae.schemaVersion 1
# @vicinae.title connect-audio
# @vicinae.mode silent
# @vicinae.description サスペンドから復帰した後にオーディオを繋げます

SPEAKER="alsa:acp:NVidia:4:playback"
TRICAPTURE_OUT="alsa:acp:TRICAPTURE:4:playback"
DEFAULT="default-output"
FOR_OBS="for-obs"

pw-link "$DEFAULT:monitor_1" "$TRICAPTURE_OUT:playback_1"
pw-link "$DEFAULT:monitor_0" "$TRICAPTURE_OUT:playback_0"
pw-link "$FOR_OBS:monitor_1" "$TRICAPTURE_OUT:playback_1"
pw-link "$FOR_OBS:monitor_0" "$TRICAPTURE_OUT:playback_0"
pw-link "$DEFAULT:monitor_1" "$SPEAKER:playback_1"
pw-link "$DEFAULT:monitor_0" "$SPEAKER:playback_0"
pw-link "$FOR_OBS:monitor_1" "$SPEAKER:playback_1"
pw-link "$FOR_OBS:monitor_0" "$SPEAKER:playback_0"


echo "[OK] Default sink set & permanent link established."

exit 0
