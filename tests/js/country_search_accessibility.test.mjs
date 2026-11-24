import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../../html/js/display.js', import.meta.url), 'utf8');

function countrySelector(label) {
    const handlers = {};
    const attributes = {};
    const search = {attr(values) {Object.assign(attributes, values);}};
    let instance = {dropdown: {$search: search}};
    const selector = {
        select2() {return this;},
        on(event, handler) {handlers[event] = handler; return this;},
        data() {return instance;},
        attr(name) {
            assert.equal(name, 'data-search-placeholder');
            return label;
        }
    };
    const window = {addEventListener() {}, location: {hostname: 'localhost'}};
    const document = {querySelector() {return {dataset: {serverdomain: 'example.org'}};}};
    function $(value) {
        if (typeof value === 'function') {
            value();
            return;
        }
        assert.ok(value === '#select_country' || value === selector,
            'initialization and handlers only access the country selector');
        return selector;
    }
    vm.runInNewContext(source, {$, window, document}, {filename: 'display.js'});
    return {
        attributes,
        open() {handlers['select2:open'].call(selector);},
        setInstance(value) {instance = value;}
    };
}

test('country search uses the translated hint as its visible and accessible label', () => {
    const country = countrySelector('Buscar un país…');
    country.open();
    assert.equal(country.attributes.placeholder, 'Buscar un país…');
    assert.equal(country.attributes['aria-label'], 'Buscar un país…');
});

test('reopening applies the label to a replacement search field', () => {
    const country = countrySelector("Search for a country's name…");
    country.open();
    const replacement = {};
    country.setInstance({dropdown: {$search: {attr(values) {Object.assign(replacement, values);}}}});
    country.open();
    assert.equal(replacement.placeholder, "Search for a country's name…");
    assert.equal(replacement['aria-label'], replacement.placeholder);
});

test('opening remains safe when Select2 has no dropdown search field', () => {
    const country = countrySelector('Search for a country…');
    for (const instance of [undefined, {}, {dropdown: {}}]) {
        country.setInstance(instance);
        assert.doesNotThrow(() => country.open());
    }
    assert.deepEqual(country.attributes, {});
});
