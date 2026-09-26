// <noop-gauge charge="56" wake="92"> — the Charge tick ring at true size, for the redline sheet.
// 41 ticks, span 250°, start -125°, ring radius 142, marker at 131. Mirrors NoopChargeGauge.swift.
(function () {
  const RAMP = [[0, 47, 178, 240], [0.5, 224, 138, 155], [0.78, 242, 180, 92], [1, 240, 116, 44]];

  function levelColor(charge) {
    const h = Math.min(Math.max((58 - charge) / 40, 0), 1);
    if (h < 0.03) return '#17A2E6';
    let i = RAMP.findIndex(s => s[0] >= h);
    if (i <= 0) i = 1;
    const a = RAMP[i - 1], b = RAMP[i];
    const t = (h - a[0]) / (b[0] - a[0]);
    const c = n => Math.round(a[n] + (b[n] - a[n]) * t);
    return `rgb(${c(1)},${c(2)},${c(3)})`;
  }

  class NoopGauge extends HTMLElement {
    connectedCallback() { this.render(); }
    static get observedAttributes() { return ['charge', 'wake']; }
    attributeChangedCallback() { if (this.isConnected) this.render(); }

    render() {
      const charge = parseFloat(this.getAttribute('charge') || '56');
      const wake = parseFloat(this.getAttribute('wake') || '92');
      const colour = levelColor(charge);
      const lit = Math.round(charge / 100 * 40);
      const ghost = Math.round(wake / 100 * 40);
      const COUNT = 41, SPAN = 250, START = -125;

      let ticks = '';
      for (let i = 0; i < COUNT; i++) {
        const angle = START + SPAN * i / (COUNT - 1);
        const tall = i % 5 === 0;
        const isLit = i <= lit;
        const isGhost = !isLit && i <= ghost;
        const op = lit > 0 ? Math.min(0.32 + 0.68 * (i / Math.max(lit, 1)), 1) : 0.32;
        const bg = isLit ? colour : isGhost ? 'rgba(159,226,251,.28)' : 'rgba(255,255,255,.13)';
        ticks += `<div style="position:absolute;left:50%;top:50%;width:2px;height:${tall ? 15 : 9}px;`
          + `margin:-${(tall ? 15 : 9) / 2}px 0 0 -1px;border-radius:2px;background:${bg};`
          + `opacity:${isLit ? op : 1};transform:rotate(${angle}deg) translateY(-142px)"></div>`;
      }

      const markerAngle = START + SPAN * lit / (COUNT - 1);
      const marker = `<div style="position:absolute;left:50%;top:50%;width:0;height:0;margin:-4.5px 0 0 -6px;`
        + `border-left:6px solid transparent;border-right:6px solid transparent;border-bottom:9px solid #EDF1EF;`
        + `filter:drop-shadow(0 0 6px rgba(0,0,0,.5));transform:rotate(${markerAngle}deg) translateY(-131px)"></div>`;

      const orb = `<div style="position:absolute;left:50%;top:50%;width:176px;height:176px;margin:-88px 0 0 -88px;`
        + `border-radius:50%;background:radial-gradient(circle at 38% 32%,#9FE2FB,#2FB2F0 55%,#0A5F92);`
        + `box-shadow:0 18px 52px rgba(11,111,168,.55),inset 0 -8px 24px rgba(4,42,66,.5);`
        + `display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px">`
        + `<span style="font-family:'Outfit',sans-serif;font-size:52px;font-weight:200;letter-spacing:-1.56px;`
        + `color:#F6FDFF;text-shadow:0 2px 16px rgba(4,30,48,.55);font-variant-numeric:tabular-nums;line-height:1">64</span>`
        + `<span style="font-family:'Instrument Sans',system-ui,sans-serif;font-size:12.5px;font-weight:600;`
        + `letter-spacing:1.375px;text-transform:uppercase;color:rgba(246,253,255,.82)">Hold</span></div>`;

      const ring = `<div style="position:absolute;left:50%;top:50%;width:224px;height:224px;margin:-112px 0 0 -112px;`
        + `border-radius:50%;border:1px solid rgba(159,226,251,.5)"></div>`;

      this.innerHTML = `<div style="position:relative;width:306px;height:318px">`
        + `<div style="position:absolute;left:0;top:6px;width:306px;height:306px">${ticks}${marker}${ring}${orb}</div>`
        + `</div>`;
    }
  }

  if (!customElements.get('noop-gauge')) customElements.define('noop-gauge', NoopGauge);
})();
