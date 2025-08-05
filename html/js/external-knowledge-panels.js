// TEMP DEBUG - remove after
console.log("Perl productData before mock:", window.productData);

window.productData = {
    code: "3450970045360",
    category: "en:cage-chicken-eggs",
    country: "fr",
    language: "fr",
    product_type: "food"
};

function clearExternalSections() {
    document.querySelectorAll('.external-section').forEach(el => el.remove());
}

function prettySectionName(sectionId) {
    return sectionId.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

function getExternalKnowledgePanelsOptin(panelId) {
    const val = localStorage.getItem('external_panel_' + panelId);
    return val === null ? true : val === "true";
}

function setExternalKnowledgePanelsOptin(panelId, enabled) {
    localStorage.setItem('external_panel_' + panelId, enabled);
}

async function renderExternalKnowledgeSections() {
    clearExternalSections();

    let sources;
    try {
        const response = await fetch('/resources/files/external-sources.json');
        if (!response.ok) {
            console.error("Failed to load external-sources.json");
            return;
        }
        sources = await response.json();
    } catch (err) {
        console.error("Error fetching external-sources.json", err);
        return;
    }

    const { code, category, country, language, product_type } = window.productData;

    const filtered = sources.filter(panel => {
        const f = panel.filters || {};
        const matchCat = !f.categories || !f.categories.length || f.categories.includes(category);
        const matchCountry = !f.countries || !f.countries.length || f.countries.includes(country);
        const matchLang = !f.languages || !f.languages.length || f.languages.includes(language);
        const matchType = !f.product_types || !f.product_types.length || f.product_types.includes(product_type);
        return matchCat && matchCountry && matchLang && matchType && getExternalKnowledgePanelsOptin(panel.id);
    });

    const bySection = {};
    filtered.forEach(panel => {
        if (!bySection[panel.section]) bySection[panel.section] = [];
        bySection[panel.section].push(panel);
    });

    const matchSection = document.getElementById('match');
    if (!matchSection || !matchSection.parentNode) {
        console.error("Cannot find #match section to insert external panels");
        return;
    }
    let parent = matchSection.parentNode;
    let insertAfter = matchSection;

    Object.entries(bySection).forEach(([sectionId, panels]) => {
        const sectionDiv = document.createElement("section");
        sectionDiv.className = "row external-section";
        sectionDiv.id = "external_section_" + sectionId;

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
        sectionTitle.textContent = prettySectionName(sectionId);
        cardSection.appendChild(sectionTitle);

        panels.forEach(panel => {
            const panelTitle = document.createElement("h3");
            panelTitle.textContent = panel.name;
            cardSection.appendChild(panelTitle);

            const url = `${panel.knowledge_panel_url}${code}?lang=${language}`;
            const knowledgePanel = document.createElement("knowledge-panels");
            knowledgePanel.setAttribute("url", url);
            knowledgePanel.setAttribute("path", "panels");
            knowledgePanel.setAttribute("heading-level", "h4");
            cardSection.appendChild(knowledgePanel);
        });

        if (insertAfter.nextSibling) {
            parent.insertBefore(sectionDiv, insertAfter.nextSibling);
        } else {
            parent.appendChild(sectionDiv);
        }
        insertAfter = sectionDiv;
    });
}

function renderExternalPanelsOptinPreferences(container) {
    fetch('/resources/files/external-sources.json')
      .then(r => {
        if (!r.ok) {
            console.error("Failed to load external-sources.json (optin prefs)");
            return [];
        }
        return r.json();
      })
      .then(sources => {
        if (!Array.isArray(sources)) return;
        container.innerHTML = sources.map(panel => `
          <div class="panel callout" style="margin-bottom:1em;">
            <label>
              <input type="checkbox" class="optin_external_panel" data-panel-id="${panel.id}" ${getExternalKnowledgePanelsOptin(panel.id) ? "checked" : ""}>
              ${panel.description}
            </label>
          </div>
        `).join("");
        container.querySelectorAll(".optin_external_panel").forEach(cb => {
            cb.addEventListener("change", function () {
                setExternalKnowledgePanelsOptin(this.dataset.panelId, this.checked);
                renderExternalKnowledgeSections();
            });
        });
      })
      .catch(err => {
        console.error("Error fetching external-sources.json (optin prefs)", err);
      });
}

document.addEventListener("DOMContentLoaded", renderExternalKnowledgeSections);

