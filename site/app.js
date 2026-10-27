'use strict';
(() => {
  const cards = [...document.querySelectorAll('.feature-card')];
  if (!cards.length) return;
  const ar = document.documentElement.lang === 'ar';
  const filters = [...document.querySelectorAll('[data-filter]')];
  const search = document.querySelector('#feature-search');
  const more = document.querySelector('#show-more');
  const count = document.querySelector('.result-count');
  const empty = document.querySelector('.empty-state');
  const dialog = document.querySelector('#feature-dialog');
  let category = 'all', expanded = false, matches = cards, activeIndex = 0;
  let previousFocus = null;
  function update() {
    const query = search.value.trim().toLocaleLowerCase();
    matches = cards.filter(card => (category === 'all' || card.dataset.category === category) && card.dataset.title.toLocaleLowerCase().includes(query));
    const limit = expanded || category !== 'all' || query ? matches.length : 8;
    const visible = new Set(matches.slice(0, limit));
    cards.forEach(card => { card.hidden = !visible.has(card); });
    filters.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.filter === category)));
    more.hidden = matches.length <= limit;
    empty.hidden = matches.length !== 0;
    count.textContent = ar ? `${visible.size} من ${matches.length} ميزة` : `${visible.size} of ${matches.length} features`;
  }
  filters.forEach(button => button.addEventListener('click', () => { category = button.dataset.filter; expanded = false; update(); }));
  search.addEventListener('input', update);
  more.addEventListener('click', () => { expanded = true; update(); });
  function show(index) {
    if (!matches.length) return;
    activeIndex = (index + matches.length) % matches.length;
    const card = matches[activeIndex];
    const image = card.querySelector('img');
    const enlarged = document.querySelector('#dialog-image');
    enlarged.src = image.src; enlarged.alt = image.alt;
    document.querySelector('#dialog-original').href = image.src;
    document.querySelector('#dialog-title').textContent = card.querySelector('h3').textContent;
    document.querySelector('#dialog-description').textContent = card.querySelector('.feature-copy > p').textContent;
    document.querySelector('#dialog-note').textContent = card.querySelector('.feature-note').textContent;
    document.querySelector('#dialog-position').textContent = `${activeIndex + 1} / ${matches.length}`;
  }
  document.querySelectorAll('[data-open]').forEach(button => button.addEventListener('click', () => {
    previousFocus = button;
    show(matches.findIndex(card => card.id === button.dataset.open));
    dialog.showModal(); document.body.style.overflow = 'hidden';
    document.querySelector('#dialog-close').focus();
  }));
  document.querySelector('#dialog-close').addEventListener('click', () => dialog.close());
  document.querySelector('#dialog-prev').addEventListener('click', () => show(activeIndex - 1));
  document.querySelector('#dialog-next').addEventListener('click', () => show(activeIndex + 1));
  dialog.addEventListener('click', event => { if (event.target === dialog) { const r = dialog.getBoundingClientRect(); if(event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close(); } });
  dialog.addEventListener('close', () => { document.body.style.overflow = ''; previousFocus?.focus(); });
  dialog.addEventListener('keydown', event => { if(event.key === 'ArrowRight') { event.preventDefault(); show(activeIndex + (ar ? -1 : 1)); } if(event.key === 'ArrowLeft') { event.preventDefault(); show(activeIndex + (ar ? 1 : -1)); } });
  function revealHash() {
    const target = cards.find(card => '#' + card.id === window.location.hash);
    if (!target) return;
    category = 'all'; expanded = true; search.value = ''; update(); target.scrollIntoView({block:'start'});
  }
  update(); revealHash(); window.addEventListener('hashchange', revealHash);
})();
