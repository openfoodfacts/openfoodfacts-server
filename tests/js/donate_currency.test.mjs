import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../../html/donate/en.html', import.meta.url), 'utf8');
const scriptMatch = html.match(/<script>\s*(\/\/ Donorbox contract[\s\S]*?)<\/script>/);
assert.ok(scriptMatch, 'donate v2 script block must exist in html/donate/en.html');
const donateScript = scriptMatch[1];

const SAMPLE_COUNTRIES = {
    'en:france': {
        country_code_2: {en: 'FR'},
        currency_codes: {en: 'EUR'},
    },
    'en:united-kingdom': {
        country_code_2: {en: 'UK'},
        official_country_code_2: {en: 'GB'},
        currency_codes: {en: 'GBP'},
    },
    'en:united-states': {
        country_code_2: {en: 'US'},
        currency_codes: {en: 'USD'},
    },
    'en:canada': {
        country_code_2: {en: 'CA'},
        currency_codes: {en: 'CAD'},
    },
    'en:panama': {
        country_code_2: {en: 'PA'},
        currency_codes: {en: 'PAB,USD'},
    },
};

function makeElement(attrs = {}, textContent = '') {
    const listeners = {};
    const attributes = {...attrs};
    return {
        hidden: false,
        textContent,
        value: '',
        style: {},
        classList: {toggle() {}},
        children: [],
        getAttribute(name) {
            return attributes[name] ?? null;
        },
        setAttribute(name, val) {
            attributes[name] = String(val);
        },
        addEventListener(type, fn) {
            listeners[type] = listeners[type] || [];
            listeners[type].push(fn);
        },
        dispatch(type) {
            for (const fn of listeners[type] || []) {
                fn({currentTarget: this});
            }
        },
        appendChild(child) {
            this.children.push(child);
            return child;
        },
        querySelector() {
            return null;
        },
        _attributes: attributes,
    };
}

async function runDonateV2({hostname = 'world.openfoodfacts.org', campaignData, countries = SAMPLE_COUNTRIES, fetchFails = false}) {
    const nextTextNode = {nodeType: 3, nodeValue: 'Next'};
    const nextButton = {firstChild: nextTextNode};
    const shadowRoot = {
        children: [],
        appendChild(el) {
            this.children.push(el);
        },
        querySelector(sel) {
            return sel === '#standard_checkout_section button' ? nextButton : null;
        },
    };
    const widget = makeElement();
    widget.shadowRoot = shadowRoot;
    widget.campaignData = campaignData;

    const slot = makeElement();
    const toggleButtons = [
        makeElement({'data-interval': '1 M'}),
        makeElement({'data-interval': '1 Y'}),
        makeElement({'data-interval': '1 T'}),
    ];
    const tierButtons = [
        makeElement({'data-amount': '3'}),
        makeElement({'data-amount': '5'}),
        makeElement({'data-amount': '10'}),
        makeElement({'data-amount': '20'}),
    ];
    const otherInput = makeElement();
    const otherMinNote = makeElement({}, 'Minimum {amount}');
    const currencyChip = makeElement({}, 'EUR');
    const payLabel = makeElement();
    const payTplEls = [
        makeElement({'data-interval': '1 M'}, 'Pay {amount} a month with'),
        makeElement({'data-interval': '1 Y'}, 'Pay {amount} a year with'),
        makeElement({'data-interval': '1 T'}, 'Pay {amount} with'),
    ];
    const nextTemplates = {
        eur: makeElement({'data-currency': 'eur'}, 'Continue with card, PayPal, iDEAL or Wero'),
        usd: makeElement({'data-currency': 'usd'}, 'Continue with card or PayPal'),
    };
    const hideAskButton = makeElement();
    const hideAskNote = makeElement();

    const v1 = {
        hidden: false,
        querySelector(sel) {
            return sel === 'dbox-widget' ? widget : null;
        },
    };
    const v2 = {
        hidden: true,
        querySelector(sel) {
            if (sel === '.donate-slot') return slot;
            if (sel === '.donate-other-input') return otherInput;
            if (sel === '.donate-other-min') return otherMinNote;
            if (sel === '.donate-cur') return currencyChip;
            if (sel === '.donate-pay-label') return payLabel;
            if (sel === '.donate-hide-ask') return hideAskButton;
            if (sel === '.donate-hide-ask-note') return hideAskNote;
            const m = sel.match(/^\.donate-next-tpl\[data-currency="([^"]+)"\]$/);
            if (m) return nextTemplates[m[1]] || null;
            return null;
        },
        querySelectorAll(sel) {
            if (sel === '.donate-iv-btn') return toggleButtons;
            if (sel === '.donate-tier') return tierButtons;
            if (sel === '.donate-pay-tpl') return payTplEls;
            return [];
        },
    };

    const sessionStorage = {};
    const sandbox = {
        Math: Object.assign(Object.create(Math), {random: () => 0.1}),
        URLSearchParams,
        Intl,
        Promise,
        Number,
        Object,
        String,
        Date,
        isFinite,
        setTimeout: () => 1,
        clearTimeout: () => {},
        MutationObserver: class {
            observe() {}
        },
        location: {
            hostname,
            origin: `https://${hostname}`,
            pathname: '/donate',
            search: '',
            hash: '',
        },
        history: {replaceState() {}},
        sessionStorage,
        window: {},
        document: {
            cookie: '',
            getElementById(id) {
                if (id === 'donate-v1') return v1;
                if (id === 'donate-v2') return v2;
                return null;
            },
            createElement() {
                return makeElement();
            },
        },
        fetch(url) {
            assert.equal(url, '/data/taxonomies/countries.json');
            if (fetchFails) {
                return Promise.reject(new Error('network error'));
            }
            return Promise.resolve({
                ok: true,
                json: () => Promise.resolve(countries),
            });
        },
    };

    vm.runInNewContext(donateScript, sandbox, {filename: 'html/donate/en.html'});
    widget.dispatch('dbox:campaign-loaded');
    await new Promise((resolve) => setImmediate(resolve));

    return {
        widget,
        currencyChip,
        payLabel,
        otherMinNote,
        nextTextNode,
        sessionStorage,
    };
}

