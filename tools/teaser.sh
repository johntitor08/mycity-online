#!/bin/bash
# Tanıtım videosunu çeker: build/teaser/mycity-teaser.mp4 (1920x1080, 30 fps, oyun sesiyle).
set -e
cd "$(dirname "$0")/.."
OUT=build/teaser
rm -rf "$OUT/kareler" && mkdir -p "$OUT/kareler"
flatpak run --command=godot org.godotengine.Godot --path . --resolution 1920x1080 --fixed-fps 30 \
	--write-movie "$OUT/kareler/kare.png" -- --teaser 2>&1 | tee "$OUT/kayit.log" | grep -E "TEASER|SCRIPT ERROR" || true
START=$(grep -o "TEASER_BASLA [0-9]*" "$OUT/kayit.log" | awk '{print $2}')
END=$(grep -o "TEASER_BITTI [0-9]*" "$OUT/kayit.log" | awk '{print $2}')
SS=$(python3 -c "print($START/30)")
DUR=$(python3 -c "print(($END-$START)/30)")
ffmpeg -y -loglevel error -framerate 30 -start_number "$START" -i "$OUT/kareler/kare%08d.png" \
	-ss "$SS" -i "$OUT/kareler/kare.wav" -t "$DUR" \
	-af "afade=t=in:d=1,afade=t=out:st=$(python3 -c "print($DUR-1.2)"):d=1.2,loudnorm=I=-16" \
	-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart \
	-shortest "$OUT/mycity-teaser.mp4"
rm -rf "$OUT/kareler"
ls -la "$OUT/mycity-teaser.mp4"
