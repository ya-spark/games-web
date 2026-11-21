/* Progress saved on this device (W6). ONE JSON blob in localStorage key 'amc.state', the same schema the Flutter
   side reads and writes (overlay/common/lib/web_product/web_state_model.dart). Keep the two in step:
   {"v":1,"year":3,"topics":{"maths/3/money":"known"|"practising"},"last":{"game":"..","topic":".."},"byGame":{"<game id>":"<topic key>"}}
   Plain script: exposes window.AMCProgress, and module.exports when `module` exists (node tests). No dependencies. */
(function (root) {
  'use strict';
  var KEY = 'amc.state', VERSION = 1;

  function empty() { return { v: VERSION, year: null, topics: {}, last: null, byGame: {} }; }
  function isObj(x) { return x !== null && typeof x === 'object' && !Array.isArray(x); }
  function validYear(y) { return typeof y === 'number' && isFinite(y) && Math.floor(y) === y && y >= 0 && y <= 12; }

  /* Tolerant parse: bad JSON, a wrong version or odd values give an empty state (or drop the odd value), never throw. */
  function parse(raw) {
    var s = empty();
    if (typeof raw !== 'string' || raw === '') return s;
    var j;
    try { j = JSON.parse(raw); } catch (e) { return empty(); }
    if (!isObj(j) || j.v !== VERSION) return empty();
    if (validYear(j.year)) s.year = j.year;
    if (isObj(j.topics)) {
      Object.keys(j.topics).forEach(function (k) {
        var v = j.topics[k];
        if (v === 'known' || v === 'practising') s.topics[k] = v;
      });
    }
    if (isObj(j.byGame)) {
      Object.keys(j.byGame).forEach(function (k) { if (typeof j.byGame[k] === 'string') s.byGame[k] = j.byGame[k]; });
    }
    if (isObj(j.last)) {
      var l = {};
      if (typeof j.last.game === 'string') l.game = j.last.game;
      if (typeof j.last.topic === 'string') l.topic = j.last.topic;
      if (l.game !== undefined || l.topic !== undefined) s.last = l;
    }
    return s;
  }

  /* 'fresh' topics are not stored; year and last are left out when unset. */
  function encode(state) {
    var s = state || empty(), out = { v: VERSION };
    if (validYear(s.year)) out.year = s.year;
    out.topics = {};
    Object.keys(s.topics || {}).forEach(function (k) {
      var v = s.topics[k];
      if (v === 'known' || v === 'practising') out.topics[k] = v;
    });
    if (isObj(s.last) && (typeof s.last.game === 'string' || typeof s.last.topic === 'string')) {
      out.last = {};
      if (typeof s.last.game === 'string') out.last.game = s.last.game;
      if (typeof s.last.topic === 'string') out.last.topic = s.last.topic;
    }
    out.byGame = {};
    Object.keys(s.byGame || {}).forEach(function (k) { if (typeof s.byGame[k] === 'string') out.byGame[k] = s.byGame[k]; });
    return JSON.stringify(out);
  }

  function store() { try { return root.localStorage || null; } catch (e) { return null; } }

  function load() {
    try { var st = store(); return parse(st ? st.getItem(KEY) : null); } catch (e) { return empty(); }
  }
  function save(state) {
    try { var st = store(); if (!st) return false; st.setItem(KEY, encode(state)); return true; } catch (e) { return false; }
  }
  /* Sets the active year (any year, higher or lower); progress of other years is kept. Returns the state. */
  function setYear(state, year) {
    if (validYear(year)) state.year = year;
    return state;
  }
  function statusOf(state, key) {
    var v = state && state.topics ? state.topics[key] : null;
    return v === 'known' || v === 'practising' ? v : 'fresh';
  }
  function keyOf(t) { return typeof t === 'string' ? t : (t && t.key) || ''; }

  /* gameIds may be one id or a list of ids to try in order (for example the plain id, then slug/id). */
  function defaultTopic(topicsOfYear, state, gameIds) {
    var list = Array.isArray(topicsOfYear) ? topicsOfYear : [];
    var ids = Array.isArray(gameIds) ? gameIds : (gameIds ? [gameIds] : []);
    for (var i = 0; i < ids.length; i++) {
      var mine = state && state.byGame ? state.byGame[ids[i]] : null;
      if (typeof mine !== 'string') continue;
      for (var j = 0; j < list.length; j++) {
        if (keyOf(list[j]) === mine) { if (statusOf(state, mine) !== 'known') return list[j]; break; }
      }
    }
    for (var k = 0; k < list.length; k++) if (statusOf(state, keyOf(list[k])) !== 'known') return list[k];
    return null;
  }
  function allKnown(topicsOfYear, state) {
    var list = Array.isArray(topicsOfYear) ? topicsOfYear : [];
    if (!list.length) return false;
    return list.every(function (t) { return statusOf(state, keyOf(t)) === 'known'; });
  }
  /* 'Topic 3 of 12', or '' when the key is not in the list. */
  function position(topicsOfYear, key) {
    var list = Array.isArray(topicsOfYear) ? topicsOfYear : [];
    for (var i = 0; i < list.length; i++) if (keyOf(list[i]) === key) return 'Topic ' + (i + 1) + ' of ' + list.length;
    return '';
  }

  var api = {
    KEY: KEY, empty: empty, parse: parse, encode: encode, load: load, save: save, setYear: setYear,
    statusOf: statusOf, defaultTopic: defaultTopic, allKnown: allKnown, position: position, validYear: validYear
  };
  root.AMCProgress = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : (typeof globalThis !== 'undefined' ? globalThis : this));
