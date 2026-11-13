<script def>
{
  "navigationBarTitleText": "Radar"
}
</script>

<script setup>
// rdr-b7: dedicated rain-radar agent (2026-11-13).
// Changes from b6 (user device feedback):
// - Tap lockout: one physical temple tap could advance the view
//   TWICE (an extra GlobalHook after the Enter confirm armed a
//   second tap). After a confirmed tap, further tap gestures are
//   ignored for 700 ms.
// - Zooms: the z9 regional view is gone. Both modes are now
//   near z12 / wide z11 (the old z11 "current" range is the new
//   wide; near is a 2x zoom of it). Labels are the local set at
//   both zooms (off-frame ones clip, thinning the near view).
// - The fixed set is centred on KYOTO STATION, not home — the
//   startup map must not give away the home location in
//   screenshots. (View keys stay home/wide for file compat.)
// Layout: hint line moved ABOVE the image (user device report:
// text below the image falls outside the visible band).
// Generation is ON DEMAND inside the laptop listener (RadarGen):
// nothing is rendered periodically. On open the page POSTs a bare
// /radar/request to trigger a home-set refresh (the listener
// regenerates only when its stored frame is stale).
// Staged display (user design): at open, show the base MAP only
// for the current view — the map itself never changes, so it is
// served as its own file (base_<view>.png). Scale taps swap the
// base immediately; time swipes are remembered as the wanted
// offset. When the rendered frame is ready (meta answered_at /
// validtime change), the display switches to the rain image at
// the remembered view + offset. The here mode stages the same
// way: base-meta-here.json lands first (map), meta-here.json
// second (rain).
// - Home mode: frames centred on Kyoto Station; views home
//   (z12, 京都駅周辺) / wide (z11, 京都駅・広域).
// - Here mode: the page reads navigator.geolocation, POSTs
//   {lat,lon} to the listener (/radar/request), and polls
//   meta-here.json until the listener has rendered frames centred
//   on the current location; views here (z12) / widehere (z11).
//   Falls back to home mode when geolocation or generation fails.
// - Gestures (temple model from kensho b16 + b7 lockout): tap
//   (GlobalHook arm + Enter confirm, or a bare Enter) cycles the
//   view; swipe (ArrowUp/ArrowDown) steps the frame time through
//   the nowcast forecasts +5/+10/+30/+60 min and back.
// Layout follows the kensho b24 device findings: status above the
// image, nothing essential below it.
export default {
  data: {
    build: 'rdr-b7',
    status: '読込中…',
    imgSrc: '',
    hint: 'タップ: 画面切替 / スワイプ: 時刻'
  },
  _base: 'http://100.124.235.107:18765/radar/',
  _token: 'gchat-4c1d9a72',
  _modes: {
    home: { meta: 'meta.json', views: [
      { key: 'home', label: '京都駅周辺' },
      { key: 'wide', label: '京都駅・広域' } ] },
    here: { meta: 'meta-here.json', views: [
      { key: 'here', label: '現在地' },
      { key: 'widehere', label: '現在地・広域' } ] }
  },
  _mode: 'home',
  _view: 0,
  _fIdx: 0,
  _frames: [{ off: 0, vt: '', display: '' }],
  _tapTimer: null,
  _tapLockUntil: 0,
  _pollTimer: null,
  _pollLeft: 0,
  _hereReqAt: 0,
  _hereLat: null,
  _hereLon: null,
  _openAt: 0,
  _paintedVt: '',
  _homeReady: false,
  _hereReady: false,
  _hereBaseReady: false,
  _basesAt: 0,
  _baseLeft: 0,
  pollMs: 3000,
  onLoad() {
    this._openAt = Math.floor(Date.now() / 1000);
    this.loadMeta('home', (m) => {
      if (m && Array.isArray(m.frames) && m.frames.length) this._paintedVt = m.frames[0].vt;
      this.applyView();
    });
    this.postOpenPing();
    this.pollHomeFresh();
    this.startHere();
  },
  postOpenPing() {
    try {
      wx.request({
        url: this._base + 'request',
        method: 'POST',
        header: { 'X-Talk-Token': this._token, 'content-type': 'application/json' },
        data: {},
        success: () => {},
        fail: () => {}
      });
    } catch (e) {}
  },
  // The home frame counts as ready when the listener has answered
  // this open (answered_at) or a newer frame has landed; after ~2
  // min of silence, fall back to the stored (stale) frames.
  pollHomeFresh() {
    let left = 40;
    const step = () => {
      if (this._homeReady) return;
      if (left-- <= 0) {
        this._homeReady = true;
        if (this._mode === 'home') this.applyView();
        return;
      }
      this.loadMeta('home', (m) => {
        const answered = m && typeof m.answered_at === 'number' && m.answered_at >= this._openAt - 5;
        const newer = m && Array.isArray(m.frames) && m.frames.length
          && this._paintedVt && m.frames[0].vt !== this._paintedVt;
        if (answered || newer) {
          this._homeReady = true;
          if (this._mode === 'home') this.applyView();
          return;
        }
        this._homeTimer = setTimeout(step, this.pollMs);
      });
    };
    this._homeTimer = setTimeout(step, this.pollMs);
  },
  loadMeta(mode, cb) {
    try {
      wx.request({
        url: this._base + this._modes[mode].meta,
        success: (res) => {
          const m = (res && res.data) || {};
          if (Array.isArray(m.frames) && m.frames.length) {
            if (mode === this._mode) {
              this._frames = m.frames;
              if (this._fIdx >= this._frames.length) this._fIdx = this._frames.length - 1;
            }
          }
          if (cb) cb(m);
        },
        fail: () => { if (cb) cb(null); }
      });
    } catch (e) { if (cb) cb(null); }
  },
  startHere() {
    let geo = null;
    try { geo = (typeof navigator !== 'undefined') ? navigator.geolocation : null; } catch (e) { geo = null; }
    if (!geo || !geo.getCurrentPosition) return;
    this.setData({ hint: '現在地を取得中…' });
    try {
      geo.getCurrentPosition(
        (pos) => {
          const c = (pos && pos.coords) || {};
          if (typeof c.latitude !== 'number' || typeof c.longitude !== 'number') { this.hereFailed(); return; }
          this._hereLat = c.latitude; this._hereLon = c.longitude;
          this._hereReqAt = Math.floor(Date.now() / 1000);
          this.setData({ hint: '現在地レーダーを作成中…' });
          try {
            wx.request({
              url: this._base + 'request',
              method: 'POST',
              header: { 'X-Talk-Token': this._token, 'content-type': 'application/json' },
              data: { lat: this._hereLat, lon: this._hereLon },
              success: () => {},
              fail: () => {}
            });
          } catch (e) {}
          this._pollLeft = 40;
          this._baseLeft = 40;
          this.pollHereBase();
          this.pollHere();
        },
        () => this.hereFailed(),
        { timeout: 15000 }
      );
    } catch (e) { this.hereFailed(); }
  },
  hereFailed() {
    this.setData({ hint: '現在地が取れませんでした（京都駅を表示）' });
  },
  // Stage 1 of here mode: the listener writes base maps + this
  // meta before rendering frames; switch to the current-location
  // MAP as soon as it matches this request.
  pollHereBase() {
    if (this._mode === 'here' || this._baseLeft <= 0) return;
    this._baseLeft--;
    try {
      wx.request({
        url: this._base + 'base-meta-here.json',
        success: (res) => {
          const m = (res && res.data) || {};
          const ctr = Array.isArray(m.centre) ? m.centre : null;
          const fresh = typeof m.bases_at === 'number' && m.bases_at >= this._hereReqAt - 660;
          const near = ctr && Math.abs(ctr[0] - this._hereLat) + Math.abs(ctr[1] - this._hereLon) <= 0.02;
          if (ctr && fresh && near) {
            this._mode = 'here';
            this._view = 0;
            this._hereBaseReady = true;
            this._basesAt = m.bases_at;
            this.applyView();
            return;
          }
          this._baseTimer = setTimeout(() => this.pollHereBase(), this.pollMs);
        },
        fail: () => { this._baseTimer = setTimeout(() => this.pollHereBase(), this.pollMs); }
      });
    } catch (e) {
      this._baseTimer = setTimeout(() => this.pollHereBase(), this.pollMs);
    }
  },
  pollHere() {
    if (this._pollLeft <= 0) {
      this.setData({ hint: '現在地レーダーが間に合いませんでした' });
      return;
    }
    this._pollLeft--;
    try {
      wx.request({
        url: this._base + 'meta-here.json',
        success: (res) => {
          const m = (res && res.data) || {};
          const ctr = Array.isArray(m.centre) ? m.centre : null;
          const fresh = typeof m.generated_at === 'number' && m.generated_at >= this._hereReqAt - 660;
          const near = ctr && Math.abs(ctr[0] - this._hereLat) + Math.abs(ctr[1] - this._hereLon) <= 0.02;
          if (ctr && fresh && near && Array.isArray(m.frames) && m.frames.length) {
            this._mode = 'here';
            this._view = 0;
            if (this._fIdx >= m.frames.length) this._fIdx = 0;
            this._frames = m.frames;
            this._hereReady = true;
            this.setData({ hint: 'タップ: 画面切替 / スワイプ: 時刻' });
            this.applyView();
            return;
          }
          this._pollTimer = setTimeout(() => this.pollHere(), this.pollMs);
        },
        fail: () => { this._pollTimer = setTimeout(() => this.pollHere(), this.pollMs); }
      });
    } catch (e) {
      this._pollTimer = setTimeout(() => this.pollHere(), this.pollMs);
    }
  },
  applyView() {
    const views = this._modes[this._mode].views;
    const v = views[this._view % views.length];
    const f = this._frames[this._fIdx] || this._frames[0];
    const ready = this._mode === 'home' ? this._homeReady : this._hereReady;
    if (!ready) {
      // Map-only stage: the base map for the current view. Scale
      // taps and time swipes already took effect on _view/_fIdx
      // and will apply to the frame when it lands.
      const bust = this._mode === 'here' && this._basesAt ? ('?v=' + this._basesAt) : '';
      this.setData({
        imgSrc: this._base + 'base_' + v.key + '.png' + bust,
        status: v.label + ' の地図（作成中…）'
      });
      return;
    }
    const suffix = f.off ? ('_p' + f.off) : '';
    const q = f.vt ? ('?v=' + f.vt) : '';
    this.setData({
      imgSrc: this._base + v.key + suffix + '.png' + q,
      status: v.label + '  ' + (f.off ? ('+' + f.off + '分予測 ' + f.display) : (f.display + ' の雨雲'))
    });
  },
  cycleView() {
    const views = this._modes[this._mode].views;
    this._view = (this._view + 1) % views.length;
    this.applyView();
  },
  stepTime(dir) {
    const n = this._fIdx + dir;
    if (n < 0 || n >= this._frames.length) return;
    this._fIdx = n;
    this.applyView();
  },
  // One physical tap must cycle exactly once. The temple sends
  // GlobalHook then the gesture key; an extra GlobalHook can
  // trail the Enter, and without a lockout it armed a second tap
  // (device report 2026-11-13: wide -> wide). After a confirmed
  // tap, ignore tap gestures for 700 ms.
  fireTap() {
    this._tapLockUntil = Date.now() + 700;
    this.cycleView();
  },
  onKeyUp(event) {
    const code = event && event.code;
    if (code === 'GlobalHook') {
      event.preventDefault();
      if (Date.now() < this._tapLockUntil) return;
      if (this._tapTimer) return;
      this._tapTimer = setTimeout(() => { this._tapTimer = null; this.fireTap(); }, 300);
      return;
    }
    if (code === 'Enter') {
      event.preventDefault();
      if (Date.now() < this._tapLockUntil) return;
      if (this._tapTimer) { clearTimeout(this._tapTimer); this._tapTimer = null; }
      this.fireTap();
      return;
    }
    if (code === 'ArrowUp' || code === 'ArrowDown') {
      event.preventDefault();
      if (this._tapTimer) { clearTimeout(this._tapTimer); this._tapTimer = null; }
      // Temple swipes: forward (ArrowUp) = later, back = earlier.
      this.stepTime(code === 'ArrowUp' ? 1 : -1);
    }
  }
}
</script>

<page>
  <view class="container">
    <text class="title">Radar {{ build }}</text>
    <text class="line sub">{{ status }}</text>
    <text class="line hint">{{ hint }}</text>
    <image class="radar" src="{{ imgSrc }}"></image>
  </view>
</page>

<style>
.container {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: flex-start;
  height: 100vh;
  padding: 10px;
}

.title {
  color: #40FF5E;
  font-size: 13px;
  line-height: 16px;
  margin-bottom: 4px;
}

.line {
  color: #40FF5E;
  font-size: 22px;
  line-height: 26px;
}

.sub {
  color: #40FF5E99;
  font-size: 18px;
  line-height: 22px;
}

.hint {
  color: #40FF5E99;
  font-size: 13px;
  line-height: 16px;
}

.radar {
  width: 448px;
  height: 286px;
  margin: 4px 0;
}

</style>
