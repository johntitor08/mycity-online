#!/bin/bash
# Büyük tanıtım videosu: oyunun bütün özellikleri (build/teaser/mycity-teaser-dev.mp4; 1280x720 kaydedilip 1920x1080'e büyütülür, 30 fps).
# Her bölüm ekran görüntüsü betiğinin (tests/screenshot.gd) "--klip" kipiyle ayrı ayrı kaydedilir;
# görüntü anları kliplere dönüşür (tests/teaser_clips.gd), aradaki siyah hazırlık kesilir, sonra
# bölümler birleştirilip altına oyunun müzikleri döşenir.
# Kullanım: tools/teaser_dev.sh            (hepsi)
#           tools/teaser_dev.sh acilis sadece21   (sadece bu bölümleri yeniden kaydet)
#           tools/teaser_dev.sh birlestir          (kayıt yapmadan birleştir)
set -e
cd "$(dirname "$0")/.."
OUT=build/teaser/dev
mkdir -p "$OUT"
ALL="acilis genel sadece09 sadece08 sadece10 sadece11 sadece12 sadece13 sadece14 sadece15 sadece16 sadece17 sadece18 sadece19 sadece20 sadece21 icmekan dokunmatik sunucular kapanis"
SECTIONS="${*:-$ALL}"
[ "$1" = birlestir ] && SECTIONS=""          # tools/teaser_dev.sh birlestir: sadece birleştir
G="flatpak run --command=godot org.godotengine.Godot --path ."

kaydet() {
	local s=$1 extra=()
	[ "$s" != genel ] && extra=("--$s")
	local srv=""
	if [ "$s" = sunucular ]; then
		# yerel ağda ikinci bir sunucu: listede kendiliğinden görünsün
		$G --headless -- --sunucu --port=7796 --kayit=user://teaser_srv2.json --ad="Gece Şehri" \
			--aciklama="Arkadaş sunucusu · hızlı ekonomi" > /dev/null 2>&1 &
		srv=$!
		sleep 4
	fi
	rm -f "$OUT/$s.avi"
	$G --display-driver x11 --resolution 1920x1080 --fixed-fps 30 --write-movie "$OUT/$s.avi" \
		-- --foto --klip "${extra[@]}" > "$OUT/$s.log" 2>&1 || true
	[ -n "$srv" ] && for p in $(pgrep -f "godot-bin.*teaser_srv2[.]json"); do kill "$p"; done
	grep -E "SCRIPT ERROR" "$OUT/$s.log" | head -3 || true
	python3 - "$OUT/$s.log" "$OUT/$s.avi" "$OUT/$s.mp4" <<'PY'
import re, subprocess, sys
log, avi, mp4 = sys.argv[1:4]
txt = open(log, encoding="utf-8", errors="replace").read()
a = [int(x) for x in re.findall(r"KLIP_BASLA (\d+)", txt)]
b = [int(x) for x in re.findall(r"KLIP_BITTI (\d+)", txt)]
pairs = list(zip(a, b))
if not pairs:
    print("  klip yok:", log); sys.exit(0)
vs = "+".join("between(n,%d,%d)" % (x, y) for x, y in pairs)
# Sadece görüntü: hızlandırılmış hazırlık yüzünden AVI'deki ses zaman çizelgesi görüntüyle örtüşmüyor
# (kesilen ses görüntüden uzun kalıyor, birleşince son kare donuyordu). Altına müzik döşenir.
fc = "[0:v]select='%s',setpts=N/30/TB[v]" % vs
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", avi, "-filter_complex", fc, "-map", "[v]", "-an",
    "-r", "30", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", mp4], check=True)
print("  %s: %d klip, %.1f sn" % (mp4, len(pairs), sum(y - x + 1 for x, y in pairs) / 30))
PY
	rm -f "$OUT/$s.avi"
}

for s in $SECTIONS; do
	echo "== $s"
	kaydet "$s"
done

# birleştir
LIST="$OUT/liste.txt"
: > "$LIST"
for s in $ALL; do
	if [ -f "$OUT/$s.mp4" ]; then
		# sadece görüntü (eski kayıtlarda uzun kalan ses izi birleşince boşluk bırakıyordu)
		ffmpeg -y -loglevel error -i "$OUT/$s.mp4" -map 0:v -c copy "$OUT/$s.v.mp4"
		echo "file '$PWD/$OUT/$s.v.mp4'" >> "$LIST"
	fi
done
ffmpeg -y -loglevel error -f concat -safe 0 -i "$LIST" -map 0:v -c copy "$OUT/ham.mp4"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/ham.mp4")
# müzik: şehir → yaz → gece → kış, video boyunca döner
M=assets/sounds
ffmpeg -y -loglevel error -i $M/music_city.wav -i $M/music_summer.wav -i $M/music_night.wav -i $M/music_winter.wav \
	-filter_complex "[0:a][1:a][2:a][3:a]concat=n=4:v=0:a=1,aresample=48000,aformat=channel_layouts=stereo[m]" -map "[m]" "$OUT/muzik.wav"
FO=$(python3 -c "print(max(0, $DUR - 2.5))")
ffmpeg -y -loglevel error -i "$OUT/ham.mp4" -stream_loop -1 -i "$OUT/muzik.wav" \
	-filter_complex "[1:a]atrim=0:$DUR,afade=t=in:d=1.5,afade=t=out:st=$FO:d=2.5,loudnorm=I=-16[a]" \
	-map 0:v -map "[a]" -vf "scale=1920:1080:flags=lanczos" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart -shortest build/teaser/mycity-teaser-dev.mp4
ls -la build/teaser/mycity-teaser-dev.mp4
echo "süre: $DUR sn"