test('subdomain uk.openfoodfacts.org resolves GBP from countries.json when supported', async () => {
    const res = await runDonateV2({
        hostname: 'uk.openfoodfacts.org',
        campaignData: {
            current_country: 'FR',
            min_currencies_values: {eur: 1, usd: 1, gbp: 2},
        },
    });
    assert.equal(res.widget.getAttribute('currency'), 'gbp');
    assert.equal(res.currencyChip.textContent, 'GBP');
    assert.equal(res.payLabel.textContent, 'Pay £5 a month with');
    assert.equal(res.otherMinNote.textContent, 'Minimum £2');
    assert.equal(res.nextTextNode.nodeValue, 'Continue with card or PayPal');
});

test('world subdomain uses Donorbox current_country and matches official_country_code_2 (GB -> GBP)', async () => {
    const res = await runDonateV2({
        hostname: 'world.openfoodfacts.org',
        campaignData: {
            current_country: 'GB',
            min_currencies_values: {eur: 1, usd: 1, gbp: 1},
        },
    });
    assert.equal(res.widget.getAttribute('currency'), 'gbp');
    assert.equal(res.currencyChip.textContent, 'GBP');
});

test('dual-currency country selects first currency supported by Donorbox (PA -> PAB,USD -> usd)', async () => {
    const res = await runDonateV2({
        hostname: 'world.openfoodfacts.org',
        campaignData: {
            current_country: 'PA',
            min_currencies_values: {eur: 1, usd: 1},
        },
    });
    assert.equal(res.widget.getAttribute('currency'), 'usd');
    assert.equal(res.payLabel.textContent, 'Pay $5 a month with');
});

test('unsupported mapped currency falls back to Donorbox-supported currency', async () => {
    const res = await runDonateV2({
        hostname: 'world.openfoodfacts.org',
        campaignData: {
            current_country: 'GB',
            min_currencies_values: {eur: 1, usd: 1},
        },
    });
    assert.equal(res.widget.getAttribute('currency'), 'eur');
    assert.equal(res.payLabel.textContent, 'Pay €5 a month with');
    assert.equal(res.nextTextNode.nodeValue, 'Continue with card, PayPal, iDEAL or Wero');
});

test('country-language subdomain (fr-en) resolves country currency (EUR)', async () => {
    const res = await runDonateV2({
        hostname: 'fr-en.openfoodfacts.org',
        campaignData: {
            current_country: 'US',
            min_currencies_values: {eur: 1, usd: 1},
        },
    });
    assert.equal(res.widget.getAttribute('currency'), 'eur');
    assert.equal(res.currencyChip.textContent, 'EUR');
});

test('countries.json fetch failure gracefully falls back to AMERICAS heuristic', async () => {
    const res = await runDonateV2({
        hostname: 'world.openfoodfacts.org',
        campaignData: {
            current_country: 'US',
            min_currencies_values: {eur: 1, usd: 1},
        },
        fetchFails: true,
    });
    assert.equal(res.widget.getAttribute('currency'), 'usd');
    assert.equal(res.payLabel.textContent, 'Pay $5 a month with');
});
