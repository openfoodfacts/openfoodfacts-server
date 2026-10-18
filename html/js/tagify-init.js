// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2025 Association Open Food Facts
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
/*exported initializeTagifyInput*/

// Note: this function is used in product-multilingual.js and product-preferences.js to select unwanted ingredients

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

    let abortController;
    let debounceTimer;
    const timeoutWait = 300;
    let value = "";

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
        autocompleteWithSearch(event.detail.data.value);
    });

    input.on("change", function () {
        value = "";
        updateSuggestions(false);
        if (changeCallback) {
            changeCallback(el);
        }
    });

    input.on("edit:updated", function () {
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

        // Store the last tags in localStorage if maximumRecentEntriesPerTag > 0

        if (maximumRecentEntriesPerTag) {

            const obj = get_last_tags();

            obj[el.id] = update_tag_recents(obj[el.id], event.detail.data.value, maximumRecentEntriesPerTag);

            try {
                window.localStorage.setItem("po_last_tags", JSON.stringify(obj));
            } catch {
                // Don't do anything if the local storage is not writable (e.g. Firefox private mode)
            }

        }

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

function get_recents(tagfield, maximumRecentEntriesPerTag) {
    if (maximumRecentEntriesPerTag > 0) {
        const obj = get_last_tags();

        if (Array.isArray(obj[tagfield])) {
            return obj[tagfield];
        }
    }

    return [];
}

// Read the tags history saved in the local storage
function get_last_tags() {
    let obj = null;

    try {
        obj = JSON.parse(window.localStorage.getItem("po_last_tags"));
    } catch {
        // Ignore values we cannot read or parse (corrupted value, local storage not readable):
        // the history is simply built again from the tags added from now on
        obj = null;
    }

    if (obj === null || typeof obj !== "object") {
        obj = {};
    }

    return obj;
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