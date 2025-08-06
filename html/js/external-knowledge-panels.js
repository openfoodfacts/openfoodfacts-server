let allPanelsBySection = [];

/**
 * Loads external-sources.json and builds the original section/panel mapping with order preserved.
 */
async function loadPanelsMapping() {
    const response = await fetch('/resources/files/external-sources.json');
    if (!response.ok) throw new Error("Failed to load external-sources.json");
    const sources = await response.json();
    const sections = [];
    const sectionMap = {};
    sources.forEach(panel => {
        if (!sectionMap[panel.section]) {
            const sectionObj = {
                sectionId: panel.section,
                label: prettySectionName(panel.section),
                panels: []
            };
            sectionMap[panel.section] = sectionObj;
            sections.push(sectionObj);
        }
        sectionMap[panel.section].panels.push(panel);
    });
    allPanelsBySection = sections;
}

/**
 * Returns a pretty string for section names.
 */
function prettySectionName(sectionId) {
    return sectionId.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

/**
 * Returns whether the panel should be shown (opt-in), defaulting to true.
 */
function getExternalKnowledgePanelsOptin(sectionId, panelId) {
    const val = localStorage.getItem('external_panel_' + sectionId + "_" + panelId);
    return val === null ? true : val === "true";
}

/**
 * Sets the opt-in value for a panel.
 */
function setExternalKnowledgePanelsOptin(sectionId, panelId, enabled) {
    localStorage.setItem('external_panel_' + sectionId + "_" + panelId, enabled);
}

/**
 * Expands a template URL with variables from productData.
 */
function interpolateUrl(urlTemplate, productData) {
    return urlTemplate
        .replace(/\$code\b/g, encodeURIComponent(productData.code))
        .replace(/\$lc\b/g, encodeURIComponent(productData.language))
        .replace(/\$cc\b/g, encodeURIComponent(productData.country));
}

/**
 * Clears all rendered external panel sections from DOM.
 */
function clearExternalSections() {
    document.querySelectorAll('.external-section').forEach(el => el.remove());
}

/**
 * Synchronizes the navbar with the visible external sections, preserving their order.
 */
function syncNavbarExternalSections(visibleSectionsOrdered) {
    const navbar = document.querySelector("#navbar ul.inline-list");
    navbar.querySelectorAll("a[href^='#external_section_']").forEach(link => link.parentElement.remove());
    const after = navbar.querySelector('[href="#match"]')?.parentElement;
    let insertAfter = after;
    visibleSectionsOrdered.forEach(({ sectionId, label }) => {
        const li = document.createElement("li");
        li.className = "product-section-button";
        li.innerHTML = `<a class="nav-link scrollto button small round white-button" href="#external_section_${sectionId}"><span>${label}</span></a>`;
        if (insertAfter && insertAfter.nextSibling) {
            insertAfter.parentNode.insertBefore(li, insertAfter.nextSibling);
        } else if (insertAfter) {
            insertAfter.parentNode.appendChild(li);
        } else {
            navbar.appendChild(li);
        }
        insertAfter = li;
    });
}

/**
 * Enables smooth scroll and highlight for navbar links.
 */
function enableSmoothScrollAndHighlight() {
    const navbar = document.querySelector("#navbar ul.inline-list");
    if (!navbar) return;
    navbar.querySelectorAll(".nav-link").forEach(link => {
        link.addEventListener("click", function(e) {
            const hash = this.getAttribute("href");
            if (hash && hash.startsWith("#") && document.querySelector(hash)) {
                e.preventDefault();
                document.querySelector(hash).scrollIntoView({ behavior: "smooth" });
                navbar.querySelectorAll(".nav-link").forEach(l => l.classList.remove("active"));
                this.classList.add("active");
            }
        });
    });
    window.addEventListener("scroll", function() {
        const sections = Array.from(document.querySelectorAll("section[id]"));
        const scrollY = window.scrollY + 100;
        let currentId = "";
        for (const section of sections) {
            if (section.offsetTop <= scrollY) {
                currentId = section.id;
            }
        }
        if (currentId) {
            navbar.querySelectorAll(".nav-link").forEach(link => {
                link.classList.toggle("active", link.getAttribute("href") === `#${currentId}`);
            });
        }
    });
}

/**
 * Renders all visible external knowledge panel sections and updates the navbar in the original JSON order.
 */
async function renderExternalKnowledgeSections() {
    if (!allPanelsBySection.length) {
        await loadPanelsMapping();
    }
    clearExternalSections();
    const { code, category, country, language, product_type } = window.productData;
    const matchSection = document.getElementById('match');
    if (!matchSection || !matchSection.parentNode) {
        console.error("Cannot find #match section to insert external panels");
        return;
    }
    let parent = matchSection.parentNode;
    let insertAfter = matchSection;
    const visibleSectionsOrdered = [];
    allPanelsBySection.forEach(section => {
        const visiblePanels = section.panels.filter(panel => {
            const f = panel.filters || {};
            const matchCat = !f.categories || !f.categories.length || f.categories.some(cat => category.includes(cat));
            const matchCountry = !f.countries || !f.countries.length || f.countries.some(c => country.includes(c));
            const matchLang = !f.languages || !f.languages.length || f.languages.some(l => language.includes(l));
            const matchType = !f.product_types || !f.product_types.length || f.product_types.some(pt => product_type.includes(pt));
            return matchCat && matchCountry && matchLang && matchType && getExternalKnowledgePanelsOptin(section.sectionId, panel.id);
        });
        if (!visiblePanels.length) return;
        const sectionDiv = document.createElement("section");
        sectionDiv.className = "row external-section";
        sectionDiv.id = "external_section_" + section.sectionId;
        const colDiv = document.createElement("div");
        colDiv.className = "large-12 column";
        sectionDiv.appendChild(colDiv);
        const cardDiv = document.createElement("div");
        cardDiv.className = "card";
        colDiv.appendChild(cardDiv);
        const cardSection = document.createElement("div");
        cardSection.className = "card-section";
        cardDiv.appendChild(cardSection);
        const sectionTitle = document.createElement("h2");
        sectionTitle.textContent = section.label;
        cardSection.appendChild(sectionTitle);
        visiblePanels.forEach(panel => {
            const providerCard = document.createElement("div");
            providerCard.className = "provider-card";

            const details = document.createElement("details");
            details.open = true;

            const summary = document.createElement("summary");
            summary.className = "provider-summary";

            if (panel.icon_url) {
                const logo = document.createElement("img");
                logo.src = panel.icon_url;
                logo.className = "provider-logo";
                logo.alt = panel.provider_name || panel.name || "";
                summary.appendChild(logo);
            }
            const providerName = document.createElement("span");
            providerName.className = "provider-name";
            providerName.textContent = panel.provider_name || panel.name || "";
            summary.appendChild(providerName);

            if (panel.description) {
                const providerDesc = document.createElement("span");
                providerDesc.className = "provider-desc";
                providerDesc.textContent = panel.description;
                summary.appendChild(providerDesc);
            }

            const arrow = document.createElement("span");
            arrow.className = "provider-arrow";
            arrow.innerHTML = "&#9660;"; // ▼
            summary.appendChild(arrow);

            details.appendChild(summary);

            const hr = document.createElement("hr");
            hr.className = "provider-separator";
            details.appendChild(hr);

            const url = interpolateUrl(panel.knowledge_panel_url, window.productData);
            const knowledgePanel = document.createElement("knowledge-panels");
            knowledgePanel.setAttribute("url", url);
            knowledgePanel.setAttribute("path", "panels");
            knowledgePanel.setAttribute("heading-level", "h4");
            details.appendChild(knowledgePanel);

            providerCard.appendChild(details);
            cardSection.appendChild(providerCard);
        });

        if (insertAfter.nextSibling) {
            parent.insertBefore(sectionDiv, insertAfter.nextSibling);
        } else {
            parent.appendChild(sectionDiv);
        }
        insertAfter = sectionDiv;
        visibleSectionsOrdered.push({ sectionId: section.sectionId, label: section.label });
    });
    syncNavbarExternalSections(visibleSectionsOrdered);
    enableSmoothScrollAndHighlight();
}

/**
 * Renders the opt-in preference UI for all external knowledge panels, grouped by section.
 */
function renderExternalPanelsOptinPreferences(container) {
    if (!allPanelsBySection.length) {
        loadPanelsMapping().then(() => renderExternalPanelsOptinPreferences(container));
        return;
    }
    let html = '<div class="card" style="background:#fff;margin-top:2em;margin-bottom:2em;padding:2em 2em 1em 2em;">';
    html += `<h2 style="margin-bottom:1em;">External Knowledge Panels (BETA)</h2>`;
    allPanelsBySection.forEach(section => {
        html += `<div class="external-pref-section" style="margin-bottom:2em;">`;
        html += `<h3 style="margin-bottom:0.5em;">${section.label}</h3>`;
        section.panels.forEach(panel => {
            html += `
                <div style="margin-bottom:1em;padding:1em;background:#fff7f2;border-radius:10px;">
                    <label>
                        <input type="checkbox" class="optin_external_panel"
                            data-panel-id="${panel.id}"
                            data-section-id="${section.sectionId}"
                            ${getExternalKnowledgePanelsOptin(section.sectionId, panel.id) ? "checked" : ""}>
                        ${panel.description}
                    </label>
                </div>
            `;
        });
        html += `</div>`;
    });
    html += '</div>';
    container.innerHTML = html;
    container.querySelectorAll(".optin_external_panel").forEach(cb => {
        cb.addEventListener("change", function () {
            setExternalKnowledgePanelsOptin(this.dataset.sectionId, this.dataset.panelId, this.checked);
            renderExternalKnowledgeSections();
        });
    });
}

document.addEventListener("DOMContentLoaded", renderExternalKnowledgeSections);
