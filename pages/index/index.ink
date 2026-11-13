<script def>
{
  "navigationBarTitleText": "Radar"
}
</script>

<script setup>
// rdr-b1: dedicated rain-radar agent (built 2026-11-13, after the
// kensho vrf-b22..b24 spikes proved remote <image> rendering).
// Layout follows the b24 device findings: status line ABOVE the
// image, nothing essential below it (the visible area is the
// framebuffer's central band). The image is served by the laptop
// listener at a stable tailnet URL; meta.json gives the frame's
// valid time, appended as ?v= so the <image> reloads exactly when
// a new frame lands. Tap (temple GlobalHook arm + Enter confirm,
// the proven b16 model) or a bare Enter cycles the view.
export default {
  data: {
    build: 'rdr-b1',
    status: '読込中…',
    imgSrc: '',
    hint: 'タップ: 自宅周辺 ⇔ 近畿広域'
  },
  _base: 'http://100.124.235.107:18765/radar/',
  _views: [
    { key: 'home', label: '自宅周辺' },
    { key: 'wide', label: '近畿広域' }
  ],
  _view: 0,
  _vt: '',
  _tapTimer: null,
  onLoad() {
    this.refresh(true);
  },
  refresh(first) {
    try {
      wx.request({
        url: this._base + 'meta.json',
        success: (res) => {
          const m = (res && res.data) || {};
          if (m.validtime) this._vt = String(m.validtime);
          this.applyView(m.display || '');
        },
        fail: () => {
          if (first) this.setData({ status: '接続できません（Tailscale確認）' });
          this.applyView('');
        }
      });
    } catch (e) {
      this.setData({ status: '接続エラー' });
    }
  },
  applyView(display) {
    const v = this._views[this._view];
    const q = this._vt ? ('?v=' + this._vt) : '';
    this.setData({
      imgSrc: this._base + v.key + '.png' + q,
      status: v.label + (display ? '  ' + display + ' の雨雲' : '')
    });
  },
  cycle() {
    this._view = (this._view + 1) % this._views.length;
    this.refresh(false);
  },
  onKeyUp(event) {
    const code = event && event.code;
    if (code === 'GlobalHook') {
      event.preventDefault();
      if (this._tapTimer) {
        // Second hook inside the window: treat as the same tap.
        return;
      }
      this._tapTimer = setTimeout(() => {
        this._tapTimer = null;
        this.cycle();
      }, 300);
      return;
    }
    if (code === 'Enter') {
      event.preventDefault();
      if (this._tapTimer) { clearTimeout(this._tapTimer); this._tapTimer = null; }
      this.cycle();
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
