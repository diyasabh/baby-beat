/* Baby Beat design-rationale layer.
   Same primitive as the Atlas flows: handwritten margin notes, each anchored to
   the exact decision it explains, appearing per screen. The difference is that
   Baby Beat is a native app, so anchors are points on a captured screen rather
   than live DOM nodes.
   Toggle: the "Design notes" switch, or the `n` key. */
(function () {
  'use strict';

  var on = true, layer, svg, items = [], REDUCED = false;
  /* the page may ask for a screen's notes before the layer exists, so the
     last request is always kept and replayed once boot() has run */
  var pending = null;
  try { REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) {}

  function hash(s) { var h = 0; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return Math.abs(h); }
  function f1(n) { return Math.round(n * 10) / 10; }

  /* hand-drawn curved arrow with a two-stroke head, seeded so each note bends
     its own way and the page never looks mechanically ruled */
  function wpath(sx, sy, ex, ey, seed) {
    var dx = ex - sx, dy = ey - sy, L = Math.max(1, Math.hypot(dx, dy));
    var px = -dy / L, py = dx / L;
    var k = Math.min(30, L * 0.2) * ((seed % 2) ? 1 : -1);
    var c1x = sx + dx * 0.3 + px * k, c1y = sy + dy * 0.3 + py * k;
    var c2x = sx + dx * 0.72 + px * k * 0.35, c2y = sy + dy * 0.72 + py * k * 0.35;
    var ang = Math.atan2(ey - c2y, ex - c2x), h = 8.5, a1 = ang + 2.6, a2 = ang - 2.6;
    return 'M' + f1(sx) + ' ' + f1(sy) +
      ' C' + f1(c1x) + ' ' + f1(c1y) + ' ' + f1(c2x) + ' ' + f1(c2y) + ' ' + f1(ex) + ' ' + f1(ey) +
      ' M' + f1(ex) + ' ' + f1(ey) + ' L' + f1(ex + Math.cos(a1) * h) + ' ' + f1(ey + Math.sin(a1) * h) +
      ' M' + f1(ex) + ' ' + f1(ey) + ' L' + f1(ex + Math.cos(a2) * h) + ' ' + f1(ey + Math.sin(a2) * h);
  }

  function boot() {
    var pre = document.createElement('link');
    pre.rel = 'preconnect'; pre.href = 'https://fonts.gstatic.com'; pre.crossOrigin = '';
    document.head.appendChild(pre);
    var fl = document.createElement('link');
    fl.rel = 'stylesheet';
    fl.href = 'https://fonts.googleapis.com/css2?family=Caveat:wght@400;600&display=swap';
    document.head.appendChild(fl);

    var st = document.createElement('style');
    st.textContent =
      '#bbNotesLayer{position:fixed;inset:0;pointer-events:none;z-index:2147481000}' +
      '#bbNotesLayer svg{position:absolute;inset:0;width:100%;height:100%;overflow:visible;display:block}' +
      '.bb-note{position:absolute;font-family:"Caveat",cursive;font-size:19.5px;line-height:1.28;color:#45403A;' +
        'letter-spacing:.01em;transform:rotate(var(--nrot,0deg));opacity:0;translate:0 8px;' +
        'transition:opacity .4s ease,translate .45s cubic-bezier(.32,.72,0,1)}' +
      '.bb-note.in{opacity:1;translate:0 0}' +
      '.bb-note.dim{opacity:0 !important}' +
      '.bb-note b{font-weight:600;color:#2E7E44;text-decoration:underline;text-decoration-style:wavy;' +
        'text-decoration-color:rgba(46,126,68,.35);text-decoration-thickness:1px;text-underline-offset:4px}' +
      '.bb-arrow{fill:none;stroke:#57514A;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round;' +
        'opacity:.72;transition:opacity .3s}' +
      '.bb-arrow.dim{opacity:0}';
    document.head.appendChild(st);

    layer = document.createElement('div');
    layer.id = 'bbNotesLayer';
    svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    layer.appendChild(svg);
    document.body.appendChild(layer);
    addEventListener('resize', schedule);
    addEventListener('scroll', schedule, true);
    if (pending) show(pending);
  }

  var posReq = 0;
  function schedule() { if (posReq) return; posReq = requestAnimationFrame(function () { posReq = 0; position(); }); }

  /* mount the notes for one screen. `notes` is [{a:[px,py], side, w, t}] where
     a is a point in the phone image's own coordinate space (0..1). */
  function show(notes) {
    pending = notes || [];
    items.forEach(function (it) {
      it.el.classList.remove('in');
      (function (el, pa) { setTimeout(function () { el.remove(); pa.remove(); }, 240); })(it.el, it.path);
    });
    items = [];
    if (!layer) return;
    (notes || []).forEach(function (n, i) {
      var el = document.createElement('div');
      el.className = 'bb-note';
      el.innerHTML = n.t;
      el.style.setProperty('--nrot', (((hash(n.t) % 50) / 10) - 2.5).toFixed(1) + 'deg');
      layer.insertBefore(el, svg);
      var p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      p.setAttribute('class', 'bb-arrow');
      svg.appendChild(p);
      items.push({ n: n, el: el, path: p });
    });
    position(true);
    items.forEach(function (it, k) {
      setTimeout(function () { it.el.classList.add('in'); drawIn(it); }, 90 + k * 110);
    });
  }

  function drawIn(it) {
    if (REDUCED) return;
    try {
      var L = it.path.getTotalLength();
      it.path.style.transition = 'none';
      it.path.style.strokeDasharray = L + ' ' + L;
      it.path.style.strokeDashoffset = L;
      void it.path.getBoundingClientRect();
      it.path.style.transition = 'stroke-dashoffset .55s ease .05s';
      it.path.style.strokeDashoffset = '0';
      setTimeout(function () {
        it.path.style.transition = ''; it.path.style.strokeDasharray = ''; it.path.style.strokeDashoffset = '';
      }, 720);
    } catch (e) {}
  }

  function dim(it, v) { it.el.classList.toggle('dim', v); it.path.classList.toggle('dim', v); }

  function position() {
    if (!layer) return;
    var phone = document.querySelector('.phone');
    if (!on || !phone) { items.forEach(function (it) { dim(it, true); }); return; }
    var ph = phone.getBoundingClientRect();
    if (ph.width < 10) { items.forEach(function (it) { dim(it, true); }); return; }
    /* below this width the margins cannot hold a note without covering the
       screen it is explaining, so they step aside entirely */
    if (innerWidth < 1180) { items.forEach(function (it) { dim(it, true); }); return; }

    var placed = { l: [], r: [] };
    items.forEach(function (it) {
      var n = it.n, GAP = 54, w = n.w || 236, x;
      var ax = ph.left + ph.width * n.a[0], ay = ph.top + ph.height * n.a[1];
      if (n.side === 'l') {
        x = ph.left - GAP - w;
        if (x < 16) { w = ph.left - GAP - 16; x = 16; }
      } else {
        x = ph.right + GAP;
        w = Math.min(w, innerWidth - x - 16);
      }
      if (w < 120) { dim(it, true); return; }
      it.el.style.width = w + 'px';
      var oh = it.el.offsetHeight;
      var y = Math.max(74, Math.min(innerHeight - oh - 18, ay - oh * 0.45));
      dim(it, false);
      it.geo = { x: x, y: y, w: w, h: oh, ax: ax, ay: ay };
      placed[n.side === 'l' ? 'l' : 'r'].push(it);
    });

    /* resolve vertical collisions per margin, then pull back inside the window */
    ['l', 'r'].forEach(function (side) {
      var col = placed[side].sort(function (a, b) { return a.geo.y - b.geo.y; });
      for (var i = 1; i < col.length; i++) {
        var prev = col[i - 1].geo, cur = col[i].geo;
        if (cur.y < prev.y + prev.h + 18) cur.y = prev.y + prev.h + 18;
      }
      for (var j = col.length - 1; j >= 0; j--) {
        var g = col[j].geo, maxY = (j < col.length - 1) ? col[j + 1].geo.y - g.h - 18 : innerHeight - g.h - 18;
        if (g.y > maxY) g.y = Math.max(74, maxY);
      }
    });

    items.forEach(function (it) {
      if (!it.geo || it.el.classList.contains('dim')) return;
      var g = it.geo;
      it.el.style.left = g.x + 'px';
      it.el.style.top = g.y + 'px';
      var sx = (it.n.side === 'l') ? g.x + g.w + 9 : g.x - 9;
      var sy = g.y + Math.max(11, Math.min(g.h - 9, g.ay - g.y));
      it.path.setAttribute('d', wpath(sx, sy, g.ax, g.ay, hash(it.n.t)));
    });
  }

  function setOn(v) { on = v; if (layer) layer.style.display = v ? '' : 'none'; if (v) position(); }

  addEventListener('keydown', function (e) {
    if (e.key !== 'n' || e.metaKey || e.ctrlKey || e.altKey) return;
    var t = e.target;
    if (t && (t.isContentEditable || /input|textarea/i.test(t.tagName || ''))) return;
    window.BBNotes.setOn(!on);
    document.dispatchEvent(new CustomEvent('bbnotes', { detail: on }));
  });

  window.BBNotes = { show: show, position: position, setOn: setOn, isOn: function () { return on; } };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
