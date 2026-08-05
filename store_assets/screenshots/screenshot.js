// Builds one store screenshot frame from ?screen=<slug>&platform=<key>.
// The artboard is always 1080 units wide; it is scaled to the target canvas so
// a single design serves every store size.

(function () {
  const params = new URLSearchParams(location.search);
  const slug = params.get('screen') || window.PPS_SCREENS[0].slug;
  const platformKey = params.get('platform') || 'ios69';

  const spec = window.PPS_SCREENS.find((s) => s.slug === slug);
  const platform = window.PPS_PLATFORMS[platformKey];
  if (!spec) throw new Error('unknown screen: ' + slug);
  if (!platform) throw new Error('unknown platform: ' + platformKey);

  const ART_W = 1080;
  const scale = platform.w / ART_W;
  const artHeight = platform.h / scale;

  // One green phrase per headline, named explicitly by the spec so the accent
  // always lands on the payoff rather than on whatever word happens to be last.
  const headlineHtml = accentuate(spec.headline, spec.accent);

  const rawPath = `raw/${platform.raw}/${spec.slug}.png`;

  const stage = el('div', 'stage');
  stage.style.width = platform.w + 'px';
  stage.style.height = platform.h + 'px';

  // A 16:9 canvas leaves much less room above the device than a 19.5:9 one.
  const art = el('div', 'art' + (platform.w / platform.h > 0.53 ? ' short' : ''));
  art.style.width = ART_W + 'px';
  art.style.height = artHeight + 'px';
  art.style.transform = `scale(${scale})`;

  art.appendChild(marks(ART_W, artHeight));
  art.appendChild(el('div', 'bloom'));

  const header = document.createElement('header');
  header.innerHTML = `<h1>${headlineHtml}</h1>` +
    (spec.sub ? `<p class="sub">${escapeHtml(spec.sub)}</p>` : '');
  art.appendChild(header);

  const wrap = el('div', 'device-wrap');
  const device = el('div', 'device');
  if (platform.device) device.style.width = platform.device + 'px';
  const img = document.createElement('img');
  img.src = rawPath;
  img.alt = spec.screen;
  img.onerror = () => device.replaceChildren(placeholder(spec, rawPath));
  device.appendChild(img);
  wrap.appendChild(device);
  art.appendChild(wrap);

  stage.appendChild(art);
  document.body.appendChild(stage);
  document.title = `${spec.slug} · ${platform.label}`;

  function placeholder(spec, path) {
    const box = el('div', 'placeholder');
    box.innerHTML =
      '<div class="tag">capture missing</div>' +
      `<div class="what">${escapeHtml(spec.screen)}</div>` +
      `<div class="state">${escapeHtml(spec.state)}</div>` +
      `<div class="path">${escapeHtml(path)}</div>`;
    return box;
  }

  // The icon's own language, faint: registration marks at the artboard corners
  // and a measuring rule under the headline.
  function marks(w, h) {
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('class', 'marks');
    svg.setAttribute('viewBox', `0 0 ${w} ${h}`);
    svg.setAttribute('preserveAspectRatio', 'none');

    const inset = 46;
    const arm = 96;
    [
      [inset, inset, 1, 1],
      [w - inset, inset, -1, 1],
      [inset, h - inset, 1, -1],
      [w - inset, h - inset, -1, -1],
    ].forEach(([x, y, sx, sy]) => {
      const p = document.createElementNS(ns, 'path');
      p.setAttribute('d', `M ${x + sx * arm} ${y} L ${x} ${y} L ${x} ${y + sy * arm}`);
      p.setAttribute('fill', 'none');
      p.setAttribute('stroke', '#7fb0ff');
      p.setAttribute('stroke-opacity', '0.16');
      p.setAttribute('stroke-width', '6');
      p.setAttribute('stroke-linecap', 'round');
      p.setAttribute('stroke-linejoin', 'round');
      svg.appendChild(p);
    });

    const ruleY = h * 0.955;
    for (let i = 0, x = 120; x < w - 100; x += 30, i++) {
      const long = i % 4 === 0;
      const p = document.createElementNS(ns, 'path');
      p.setAttribute('d', `M ${x} ${ruleY - (long ? 18 : 10)} L ${x} ${ruleY}`);
      p.setAttribute('stroke', '#7fb0ff');
      p.setAttribute('stroke-opacity', long ? '0.22' : '0.12');
      p.setAttribute('stroke-width', '3');
      p.setAttribute('stroke-linecap', 'round');
      svg.appendChild(p);
    }
    return svg;
  }

  function accentuate(headline, accent) {
    const at = accent ? headline.indexOf(accent) : -1;
    if (at < 0) {
      if (accent) console.warn(`accent "${accent}" is not in "${headline}"`);
      return escapeHtml(headline);
    }
    return (
      escapeHtml(headline.slice(0, at)) +
      '<em>' +
      escapeHtml(accent) +
      '</em>' +
      escapeHtml(headline.slice(at + accent.length))
    );
  }

  function el(tag, className) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    return node;
  }

  function escapeHtml(s) {
    return String(s).replace(
      /[&<>"']/g,
      (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
    );
  }
})();
