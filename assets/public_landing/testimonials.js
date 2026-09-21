// Only approved public snapshots cross the bridge. No identity tokens enter this iframe.
(() => {
  const list = document.getElementById('testimonial-list');
  const status = document.getElementById('testimonial-status');
  const button = document.querySelector('[data-testimonial]');
  const embedded = window.parent !== window;
  let state = 'loading';
  function labels() {
    const es = document.documentElement.lang === 'es';
    button.textContent = es ? 'Escribir un testimonio' : 'Escrever depoimento';
    document.getElementById('testimonial-login-note').textContent = es
      ? 'Inicia sesión para enviar tu experiencia. Se publicará después de la moderación.'
      : 'Entre na sua conta para enviar sua experiência. A publicação passa por moderação.';
    const texts = {
      loading: es ? 'Cargando testimonios…' : 'Carregando depoimentos…',
      empty: es ? 'Todavía no hay testimonios publicados.' : 'Ainda não há depoimentos publicados.',
      error: es ? 'No se pudieron cargar los testimonios. Inténtalo de nuevo más tarde.' : 'Não foi possível carregar os depoimentos. Tente novamente mais tarde.',
      preview: es ? 'Los testimonios publicados aparecerán en la aplicación integrada.' : 'Os depoimentos publicados aparecerão no aplicativo integrado.',
      ready: ''
    };
    status.textContent = texts[state];
    document.querySelectorAll('[data-featured-label]').forEach(el => el.textContent = es ? 'Destacado' : 'Destaque');
    const android = document.querySelector('[data-store="android"]');
    if (android) android.setAttribute('aria-label', es ? 'Google Play: enlace no disponible' : 'Google Play: link indisponível');
  }
  const send = type => window.parent.postMessage(JSON.stringify({type, language: document.documentElement.lang}), window.location.origin);
  button.addEventListener('click', () => {
    if (embedded) { send('medcases:testimonial:v1'); }
    else { document.getElementById('registration').showModal(); }
  });
  window.addEventListener('message', event => {
    if (!embedded || event.origin !== window.location.origin || event.source !== window.parent || typeof event.data !== 'string') return;
    let payload; try { payload = JSON.parse(event.data); } catch { return; }
    if (payload.type !== 'medcases:testimonials:v1') return;
    list.replaceChildren();
    if (payload.error) { state = 'error'; labels(); return; }
    const rows = Array.isArray(payload.rows) ? payload.rows.slice(0, 12) : [];
    rows.forEach(row => {
      if (!row || typeof row.text !== 'string' || typeof row.displayName !== 'string') return;
      const card = document.createElement('article'); card.className = 'testimonial-card';
      const header = document.createElement('div'); header.className = 'testimonial-author';
      if (typeof row.photo === 'string' && row.photo.length <= 180000 && /^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/.test(row.photo)) {
        const img = document.createElement('img'); img.src = row.photo; img.alt = ''; img.width = 48; img.height = 48;
        img.addEventListener('error', () => img.remove()); header.append(img);
      }
      const who = document.createElement('div'); const name = document.createElement('h3'); name.textContent = row.displayName;
      const job = document.createElement('p'); job.textContent = typeof row.profession === 'string' ? row.profession : '';
      who.append(name, job); header.append(who); card.append(header);
      const quote = document.createElement('p'); quote.className = 'testimonial-text'; quote.textContent = row.text; card.append(quote);
      if (row.featured === true) { const label = document.createElement('span'); label.dataset.featuredLabel = ''; label.className = 'testimonial-featured'; card.append(label); }
      list.append(card);
    });
    state = list.children.length ? 'ready' : 'empty'; labels();
  });
  new MutationObserver(labels).observe(document.documentElement, {attributes:true, attributeFilter:['lang']});
  if (embedded) send('medcases:testimonials-ready:v1'); else state = 'preview';
  labels();
})();
