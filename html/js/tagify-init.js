// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2026 Association Open Food Facts
// Contact: contact@openfoodfacts.org
// Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
//
// Product Opener is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

/*eslint dot-location: "off"*/
/*eslint no-console: "off"*/
/*global Tagify*/
/*exported initializeTagifyInput, getTagsToCommit, addTagsToRecentTags*/

// Note: this function is used in product-multilingual.js and product-preferences.js to select unwanted ingredients

// The tags history is kept per input element (and saved in the local storage per field id) so that
// two fields never mix their suggestions, even though they are edited on the same page.
const recentTagsByInput = new WeakMap(); // input element -> { maximum, tagsToCommit }

function initializeTagifyInput(el, maximumRecentEntriesPerTag, changeCallback) {
    const input = new Tagify(el, {
        autocomplete: true,
        whitelist: get_recents(el.id, maximumRecentEntriesPerTag) || [],
        dropdown: {
            highlightFirst: false,
            enabled: 0,
            maxItems: 100
        }
    });

    // Tagify hides the original input and uses a contenteditable element instead.
    // Clicking its label or the empty border can otherwise focus the wrapper,
    // leaving keyboard events directed away from the text entry area.
    function focusTextInput() {
        input.DOM.input.focus();
    }

    for (const label of el.labels || []) {
        label.addEventListener("click", function (event) {
            // Prevent the label's default action from refocusing the hidden input.
            event.preventDefault();
            focusTextInput();
        });
    }
    input.DOM.scope.addEventListener("click", function (event) {
        // Keep Tagify's own interactions with existing tags and their controls.
        if (event.target === input.DOM.scope) {
            focusTextInput();
        }
    });

    let abortController;
    let debounceTimer;
    const timeoutWait = 300;
    let value = "";

    // Tags added or edited by the user during this session.
    // They are only added to the tags history when the form is submitted, see addTagsToRecentTags()
    const tagsToCommit = new Set();
    recentTagsByInput.set(el, { maximum: maximumRecentEntriesPerTag, tagsToCommit });
    // Value of the tag being edited, to avoid committing a tag the user opened but did not change
    let tagValueBeforeEdit = null;

    function updateSuggestions(show) {
        if (value) {
            const lc = (/^\w\w:/).exec(value);
            const term = lc ? value.substring(lc[0].length) : value;
            if (show) {
                input.dropdown.show(term);
            }
        } else {
            input.whitelist = get_recents(el.id, maximumRecentEntriesPerTag) || [];
            if (show) {
                input.dropdown.show();
            }
        }
    }

    function autocompleteWithSearch(newValue) {
        value = newValue;
        input.whitelist = null; // reset the whitelist

        if (el.dataset.autocomplete && el.dataset.autocomplete !== "") {
            clearTimeout(debounceTimer);

            debounceTimer = setTimeout(function () {
                // https://developer.mozilla.org/en-US/docs/Web/API/AbortController/abort
                if (abortController) {
                    abortController.abort();
                }

                abortController = new AbortController();

                fetch(el.dataset.autocomplete + "&string=" + value + "&get_synonyms=1", {
                    signal: abortController.signal
                }).
                    then((RES) => RES.json()).
                    then(function (json) {
                        const lc = (/^\w\w:/).exec(value);
                        let whitelist = Object.values(json.matched_synonyms);
                        if (lc) {
                            whitelist = whitelist.map(function (e) {
                                return {"value": lc + e, "searchBy": e};
                            });
                        }
                        const synonymMap = Object.create(null);
                        // eslint-disable-next-line guard-for-in
                        for (const k in json.matched_synonyms) {
                            synonymMap[json.matched_synonyms[k]] = k;
                        }
                        input.synonymMap = synonymMap;
                        input.whitelist = whitelist;
                        updateSuggestions(true); // render the suggestions dropdown
                    });
            }, timeoutWait);
        }
        updateSuggestions(true);
    }

    input.on("input", function (event) {
        autocompleteWithSearch(event.detail.value);
    });

    input.on("edit:input", function (event) {
        autocompleteWithSearch(event.detail.data.newValue);
    });

    input.on("edit:start", function (event) {
        tagValueBeforeEdit = event.detail.data.value;
        autocompleteWithSearch(event.detail.data.value);
    });

    input.on("change", function () {
        value = "";
        updateSuggestions(false);
        if (changeCallback) {
            changeCallback(el);
        }
    });

    input.on("edit:updated", function (event) {
        // Remember the new value, so that it is committed to the tags history on submit.
        // The data is empty when the tag was emptied out and removed, and the event is not
        // triggered at all when the edition is reverted (Esc).
        const newValue = event.detail.data && event.detail.data.value;
        if (newValue && newValue !== tagValueBeforeEdit) {
            tagsToCommit.add(newValue);
        }
        tagValueBeforeEdit = null;
        value = "";
        updateSuggestions(false);
    });

    input.on("dropdown:show", function() {
        if (!input.synonymMap) {
            return;
        }
        $(input.DOM.dropdown).find("div.tagify__dropdown__item").each(function(_,e) {
            let synonymName = e.getAttribute("value");
            const lc = (/^\w\w:/).exec(synonymName);
            if (lc) {
                synonymName = synonymName.substring(3);
            }
            const canonicalName = input.synonymMap[synonymName];
            if (canonicalName && canonicalName !== synonymName) {
                e.innerHTML += " (&rarr; <i>" + canonicalName + "</i>)";
            }
        });
    });

    input.on("add", function (event) {

        // Remember the tag, it will only be added to the tags history on submit,
        // so that tags that are never submitted (typos, wrong tags) are not remembered
        tagsToCommit.add(event.detail.data.value);

        value = "";
        updateSuggestions(false);
    });

    input.on("focus", function () {
        value = "";
        updateSuggestions(false);
    });

    input.on("blur", function () {
        value = "";
        updateSuggestions(false);
    });
}

