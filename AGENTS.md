# aiui-radar

"radar" — rain-radar viewer for Rokid Glasses. Shows JMA
high-resolution precipitation nowcast rendered for the green
monochrome display (dark base map, rain as a green brightness
ladder, legend band, frame time baked into the image).

Builds: rdr-b1 = home pipeline viewer. rdr-b2 was a server-side
step only (forecast frames). rdr-b3 = swipe steps frame time
(+5/+10/+30/+60), and on open the page geolocates, POSTs
/radar/request, and polls meta-here.json until frames centred on
the current location are ready. rdr-b4 = generation is on demand:
on open the page also POSTs a bare /radar/request and repaints
when the refreshed home frame lands. rdr-b5 = staged display:
at open the page shows the base map only (base_<view>.png —
static per centre+zoom); scale taps swap the base at once, time
swipes are remembered, and the rendered frame replaces the map
when ready (home: meta answered_at; here: base-meta-here.json
lands first, then meta-here.json). rdr-b6 = hint line above the
image. rdr-b7 = tap lockout (700 ms after a confirmed tap —
one physical tap had been advancing twice), zooms reworked
(z9 regional view dropped; both modes are near z12 / wide z11
with the local label set only), and the fixed set is centred
on KYOTO STATION instead of home (screenshots must not give
away the home location; view keys stay home/wide). rdr-b8 =
BACK key reloads: back is the first stage of the OS exit
gesture but reaches the app first, so the page consumes it
(Backspace/Escape/BrowserBack/Back/GoBack or keyCode 4/27)
and re-runs the full open sequence (reset to the fixed set
at the current frame, fresh request, geolocation, polling).
rdr-b9 = back twice to exit: b8 ate every back press and the
agent became unclosable (device report); now a second press
within 3 s of a reload is NOT consumed and passes through to
the OS exit sequence.
rdr-b10 = never blank the picture during an update (user
request 2026-11-14): applyView remembers the last painted
rain frame (_lastFrameSrc); while a mode is not ready, a
session that has painted a frame keeps showing it (status
（更新中…）) and swaps exactly once when the fresh frame is
ready. The base-map stage remains only for a cold open.
Server-side the same day: the base-map luminance budget was
compressed from G<=64 to G<=32 (linear x0.5, water pinned to
G2: landuse shades 2/10/14/16/20/24 in landuse.json, prefecture
rings G23, roads G27/31 in RadarGen) at the user's pick from
rendered samples; labels and the centre marker stay bright.
Also server-side the same night: JMA hrpns tiles exist only
up to z10 (z11/z12 return transparent tiles), so RadarGen now
fetches at z10 and upscales (nearest-neighbour) — before this
fix no real rain was ever rendered; and the centre marker +
place labels are drawn AGAIN over the rain (View.drawMarks)
so echoes cannot erase them.
rdr-b11 = a third here-mode view, detail (現在地・詳細): the
current location at 1.5x the near zoom — server-side a z12
View with scale 1.5 (base_detail.png, detail[_pN].png). The
here tap cycle is here -> widehere -> detail -> here. The
home (fixed) cycle stays two views.
rdr-b12 = BACK right after an interaction exits (user
request 2026-11-16): taps (fireTap) and swipes stamp
_lastInteractAt, and the BACK branch passes through when
pressed within 3 s of the last tap/swipe as well as within
3 s of the last reload — so swipe/tap then BACK leaves at
once instead of reloading first. Zaisen got the same
change as zai-b40.
Frame layout since 2026-11-15 (server-side only, no page
change): the image is still 448x286, but the map is now
404x286 (full height) and the legend is a VERTICAL column
in the right 44 px (strongest class at top, mm/h numbers
inside the blocks) — the old 36 px bottom band is gone.
Rain compositing is ADDITIVE since then: pixel = terrain G
(0..32) + rain value, clamped at 255, so the terrain stays
visible under a full rain cover (user design, from rendered
samples). The rain ladder was 80 + strength*140 (G80..220)
until 2026-11-15 evening, when the floor was lowered to
40 + strength*180 (G40..220, top unchanged) at the user's
request so light rain sits dimmer; the legend swatches use
the same formula. Backup: GlassesChatServer.java.bak-20261115-pre-g40. Land-use
meshes are built ON DEMAND per primary mesh (Kyoto asset
stays prebuilt): RadarGen.ensureLanduse downloads the
L03-b GML zip from MLIT and caches landuse-<code>.json in
the radar dir (~1.4 MB per mesh). Label rendering note:
drawMarks draws each label's outline in pure black (G0)
at the 8 neighbouring offsets, AFTER the rain composite,
so production frames keep a G0 outline over any rain.
Offline sample generators must lift the outline into the
marks mask too (dilate the core-colour mask), or the
composite dissolves the outline into the rain colour and
the labels look unreadable on bright fields — a sample
bug, not a production one (hit 2026-11-15, kensho b27
samples v1; fixed in v2 by dilating 2 px, which reads
slightly heavier than production's 1 px outline).
Place labels are no longer Kyoto-only (2026-11-15):
besides the curated LABELS_HOME (prio 0-2), drawMarks
merges AUTOMATIC labels from labels_auto.tsv in the
radar dir (22,428 entries, 0.86 MB; built by
radar/data/make_labels_auto.py from KSJ N02-25 stations
— same-name features chain-merged within ~500 m pooling
lines; prio 3 = Shinkansen or >=3 lines, 4 = 2 lines,
6 = 1 line — and KSJ P12-14 tourism points, prio 5,
MultiPoint centroid anchors, name-filtered: >12 chars or
containing 株式会社/有限会社/一般公開/まつり are dropped).
Auto candidates are pre-sorted by distance from the
view centre (the stable prio sort keeps that order
within a tier), dropped within ~350 m of a curated
label, capped at 10 drawn per view, and skipped when
the name fits on neither side of its dot. P12 coverage
is uneven by prefecture (Niigata ~2k resources, Aichi
6) — that is the published data, not a bug. Server
76,6xx B (backups …bak-20261115-pre-autolabels and
…-autolabels-v1); verified server-side on Tokyo
Station (major stations), Amanohashidate (tourism)
and the Kyoto home view (curated intact, no dupes).
Collision clearance and scenic quota (2026-11-15
night, user-approved after three samples): text-vs-
text clearance is 5 px (was 2 px — too dense at 15
labels); every dot-involved test stays exact-overlap.
A full 15 px margin was sampled and rejected: it
thinned even the curated Kyoto set. After the main
pass, if fewer than 5 tourism labels (prio 5) were
drawn, a guarantee pass retries the missed ones in
distance order with text placements (R,0) (L,0)
(R,-14) (L,-14) (R,+14) (L,+14) — side flips and
vertical TEXT shifts only, the dot stays true — until
5 are drawn; these draws ignore the 10-slot cap, so a
frame can carry 15 auto labels. Placement lives in
View.placeLabel, shared by both passes. Server
78,766 B (backup …bak-20261115-pre-poiquota);
production-verified on Tokyo (10 stations + 5 scenic:
上野動物園・東京国立近代美術館・隅田川橋梁群・東京タワー
ほか), Kyoto home (16 labels, curated intact) and
Amanohashidate (all-scenic frame).
Event-name filter (2026-11-16, user request): P12
also registers EVENTS as tourism points (祇園祭,
fireworks shows, marathons) - not place names, so
the builder's name filter now also drops names
containing 祭・花火・大会・フェスティバル・マラソン・
駅伝・カーニバル・盆踊り・イベント・博覧会・コンテスト・
グランプリ・コンサート, plus an exact-name denylist
(ＫＡＲＡ−１ = the KARA-1グランプリ spicy-food contest
in Muko, truncated in P12 so no pattern catches it).
ライブ is NOT a pattern (would kill ドライブウェイ /
ドライブイン). Shrine festivals drop too (events;
the shrines themselves stay). Applied by post-
filtering the TSV: 22,428 -> 20,986 rows (tourism
13,399 -> 11,957); builder carries the same rules
for rebuilds. Verified on the Kyoto home base:
KARA-1 gone, 向日市天文館 appears in its area,
curated set intact. Backups: labels_auto.tsv
.bak-20261116-pre-eventfilter (VM + laptop).
After b7: base maps also draw major roads (Natural Earth 10m Japan
extract — expressways + main national routes, 103 KB
roads.geojson served from the listener's radar dir; made by
radar/data/make_roads.py; server-side only, no page change).

Pipeline: generation lives INSIDE the laptop listener
(GlassesChatServer's RadarGen, a Java port of radar_gen.py).
Nothing runs periodically: opening the agent POSTs /radar/request
(with {lat,lon} when a fix is available, bare otherwise); the
listener watches radar-requests.jsonl every 2 s and generates —
the home set when its stored frame is stale, the here set for a
new fix (10 min / ~1 km cache). The listener serves /radar/*.png
and /radar/meta(-here).json on the tailnet (no token auth on GET
/radar: an <image> cannot send headers, the content is public JMA
data, and the listener binds only to the Tailscale address).
This page fetches meta.json for the frame time and points the
<image> at the matching PNG with ?v=<validtime> as a cache-buster.
Tap cycles 京都駅周辺 (z12) <-> 京都駅・広域 (z11) in the fixed
mode, 現在地 (z12) <-> 現在地・広域 (z11) in here mode. The old VM hooks
(radar-refresh, radar-on-demand) were disabled 2026-11-13;
radar_gen.py remains as a backup implementation.

Voice launch name: "radar".
Personal use only; do not submit for store review.
