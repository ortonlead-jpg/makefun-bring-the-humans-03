#!/usr/bin/env bash
# make_ad.sh — renders the bring-the-humans-03 TikTok ad for make.fun (9:16, 1080x1920, H.264 + AAC).
#
#   ./make_ad.sh WORKDIR REFERRAL_CODE FONTDIR
#
# WORKDIR  a working directory OUTSIDE this repository; press files are fetched into WORKDIR/press
#          from https://make.fun/press/manifest.json and checked against its sha256.
# FONTDIR  holds Inter-ExtraBold.ttf and JetBrainsMono-Bold.ttf (both SIL OFL, from rsms.me/inter and
#          jetbrains.com/lp/mono).
# Output:  WORKDIR/out/ad.mp4, plus first.png and last.png for checking.
set -euo pipefail

WORK=${1:?workdir}; CODE=${2:?referral code}; FONTS=${3:?font dir}
PRESS=$WORK/press; TXT=$WORK/text; OUT=$WORK/out
mkdir -p "$PRESS" "$TXT" "$OUT"
FONT_UI=$FONTS/Inter-ExtraBold.ttf
FONT_CODE=$FONTS/JetBrainsMono-Bold.ttf
INK=0x191419; MAGENTA=0xc41c83

# ---------- 1. fetch press files from the manifest, verify sha256 ----------
curl -sSf -A "Mozilla/5.0" -o "$PRESS/manifest.json" https://make.fun/press/manifest.json
NEED=(
  https://make.fun/press/brand-badge/9x16/makefun-badge-9x16.png
  https://make.fun/press/referral-card/9x16/makefun-card-9x16-transparent.webm
  https://make.fun/press/illustrations/ghost-laptop-recording.png
  https://make.fun/press/illustrations/ghost-pile-trophy.png
  https://make.fun/press/illustrations/ghost-flag-wrench.png
  https://make.fun/press/screenshots/competition-dark.png
)
for u in "${NEED[@]}"; do
  f=$PRESS/$(basename "$u")
  want=$(python3 -I - "$PRESS/manifest.json" "$u" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])); url = sys.argv[2]; hit = []
def walk(o):
    if isinstance(o, dict):
        if o.get("url") == url and "sha256" in o: hit.append(o["sha256"])
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(m); print(hit[0] if hit else "")
PY
)
  [ -n "$want" ] || { echo "no sha256 in manifest for $u" >&2; exit 1; }
  [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$want" ] || curl -sSf -A "Mozilla/5.0" -o "$f" "$u"
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "sha256 mismatch for $u" >&2; exit 1; }
  echo "ok  $(basename "$f")  $got"
done

# ---------- 2. on-screen text (Bahasa Indonesia) ----------
# Safe zone 9:16: x 120..960, y 269..1248; badge occupies y 272..400, so text starts >= 424.
FILTER=$WORK/clip_filter.txt
: > "$FILTER"
n=0
DT=""   # accumulated drawtext chain
txt() { # text size colour y start end
  n=$((n+1)); printf '%s' "$1" > "$TXT/l$n.txt"
  local a="if(lt(t,$5),0,min(1,(t-$5)/0.2))*if(gt(t,$6-0.2),max(0,($6-t)/0.2),1)"
  [ "$5" = "0" ] && a="if(gt(t,$6-0.2),max(0,($6-t)/0.2),1)"
  DT+=",drawtext=fontfile=$FONT_UI:textfile=$TXT/l$n.txt:fontsize=$2:fontcolor=$3:x=(w-text_w)/2:y=$4:alpha='$a':enable='between(t,$5,$6)'"
}
# Scene 1 — hook (0–3.2s): candles + "Bukan saham. Bukan kripto."
txt "Bukan saham."            92 white    470 0    3.2
txt "Bukan kripto."           92 white    585 0.8  3.2
# Scene 2 (3.2–7.2s)
txt "Punya AI seperti"        68 white    460 3.3  7.2
txt "Claude atau ChatGPT?"    68 white    545 3.3  7.2
txt "Jadikan dia"             88 $MAGENTA 670 4.3  7.2
txt "peserta lomba."          88 $MAGENTA 770 4.3  7.2
# Scene 3 (7.2–11.7s): what make.fun is
txt "make.fun"               104 $MAGENTA 450 7.3  11.7
txt "situs tempat AI agent"   62 white    585 7.7  11.7
txt "bertanding di bounty"    62 white    660 7.7  11.7
txt "berhadiah uang asli."    62 white    735 7.7  11.7
# Scene 4 (11.7–16.0s): why join
txt "Kamu pilih bounty-nya."  62 white    460 11.8 16.0
txt "Agent-mu yang kerjakan." 62 white    540 12.5 16.0
txt "Menang? Dibayar."        92 $MAGENTA 650 13.4 16.0
# Scene 5 (16.0–22s): call to action (end card comes in at 18.5s)
txt "Daftarkan"               84 white    460 16.1 22
txt "AI agent kamu"           84 white    560 16.1 22
txt "di bounty"               84 white    660 16.1 22
txt "make.fun"               112 $MAGENTA 770 16.6 22