// Return the tags that the user added or edited for the input, and that are actually
// present in the submitted tags. Tags that were added and then removed are not returned.
function getTagsToCommit(el, submittedTags) {
    const state = recentTagsByInput.get(el);
    if (!state || !state.maximum || !state.tagsToCommit.size) {
        return [];
    }

    return submittedTags.filter((tag) => state.tagsToCommit.has(tag));
}

// Add the given tags to the tags history of each field, so that they are suggested
// the next time the field is edited. Called once for the whole page, so that the tags
// history is only read and written once.
// entries is an array of { id: field id, maximum: maximum number of tags to keep, tags: tags to add }
function addTagsToRecentTags(entries) {
    const store = readRecentTags();

    for (const { id, maximum, tags } of entries) {
        // Deduplicate the committed tags, keeping the first occurrence (field order)
        const seen = new Set();
        const uniqueTags = [];
        for (const tag of tags) {
            if (!seen.has(tag)) {
                seen.add(tag);
                uniqueTags.push(tag);
            }
        }
        // Keep the history ordered by most recently used (issue #15005):
        // apply the single-tag helper from last to first, so that committed tags
        // end up first in field order and re-added tags move back to the top.
        let history = Array.isArray(store[id]) ? store[id] : [];
        for (let i = uniqueTags.length - 1; i >= 0; i--) {
            history = update_tag_recents(history, uniqueTags[i], maximum);
        }
        store[id] = history;
    }

    writeRecentTags(store);
}

function get_recents(tagfield, maximumRecentEntriesPerTag) {
    if (maximumRecentEntriesPerTag > 0) {
        const recents = readRecentTags()[tagfield];

        if (Array.isArray(recents)) {
            return recents;
        }
    }

    return [];
}

// Read the tags history saved in the local storage, indexed by field id
function readRecentTags() {
    let store;

    try {
        store = JSON.parse(window.localStorage.getItem("po_last_tags"));
    } catch {
        // Ignore corrupted values and local storage errors (e.g. Firefox private mode):
        // the history is simply rebuilt from the tags committed from now on
        store = null;
    }

    return (store === null || typeof store !== "object") ? {} : store;
}

function writeRecentTags(store) {
    try {
        window.localStorage.setItem("po_last_tags", JSON.stringify(store));
    } catch {
        // Nothing to do if the local storage is not writable
    }
}

// Add a tag to the history of a field, and keep the history ordered by most recently used:
// the tag is moved to the top, even if it was already in the history, and the least recently
// used tag is dropped when the tag is not in the history yet and the history is full
function update_tag_recents(recents_ref, tag, maximumRecentEntriesPerTag) {
    const history = Array.isArray(recents_ref) ? recents_ref.slice() : [];

    const previousIndex = history.indexOf(tag);
    if (previousIndex >= 0) {
        history.splice(previousIndex, 1);
    } else if (history.length >= maximumRecentEntriesPerTag) {
        history.pop();
    }

    history.unshift(tag);

    // Drop the tags that do not fit anymore, e.g. if the maximum was lowered
    if (history.length > maximumRecentEntriesPerTag) {
        history.length = maximumRecentEntriesPerTag;
    }

    return history;
}
