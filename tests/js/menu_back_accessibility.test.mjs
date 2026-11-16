import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const template = readFileSync(new URL('../../templates/web/common/site_layout.tt.html', import.meta.url), 'utf8');
const script = template.match(/\\\$\(document\)\.foundation\(\{[\s\S]*?\\\$\('\.top-bar \.back h5 > a'\)[^\n]*/)?.[0];

test('existing and newly initialized menu links use the same localized visible and accessible label', () => {
    assert.ok(script, 'menu initialization exists');
    for (const initialText of ['Back', null]) {
        const link = {textContent: initialText, ariaLabel: null};
        const label = "Retour à l'accueil";
        const rendered = script.replaceAll('\\$', '$').replaceAll('[% esq(lang("menu_back")) %]', "Retour à l\\'accueil");
        const document = {};
        const selection = {
            text(value) {link.textContent = value; return this;},
            attr(name, value) {assert.equal(name, 'aria-label'); link.ariaLabel = value; return this;}
        };
        function $(selector) {
            if (selector === document) return {foundation() {if (link.textContent === null) link.textContent = label;}};
            assert.equal(selector, '.top-bar .back h5 > a');
            return selection;
        }
        vm.runInNewContext(rendered, {$, document});
        assert.equal(link.textContent, label);
        assert.equal(link.ariaLabel, label);
    }
});
