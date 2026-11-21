'use strict';
// Run with: node site/progress.test.js
const assert = require('assert');
const P = require('./progress.js');

const T = [
  { key: 'maths/3/a', subject: 'maths', topic: 'a' },
  { key: 'maths/3/b', subject: 'maths', topic: 'b' },
  { key: 'english/3/c', subject: 'english', topic: 'c' },
];

// parse tolerance
assert.deepStrictEqual(P.parse(null), P.empty());
assert.deepStrictEqual(P.parse(''), P.empty());
assert.deepStrictEqual(P.parse('{nope'), P.empty());
assert.deepStrictEqual(P.parse('[1]'), P.empty());
assert.deepStrictEqual(P.parse('{"v":2,"year":3}'), P.empty());
assert.strictEqual(P.parse('{"v":1,"year":13}').year, null);
assert.strictEqual(P.parse('{"v":1,"year":-1}').year, null);
assert.strictEqual(P.parse('{"v":1,"year":3.5}').year, null);
assert.strictEqual(P.parse('{"v":1,"year":"3"}').year, null);
assert.strictEqual(P.parse('{"v":1,"year":0}').year, 0);
assert.strictEqual(P.parse('{"v":1,"year":12}').year, 12);
let odd = P.parse('{"v":1,"topics":{"a":"known","b":"practising","c":"fresh","d":5},"byGame":{"g":"a","h":3},"last":{"game":7,"topic":"a"}}');
assert.deepStrictEqual(odd.topics, { a: 'known', b: 'practising' });
assert.deepStrictEqual(odd.byGame, { g: 'a' });
assert.deepStrictEqual(odd.last, { topic: 'a' });
assert.deepStrictEqual(P.parse('{"v":1,"topics":[1],"byGame":"x","last":3}'), P.empty());

// round trip, fresh not stored
let s = P.empty();
P.setYear(s, 5);
P.setYear(s, 99); // ignored
s.topics['maths/3/a'] = 'known';
s.topics['maths/3/b'] = 'fresh';
s.byGame.memory_match = 'maths/3/a';
s.last = { game: 'memory_match', topic: 'maths/3/a' };
const enc = P.encode(s);
assert.ok(enc.indexOf('fresh') < 0);
const back = P.parse(enc);
assert.strictEqual(back.year, 5);
assert.deepStrictEqual(back.topics, { 'maths/3/a': 'known' });
assert.deepStrictEqual(back.byGame, { memory_match: 'maths/3/a' });
assert.deepStrictEqual(back.last, { game: 'memory_match', topic: 'maths/3/a' });
assert.strictEqual(P.encode(back), enc);
assert.strictEqual(JSON.parse(P.encode(P.empty())).v, 1);
assert.strictEqual('year' in JSON.parse(P.encode(P.empty())), false);

// another year's progress is kept when the year changes
P.setYear(back, 2);
assert.strictEqual(P.statusOf(back, 'maths/3/a'), 'known');
assert.strictEqual(back.year, 2);

// load and save with a fake storage, and with a broken one
const mem = {};
global.localStorage = { getItem: (k) => (k in mem ? mem[k] : null), setItem: (k, v) => { mem[k] = v; } };
assert.deepStrictEqual(P.load(), P.empty());
assert.strictEqual(P.save(back), true);
assert.strictEqual(P.load().year, 2);
mem['amc.state'] = 'garbage';
assert.deepStrictEqual(P.load(), P.empty());
global.localStorage = { getItem() { throw new Error('blocked'); }, setItem() { throw new Error('blocked'); } };
assert.deepStrictEqual(P.load(), P.empty());
assert.strictEqual(P.save(back), false);
delete global.localStorage;

// statusOf
assert.strictEqual(P.statusOf(s, 'maths/3/a'), 'known');
assert.strictEqual(P.statusOf(s, 'zzz'), 'fresh');

// defaultTopic
let st = P.empty();
assert.strictEqual(P.defaultTopic(T, st, 'g').key, 'maths/3/a');
st.topics['maths/3/a'] = 'known';
assert.strictEqual(P.defaultTopic(T, st, 'g').key, 'maths/3/b');
st.byGame.g = 'english/3/c';
assert.strictEqual(P.defaultTopic(T, st, 'g').key, 'english/3/c');
assert.strictEqual(P.defaultTopic(T, st, 'other').key, 'maths/3/b');
st.topics['english/3/c'] = 'known'; // last topic now known: fall back to the first not known
assert.strictEqual(P.defaultTopic(T, st, 'g').key, 'maths/3/b');
st.byGame.g = 'maths/9/zzz'; // not in this year
assert.strictEqual(P.defaultTopic(T, st, 'g').key, 'maths/3/b');
st.byGame['scout/g'] = 'english/3/c';
st.topics['english/3/c'] = 'practising';
assert.strictEqual(P.defaultTopic(T, st, ['g', 'scout/g']).key, 'english/3/c');
st.topics['maths/3/b'] = 'known'; st.topics['english/3/c'] = 'known';
assert.strictEqual(P.defaultTopic(T, st, 'g'), null);
assert.strictEqual(P.defaultTopic([], st, 'g'), null);

// allKnown
assert.strictEqual(P.allKnown(T, st), true);
st.topics['english/3/c'] = 'practising';
assert.strictEqual(P.allKnown(T, st), false);
assert.strictEqual(P.allKnown([], st), false);

// position
assert.strictEqual(P.position(T, 'maths/3/a'), 'Topic 1 of 3');
assert.strictEqual(P.position(T, 'english/3/c'), 'Topic 3 of 3');
assert.strictEqual(P.position(T, 'nope'), '');
assert.strictEqual(P.position([], 'x'), '');

console.log('progress.test.js: all passed');