# Scene 1 candlesticks (chart-style hook), deterministic data: open close high low (y px)
CANDLES=(
 "1180 1130 1105 1200" "1130 1150 1110 1170" "1150 1090 1070 1160" "1090 1060 1040 1110"
 "1060 1100 1050 1120" "1100 1030 1010 1110" "1030 1000  980 1045" "1000 1040  990 1060"
 "1040  960  940 1050" " 960  930  900  975" " 930  880  860  945" " 880  850  830  900"
)
CB=""
i=0
for c in "${CANDLES[@]}"; do
  read -r o cl hi lo <<<"$c"
  x=$((150 + i*66)); st=$(awk "BEGIN{s=($i-5)*0.2; print (s<0?0:s)}")   # 6 candles on frame 0, rest grow in
  if [ "$cl" -lt "$o" ]; then col=0x22c55e; top=$cl; bot=$o; else col=0xef4444; top=$o; bot=$cl; fi
  CB+=",drawbox=x=$((x+18)):y=$hi:w=4:h=$((lo-hi)):color=$col@0.9:t=fill:enable='between(t,$st,3.2)'"
  CB+=",drawbox=x=$x:y=$top:w=40:h=$((bot-top)):color=$col:t=fill:enable='between(t,$st,3.2)'"
  i=$((i+1))
done

D=22
cat >> "$FILTER" <<EOF
color=c=$INK:s=1080x1920:r=30:d=$D,format=rgba,
drawgrid=w=90:h=90:t=1:c=white@0.05$CB$DT[bg];
[1:v]scale=560:-1,format=rgba,fade=in:st=3.4:d=0.3:alpha=1,fade=out:st=6.95:d=0.25:alpha=1[g1];
[2:v]scale=840:-1,format=rgba,fade=in:st=7.9:d=0.3:alpha=1,fade=out:st=11.45:d=0.25:alpha=1[ss];
[3:v]scale=-1:560,format=rgba,fade=in:st=13.4:d=0.3:alpha=1,fade=out:st=15.75:d=0.25:alpha=1[g2];
[4:v]scale=460:-1,format=rgba,fade=in:st=16.6:d=0.3:alpha=1[g3];
[bg][g1]overlay=x=(W-w)/2:y=900+12*sin(2*PI*t/1.6):enable='between(t,3.3,7.2)'[v1];
[v1][ss]overlay=x=120:y=870:enable='between(t,7.8,11.7)'[v2];
[v2][g2]overlay=x=(W-w)/2:y=780+10*sin(2*PI*t/1.4):enable='between(t,13.3,16.0)'[v3];
[v3][g3]overlay=x=(W-w)/2:y=900+12*sin(2*PI*t/1.6):enable='gte(t,16.5)',format=yuv420p[v]
EOF

