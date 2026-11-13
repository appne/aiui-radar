# aiui-radar

"radar" — rain-radar viewer for Rokid Glasses. Shows JMA
high-resolution precipitation nowcast rendered for the green
monochrome display (dark base map, rain as a green brightness
ladder, legend band, frame time baked into the image).

Pipeline: the Muse VM regenerates home/wide views every ~5 min
(hook `radar-refresh`, script ~/workspace/rokid-ios-bridge/radar/
radar_gen.py) and pushes them to the laptop listener, which serves
/radar/home.png, /radar/wide.png and /radar/meta.json on the
tailnet (no token auth on /radar: an <image> cannot send headers,
the content is public JMA data, and the listener binds only to the
Tailscale address). This page fetches meta.json for the frame time
and points the <image> at the matching PNG with ?v=<validtime> as
a cache-buster. Tap cycles 自宅周辺 (z11) <-> 近畿広域 (z9).

Voice launch name: "radar".
Personal use only; do not submit for store review.
