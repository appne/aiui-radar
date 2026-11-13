<script def>
{
  "navigationBarTitleText": "Radar"
}
</script>

<script setup>
// rdr-b4: dedicated rain-radar agent (2026-11-13).
// Generation is ON DEMAND inside the laptop listener (RadarGen):
// nothing is rendered periodically. On open the page POSTs a bare
// /radar/request to trigger a home-set refresh (the listener
// regenerates only when its stored frame is stale), and polls
// meta.json to repaint when the fresh frame lands.
// - Home mode: frames centred on home; views home (z11) / wide (z9).
// - Here mode: the page reads navigator.geolocation, POSTs
//   {lat,lon} to the listener (/radar/request), and polls
//   meta-here.json until the listener has rendered frames centred
//   on the current location; views here / widehere.
//   Falls back to home mode when geolocation or generation fails.
// - Gestures (temple model from kensho b16): tap (GlobalHook arm +
//   Enter confirm, or a bare Enter) cycles the view; swipe
//   (ArrowUp/ArrowDown) steps the frame time through the nowcast
//   forecasts +5/+10/+30/+60 min and back.
// Layout follows the kensho b24 device findings: status above the
// image, nothing essential below it.
export default {
  data: {
    build: 'rdr-b4',
    status: '読込中…',
    imgSrc: '',
    hint: 'タップ: 画面切替 / スワイプ: 時刻'
  },
  _base: 'http://100.124.235.107:18765/radar/',
  _token: 'gchat-4c1d9a72',
  _modes: {
    home: { meta: 'meta.json', views: [
      { key: 'home', label: '自宅周辺' },
      { key: 'wide', label: '近畿広域' } ] },
    here: { meta: 'meta-here.json', views: [
      { key: 'here', label: '現在地' },
      { key: 'widehere', label: '現在地・広域' } ] }
  },
  _mode: 'home',
  _view: 0,
  _fIdx: 0,
  _frames: [{ off: 0, vt: '', display: '' }],
  _tapTimer: null,
  _pollTimer: null,
  _pollLeft: 0,
  _hereReqAt: 0,
  _hereLat: null,
  _hereLon: null,
  pollMs: 3000,
  onLoad() {
    this.loadMeta('home', () => this.applyView());
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
  // Repaint the home view when the listener's on-demand refresh
  // lands a newer frame; keeps the current swipe offset.
  pollHomeFresh() {
    let left = 40;
    const step = () => {
      if (left-- <= 0) return;
      this.loadMeta('home', (m) => {
        if (this._mode === 'home' && m && Array.isArray(m.frames) && m.frames.length
            && m.frames[0].vt !== (this._homeVt || '')) {
          this._homeVt = m.frames[0].vt;
          this.applyView();
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
          this.pollHere();
        },
        () => this.hereFailed(),
        { timeout: 15000 }
      );
    } catch (e) { this.hereFailed(); }
  },
  hereFailed() {
    this.setData({ hint: '現在地が取れませんでした（自宅を表示）' });
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
            this._fIdx = 0;
            this._frames = m.frames;
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
  onKeyUp(event) {
    const code = event && event.code;
    if (code === 'GlobalHook') {
      event.preventDefault();
      if (this._tapTimer) return;
      this._tapTimer = setTimeout(() => { this._tapTimer = null; this.cycleView(); }, 300);
      return;
    }
    if (code === 'Enter') {
      event.preventDefault();
      if (this._tapTimer) { clearTimeout(this._tapTimer); this._tapTimer = null; }
      this.cycleView();
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
    <image class="radar" src="{{ imgSrc }}"></image>
    <text class="line hint">{{ hint }}</text>
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