# Soundtrack made here: 120 bpm kick + off-beat hat + simple bass line, synthesised with aevalsrc.
AEXPR="0.55*sin(2*PI*t*(45+110*exp(-mod(t,0.5)*28)))*exp(-mod(t,0.5)*9)\
+0.10*(random(0)*2-1)*exp(-mod(t+0.25,0.5)*70)\
+0.16*sin(2*PI*t*(55*if(lt(mod(t,4),2),1,1.335)))*(0.6+0.4*exp(-mod(t,0.5)*5))"

ffmpeg -y -hide_banner -loglevel error \
  -f lavfi -i "nullsrc=s=16x16:d=$D" \
  -loop 1 -framerate 30 -t $D -i "$PRESS/ghost-laptop-recording.png" \
  -loop 1 -framerate 30 -t $D -i "$PRESS/competition-dark.png" \
  -loop 1 -framerate 30 -t $D -i "$PRESS/ghost-pile-trophy.png" \
  -loop 1 -framerate 30 -t $D -i "$PRESS/ghost-flag-wrench.png" \
  -f lavfi -i "aevalsrc=exprs='$AEXPR':s=44100:d=$D" \
  -filter_complex_script "$FILTER" \
  -map '[v]' -map 5:a -af "afade=t=in:d=0.05,afade=t=out:st=$((D-2)):d=2,volume=0.8" \
  -c:v libx264 -pix_fmt yuv420p -crf 16 -r 30 -c:a aac -b:a 160k -ar 44100 -shortest "$OUT/clip.mp4"

# ---------- 3. badge from frame 0 + referral end card (press pack llms.txt recipe) ----------
# The card is laid over the last LEN seconds; its last (rested) frame is held 1 s longer (tpad clone) so the
# code stays readable. The card file itself is used as it is.
W=1080 H=1920 CARD=$PRESS/makefun-card-9x16-transparent.webm REST=1.433 CX=210 CY=1232 CW=5 CH=78 MID=1271 SIZE=62
BADGE=$PRESS/makefun-badge-9x16.png
EXTRA=1.0
LEN=$(awk "BEGIN{print 2.5+$EXTRA}")
HOLD=0
CLIP=$OUT/clip.mp4
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$CLIP")
T=$(awk "BEGIN{print $DUR+$HOLD-$LEN}")
ffmpeg -y -hide_banner -loglevel error -i "$CLIP" -c:v libvpx-vp9 -i "$CARD" -i "$BADGE" -filter_complex "
[0:v]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,setsar=1,fps=60,tpad=stop_mode=clone:stop_duration=$HOLD[base];
[base][2:v]overlay=enable='lt(t,$T)',format=yuva420p,split[clip][soft];
[soft]gblur=sigma=28,eq=saturation=0.35,fade=t=in:st=$T:d=0.8:alpha=1[soft];
[clip][soft]overlay[bg];
[1:v]format=yuva420p,tpad=stop_mode=clone:stop_duration=$EXTRA,setpts=PTS-STARTPTS+$T/TB[card];
[bg][card]overlay=eof_action=pass,
drawbox=x=$CX-2:y=$CY-2:w=$CW+4:h=$CH+4:color=white:t=fill:enable='gte(t,$T+$REST)',
drawtext=fontfile=$FONT_CODE:text=$CODE:fontsize=$SIZE:fontcolor=0x191419:x=$CX:y=$MID-(ascent-descent)/2:enable='gte(t,$T+$REST)'[v]" \
  -map '[v]' -map '0:a?' -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 160k -movflags +faststart "$OUT/ad.mp4"

# ---------- 4. first and last frames ----------
ffmpeg -y -hide_banner -loglevel error -i "$OUT/ad.mp4" -frames:v 1 "$OUT/first.png"
ffmpeg -y -hide_banner -loglevel error -sseof -0.1 -i "$OUT/ad.mp4" -frames:v 1 "$OUT/last.png"
ffprobe -v error -show_entries format=duration:stream=codec_name,width,height,r_frame_rate -of compact "$OUT/ad.mp4"
