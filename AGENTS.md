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
when the refreshed home frame lands.

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
Tap cycles 自宅周辺 (z11) <-> 近畿広域 (z9). The old VM hooks
(radar-refresh, radar-on-demand) were disabled 2026-11-13;
radar_gen.py remains as a backup implementation.

Voice launch name: "radar".
Personal use only; do not submit for store review.
