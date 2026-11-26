import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const searchJs = readFileSync(new URL('../../html/js/search.js', import.meta.url), 'utf8');
const searchTemplate = readFileSync(
    new URL('../../templates/web/pages/search_form/search_form.tt.html', import.meta.url),
    'utf8',
);

function makeField(attrs = {}, val = '') {
    const attributes = {...attrs};
    let currentVal = val;
    return {
        attr(name, value) {
            if (arguments.length === 1) {
                return attributes[name];
            }
            attributes[name] = String(value);
            return this;
        },
        val(value) {
            if (arguments.length === 0) {
                return currentVal;
            }
            currentVal = String(value);
            return this;
        },
        focus() {
            this.focused = true;
            return this;
        },
        clone() {
            return makeField({...attributes}, currentVal);
        },
    };
}

function makeCriterionRow(index) {
    const typeSelect = makeField({name: `tagtype_${index}`, id: `tagtype_${index}`}, 'brands');
    const containsSelect = makeField({name: `tag_contains_${index}`, id: `tag_contains_${index}`}, 'contains');
    const tagInput = makeField({name: `tag_${index}`, id: `tag_${index}`}, '');

    return {
        typeSelect,
        containsSelect,
        tagInput,
        find(selector) {
            if (selector === 'select') {
                return {
                    eq(i) {
                        return i === 0 ? typeSelect : containsSelect;
                    },
                };
            }
            if (selector === 'input') {
                return tagInput;
            }
            return null;
        },
        clone() {
            const clonedType = typeSelect.clone();
            const clonedContains = containsSelect.clone();
            const clonedInput = tagInput.clone();
            return {
                typeSelect: clonedType,
                containsSelect: clonedContains,
                tagInput: clonedInput,
                find(selector) {
                    if (selector === 'select') {
                        return {
                            eq(i) {
                                return i === 0 ? clonedType : clonedContains;
                            },
                        };
                    }
                    if (selector === 'input') {
                        return clonedInput;
                    }
                    return null;
                },
            };
        },
    };
}

function setupSearchSandbox({largeUp = true} = {}) {
    const rows = [makeCriterionRow(0), makeCriterionRow(1)];
    const handlers = {};
    const parentContainer = {
        append(row) {
            rows.push(row);
        },
    };

    function jQuery(selector) {
        if (selector === documentObj) {
            return {
                on(event, targetSelector, fn) {
                    handlers[`${event}:${targetSelector}`] = fn;
                },
            };
        }
        if (selector === '.criterion-row') {
            return {
                first() {
                    return {
                        parent() {
                            return parentContainer;
                        },
                        clone() {
                            return rows[0].clone();
                        },
                    };
                },
            };
        }
        if (selector === '.criterion-row:nth-last-of-type(2) select:first') {
            return rows[rows.length - 2].typeSelect;
        }
        if (selector === '.criterion-row:last select:first') {
            return rows[rows.length - 1].typeSelect;
        }
        return {
            show() {},
            hide() {},
            val() {
                return '';
            },
            autocomplete() {},
        };
    }
    jQuery.map = (arr, fn) => arr.map(fn);

    const documentObj = {};
    const sandbox = {
        document: documentObj,
        jQuery,
        $: jQuery,
        folksonomy_url: 'https://folksonomy.openfoodfacts.org',
        Foundation: {
            utils: {
                is_large_up: () => largeUp,
            },
        },
        fetch() {
            return Promise.resolve({
                json: () => Promise.resolve([]),
            });
        },
        parseInt,
    };

    vm.runInNewContext(searchJs, sandbox, {filename: 'html/js/search.js'});

    const changeHandler = handlers['change:.criterion-row:last .tag-search-criterion > input'];

    return {
        rows,
        triggerLastCriterionChange() {
            const lastRow = rows[rows.length - 1];
            const lastInput = lastRow.tagInput;
            changeHandler({
                target: {
                    name: lastInput.attr('name'),
                    id: lastInput.attr('id'),
                },
                preventDefault() {},
            });
        },
    };
}

test('search_form.tt.html uses tagtype.id for the criterion value input id and name', () => {
    assert.doesNotMatch(
        searchTemplate,
        /id="tag_\[%\s*type\.id\s*%\]"/,
        'criterion input id must not reference undefined type.id',
    );
    assert.match(
        searchTemplate,
        /id="tag_\[%\s*tagtype\.id\s*%\]"\s+name="tag_\[%\s*tagtype\.id\s*%\]"/,
        'criterion input id and name must both use tagtype.id',
    );
});

test('adding 8 pairs (16 criterion groups) on desktop assigns unique sequential names and IDs past index 9', () => {
    const env = setupSearchSandbox({largeUp: true});
    assert.ok(env, 'search sandbox must initialize');

    // Initial state has 1 pair (tag_0, tag_1). Trigger change on the last input 7 times to reach 16 criteria (tag_0..tag_15).
    for (let pair = 1; pair < 8; pair++) {
        env.triggerLastCriterionChange();
    }

    assert.equal(env.rows.length, 16);

    const seenInputNames = new Set();
    const seenInputIds = new Set();
    const seenTypeNames = new Set();
    const seenContainsNames = new Set();

    env.rows.forEach((row, index) => {
        assert.equal(row.tagInput.attr('name'), `tag_${index}`);
        assert.equal(row.tagInput.attr('id'), `tag_${index}`);
        assert.equal(row.typeSelect.attr('name'), `tagtype_${index}`);
        assert.equal(row.typeSelect.attr('id'), `tagtype_${index}`);
        assert.equal(row.containsSelect.attr('name'), `tag_contains_${index}`);
        assert.equal(row.containsSelect.attr('id'), `tag_contains_${index}`);

        seenInputNames.add(row.tagInput.attr('name'));
        seenInputIds.add(row.tagInput.attr('id'));
        seenTypeNames.add(row.typeSelect.attr('name'));
        seenContainsNames.add(row.containsSelect.attr('name'));
    });

    assert.equal(seenInputNames.size, 16);
    assert.equal(seenInputIds.size, 16);
    assert.equal(seenTypeNames.size, 16);
    assert.equal(seenContainsNames.size, 16);
});

test('adding criteria on small screens increments sequential IDs past two-digit indices', () => {
    const env = setupSearchSandbox({largeUp: false});

    // Initial state has 2 rows (0 and 1). Add 12 more one by one to reach tag_13.
    for (let i = 0; i < 12; i++) {
        env.triggerLastCriterionChange();
    }

    assert.equal(env.rows.length, 14);
    for (let index = 0; index < 14; index++) {
        assert.equal(env.rows[index].tagInput.attr('name'), `tag_${index}`);
        assert.equal(env.rows[index].tagInput.attr('id'), `tag_${index}`);
    }
});
