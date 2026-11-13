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
away the home location; view keys stay home/wide).

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
