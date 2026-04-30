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

            let obj;

            try {
                obj = JSON.parse(window.localStorage.getItem("po_last_tags"));
            } catch (err) {
                if (err.name == "NS_ERROR_FILE_CORRUPTED") {
                    obj = null;
                }
            }

            const tag = event.detail.data.value;
            if (obj === null) {
                obj = {};
                obj[el.id] = [tag];
            } else if (obj[el.id] === null || !Array.isArray(obj[el.id])) {
                obj[el.id] = [tag];
            } else if (obj[el.id].indexOf(tag) == -1) {
                if (obj[el.id].length >= maximumRecentEntriesPerTag) {
                    obj[el.id].pop();
                }

                obj[el.id].unshift(tag);
            }

            try {
                window.localStorage.setItem("po_last_tags", JSON.stringify(obj));
            } catch (err) {
                if (err.name == "NS_ERROR_FILE_CORRUPTED") {
                    // Don't to anything
                }
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
        let obj;
        try {
            obj = JSON.parse(window.localStorage.getItem("po_last_tags"));
        } catch (e) {
            if (e.name == "NS_ERROR_FILE_CORRUPTED") {
                obj = null;
            }
        }

        if (
            obj !== null &&
            typeof obj[tagfield] !== "undefined" &&
            obj[tagfield] !== null
        ) {
            return obj[tagfield];
        }
    }

    return [];
}