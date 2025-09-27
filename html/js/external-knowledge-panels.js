/* eslint valid-jsdoc: "error" */

let allPanelsBySection = [];

/**
 * Create a safe anchor id slug from a string.
 * Keeps [a-z0-9_-], replaces others by '-'.
 * @param {string} str
 * @returns {string}
 */
function safeId(str) {
  return String(str).toLowerCase().replace(/[^a-z0-9_-]/g, "-");
}

/**
 * Pretty label for section ids like "animal_welfare" -> "Animal Welfare".
 * NOTE: Proper i18n is tracked separately; this is a fallback.
 * @param {string} sectionId
 * @returns {string}
 */
function prettySectionName(sectionId) {
  return sectionId.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Small i18n helper for a few UI strings.
 * @param {string} key
 * @param {string} lc
 * @returns {string}
 */
function t(key, lc) {
  const lang = (lc || (window.productData && window.productData.language) || "en").slice(0, 2);
  const dict = {
    en: { external_panels: "External Knowledge Panels" },
    fr: { external_panels: "Panneaux d’information externes" },
    es: { external_panels: "Paneles de información externos" },
    de: { external_panels: "Externe Informations-Panels" }
  };
  return (dict[lang] && dict[lang][key]) || dict.en[key] || key;
}

/**
 * Read localStorage opt-in (default = true).
 * @param {string} sectionId
 * @param {string} panelId
 * @returns {boolean}
 */
function getExternalKnowledgePanelsOptin(sectionId, panelId) {
  const val = localStorage.getItem("external_panel_" + sectionId + "_" + panelId);
  return val === null ? true : val === "true";
}

/**
 * Set localStorage opt-in value.
 * @param {string} sectionId
 * @param {string} panelId
 * @param {boolean} enabled
 * @returns {void}
 */
function setExternalKnowledgePanelsOptin(sectionId, panelId, enabled) {
  localStorage.setItem(
    "external_panel_" + sectionId + "_" + panelId,
    enabled ? "true" : "false"
  );
}

/**
 * Expand URL templates with productData variables.
 * Supported: $code, $lc (language), $cc (country)
 * @param {string} urlTemplate
 * @param {{code:string, language:string, country:string}} productData
 * @returns {string}
 */
function interpolateUrl(urlTemplate, productData) {
  return urlTemplate
    .replace(/\$code\b/g, encodeURIComponent(productData.code))
    .replace(/\$lc\b/g, encodeURIComponent(productData.language))
    .replace(/\$cc\b/g, encodeURIComponent(productData.country));
}

/**
 * Scope checking: public | users | moderators
 * - users: logged-in users AND moderators
 * - moderators: moderators only
 * @param {object} panel
 * @returns {boolean}
 */
function canSeeByScope(panel) {
  const scope = panel.scope || "public";
  const isModerator = window.isModerator === 1;
  const isUser = window.isUser === 1;

  return (
    scope === "public" ||
    (scope === "users" && (isUser || isModerator)) ||
    (scope === "moderators" && isModerator)
  );
}

/**
 * Filter matching against current product context.
 * categories: at least one match
 * country/language/product_type: strict equality
 * @param {object} panel
 * @param {{categories:string[], country:string, language:string, product_type:string}} ctx
 * @returns {boolean}
 */
function matchesFilters(panel, ctx) {
  const f = panel.filters || {};
  const catOk = !f.categories?.length || f.categories.some((c) => ctx.categories.includes(c));
  const countryOk = !f.countries?.length || f.countries.includes(ctx.country);
  const langOk = !f.languages?.length || f.languages.includes(ctx.language);
  const typeOk = !f.product_types?.length || f.product_types.includes(ctx.product_type);
  return catOk && countryOk && langOk && typeOk;
}

/**
 * Visibility for a panel (scope + filters + opt-in).
 * @param {string} sectionId
 * @param {object} panel
 * @param {object} ctx
 * @returns {boolean}
 */
function isPanelVisible(sectionId, panel, ctx) {
  return (
    canSeeByScope(panel) &&
    matchesFilters(panel, ctx) &&
    getExternalKnowledgePanelsOptin(sectionId, panel.id)
  );
}

/**
 * Loads external-sources.json and builds the section/panel mapping with order preserved.
 * @returns {Promise<void>}
 */
async function loadPanelsMapping() {
  const response = await fetch("/resources/files/external-sources.json");
  if (!response.ok) throw new Error("Failed to load external-sources.json");
  const sources = await response.json();

  const sections = [];
  const sectionMap = {};
  sources.forEach((panel) => {
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
 * Remove all rendered external sections.
 * @returns {void}
 */
function clearExternalSections() {
  document.querySelectorAll(".external-section").forEach((el) => el.remove());
}

/**
 * Keep navbar in sync with actually visible sections (order preserved).
 * Avoid innerHTML for XSS safety.
 * @param {{sectionId:string,label:string}[]} visibleSectionsOrdered
 * @returns {void}
 */
function syncNavbarExternalSections(visibleSectionsOrdered) {
  const navbar = document.querySelector("#navbar ul.inline-list");
  if (!navbar) return;

  // Remove previous external entries
  navbar
    .querySelectorAll("a[href^='#external_section_']")
    .forEach((link) => link.parentElement.remove());

  // Insert after "#match" anchor if present
  const after = navbar.querySelector('[href="#match"]')?.parentElement;
  let insertAfter = after || null;

  visibleSectionsOrdered.forEach(({ sectionId, label }) => {
    const li = document.createElement("li");
    li.className = "product-section-button";

    const a = document.createElement("a");
    a.className = "nav-link scrollto button small round white-button";
    const id = "external_section_" + safeId(sectionId);
    a.setAttribute("href", "#" + id);
    const span = document.createElement("span");
    span.textContent = String(label);
    a.appendChild(span);

    li.appendChild(a);

    if (insertAfter?.nextSibling) {
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
 * Smooth scroll + active link highlight.
 * @returns {void}
 */
function enableSmoothScrollAndHighlight() {
  const navbar = document.querySelector("#navbar ul.inline-list");
  if (!navbar) return;

  navbar.querySelectorAll(".nav-link").forEach((link) => {
    link.addEventListener("click", function (e) {
      const hash = this.getAttribute("href");
      if (hash?.startsWith("#") && document.querySelector(hash)) {
        e.preventDefault();
        document.querySelector(hash).scrollIntoView({ behavior: "smooth" });
        navbar.querySelectorAll(".nav-link").forEach((l) => l.classList.remove("active"));
        this.classList.add("active");
      }
    });
  });

  window.addEventListener("scroll", function () {
    const sections = Array.from(document.querySelectorAll("section[id]"));
    const scrollY = window.scrollY + 100;
    let currentId = "";
    for (const section of sections) {
      if (section.offsetTop <= scrollY) currentId = section.id;
    }
    if (currentId) {
      navbar.querySelectorAll(".nav-link").forEach((link) => {
        link.classList.toggle("active", link.getAttribute("href") === `#${currentId}`);
      });
    }
  });
}

/**
 * Render all external sections (only if they have at least 1 visible panel)
 * and sync the navbar. Order strictly follows JSON order.
 * @returns {Promise<void>}
 */
async function renderExternalKnowledgeSections() {
  if (!allPanelsBySection.length) {
    await loadPanelsMapping();
  }
  clearExternalSections();

  const { categories, country, language, product_type } = window.productData || {};
  const ctx = { categories: categories || [], country, language, product_type };

  const matchSection = document.getElementById("match");
  if (!matchSection?.parentNode) {
    // eslint-disable-next-line no-console
    console.error("Cannot find #match section to insert external panels");
    return;
  }

  // Where to insert new sections
  const parent = matchSection.parentNode;
  let insertAfter = matchSection;

  // Keep a list of sections that ended up visible
  const visibleSectionsOrdered = [];

  allPanelsBySection.forEach((section) => {
    const visiblePanels = section.panels.filter((panel) =>
      isPanelVisible(section.sectionId, panel, ctx)
    );

    // Skip empty sections (no header, no navbar link)
    if (!visiblePanels.length) {
      return;
    }

    // --- Section UI ---
    const sectionDiv = document.createElement("section");
    sectionDiv.className = "row external-section";
    sectionDiv.id = "external_section_" + safeId(section.sectionId);

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

    // --- Panels ---
    visiblePanels.forEach((panel) => {
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

      // Knowledge panel webcomponent
      const url = interpolateUrl(panel.knowledge_panel_url, window.productData);
      const knowledgePanel = document.createElement("knowledge-panels");
      knowledgePanel.setAttribute("url", url);
      knowledgePanel.setAttribute("path", "panels");
      knowledgePanel.setAttribute("heading-level", "h4");
      // Future support when available in webcomponent:
      // knowledgePanel.setAttribute("top-panels", "main,root");
      // knowledgePanel.setAttribute("external-badge", "");
      // knowledgePanel.setAttribute("external-badge-url", "/help/external-panels");

      details.appendChild(knowledgePanel);
      providerCard.appendChild(details);
      cardSection.appendChild(providerCard);
    });

    // Insert the section in DOM keeping original order
    if (insertAfter?.nextSibling) {
      parent.insertBefore(sectionDiv, insertAfter.nextSibling);
    } else {
      parent.appendChild(sectionDiv);
    }
    insertAfter = sectionDiv;

    visibleSectionsOrdered.push({ sectionId: section.sectionId, label: section.label });
  });

  // Keep navbar in sync with what actually rendered
  syncNavbarExternalSections(visibleSectionsOrdered);
  enableSmoothScrollAndHighlight();
}

/**
 * Render opt-in preferences grouped by section.
 * Show checkboxes only for panels the user could potentially see (scope + filters).
 * If none, hide the whole container.
 * @param {HTMLElement} container
 * @returns {void}
 */
function renderExternalPanelsOptinPreferences(container) {
  if (!container) {
    return;
  }

  const ensureMapping = () =>
    allPanelsBySection.length ? Promise.resolve() : loadPanelsMapping();

  ensureMapping().then(() => {
    const { categories, country, language, product_type } = window.productData || {};
    const ctx = { categories: categories || [], country, language, product_type };

    let sectionsHtml = "";
    let anyItem = false;

    allPanelsBySection.forEach((section) => {
      const scoppablePanels = section.panels.filter(
        (panel) => canSeeByScope(panel) && matchesFilters(panel, ctx)
      );

      if (!scoppablePanels.length) {
        return;
      }

      anyItem = true;
      let html = '<div class="external-pref-section" style="margin-bottom:2em;">';
      html += `<h3 style="margin-bottom:0.5em;">${section.label}</h3>`;

      scoppablePanels.forEach((panel) => {
        html += `
          <div style="margin-bottom:1em;padding:1em;background:#fff;border-radius:10px;">
            <label style="display:flex;gap:.75em;align-items:flex-start;">
              <input
                type="checkbox"
                class="optin_external_panel"
                data-panel-id="${panel.id}"
                data-section-id="${section.sectionId}"
                ${getExternalKnowledgePanelsOptin(section.sectionId, panel.id) ? "checked" : ""}
              >
              <span>
                ${panel.description || panel.name || ""}
                ${
                  panel.provider_website || panel.provider_name
                    ? `<br><small>Provided by ${
                        panel.provider_website
                          ? `<a href="${panel.provider_website}" target="_blank" rel="noopener">${panel.provider_name || panel.provider_website}</a>`
                          : panel.provider_name
                      }</small>`
                    : ``
                }
              </span>
            </label>
          </div>`;
      });

      html += `</div>`;
      sectionsHtml += html;
    });

    if (!anyItem) {
      container.innerHTML = "";
      container.style.display = "none";
      return;
    }

    container.style.display = "";
    // Global header only if there is at least one section rendered
    container.innerHTML =
      '<div class="card" style="background:#fff;margin-top:2em;margin-bottom:2em;padding:2em 2em 1em 2em;">' +
      `<h2 style="margin-bottom:1em;">${t("external_panels", language)}</h2>` +
      sectionsHtml +
      "</div>";

    // Wire events
    container.querySelectorAll(".optin_external_panel").forEach((cb) => {
      cb.addEventListener("change", function () {
        setExternalKnowledgePanelsOptin(
          this.dataset.sectionId,
          this.dataset.panelId,
          this.checked
        );
        // Live refresh after opt-in change
        renderExternalKnowledgeSections();
      });
    });
  });
}

// Expose globally for product-preferences.js to call it safely
window.renderExternalPanelsOptinPreferences = renderExternalPanelsOptinPreferences;

document.addEventListener("DOMContentLoaded", () => {
  renderExternalKnowledgeSections();
});
