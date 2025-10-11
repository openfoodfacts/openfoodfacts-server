/* eslint valid-jsdoc: "error" */
/* exported renderExternalPanelsOptinPreferences */

/**
 * External knowledge panels rendering and preferences.
 * - Renders sections and providers strictly in JSON order.
 * - Enforces scope and product filters.
 * - Opt-in stored per (sectionId, panelId) in localStorage, default false.
 * - Hides a panel if its URL returns 404, and shows an availability message next to the opt-in checkbox when checked.
 * - Supports partial rerender by section to avoid full-page flashing.
 */

let allPanelsBySection = [];
let mappingPromise = null;

const notFoundPanels = new Set();
const availabilityCache = new Map();

/**
 * Create a safe anchor id slug from a string.
 * Keeps [a-z0-9_-], replaces others by '-'.
 * @param {string} str - Source string to slugify.
 * @returns {string} A sanitized id-safe slug.
 */
function safeId(str) {
  return String(str).toLowerCase().replace(/[^a-z0-9_-]/g, "-");
}

/**
 * Pretty label fallback for section ids like "animal_welfare" -> "Animal Welfare".
 * NOTE: Proper i18n is provided by the API (section_title); this is a fallback.
 * @param {string} sectionId - Raw section identifier.
 * @returns {string} Human readable section label.
 */
function prettySectionName(sectionId) {
  return sectionId.replaceAll("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Small i18n helper for a few UI strings.
 * @param {string} key - Translation key.
 * @param {string} lc - Language code (optional).
 * @returns {string} Localized string for the given key.
 */
function t(key, lc) {
  const lang = (lc || globalThis.productData?.language || "en").slice(0, 2);
  const dict = {
    en: { external_panels: "External Knowledge Panels", panel_unavailable: "Panel unavailable" },
    fr: { external_panels: "Panneaux d’information externes", panel_unavailable: "Panel unavailable" },
    es: { external_panels: "Paneles de información externos", panel_unavailable: "Panel unavailable" },
    de: { external_panels: "Externe Informations-Panels", panel_unavailable: "Panel unavailable" }
  };
  return (dict[lang] && dict[lang][key]) || dict.en[key] || key;
}

/**
 * Read localStorage opt-in (true only if explicitly "true").
 * Default false.
 * @param {string} sectionId
 * @param {string} panelId
 * @returns {boolean}
 */
function getExternalKnowledgePanelsOptin(sectionId, panelId) {
  const val = globalThis.localStorage.getItem(`external_panel_${sectionId}_${panelId}`);
  return val === "true";
}

/**
 * Set localStorage opt-in value.
 * @param {string} sectionId
 * @param {string} panelId
 * @param {boolean} enabled
 * @returns {void}
 */
function setExternalKnowledgePanelsOptin(sectionId, panelId, enabled) {
  globalThis.localStorage.setItem(
    `external_panel_${sectionId}_${panelId}`,
    enabled ? "true" : "false"
  );
}

/**
 * Expand URL templates with productData variables.
 * Supported: $code, $lc (language), $cc (country)
 * @param {string} urlTemplate
 * @param {Object} productData
 * @returns {string}
 */
function interpolateUrl(urlTemplate, productData) {
  const pd = productData || {};
  return String(urlTemplate)
    .replaceAll("$code", encodeURIComponent(pd.code || ""))
    .replaceAll("$lc", encodeURIComponent(pd.language || ""))
    .replaceAll("$cc", encodeURIComponent(pd.country || ""));
}

/**
 * Scope checking: public | users | moderators.
 * - users: logged-in users AND moderators
 * - moderators: moderators only
 * @param {Object} panel
 * @returns {boolean}
 */
function canSeeByScope(panel) {
  const scope = panel.scope || "public";
  const isModerator = globalThis.isModerator === 1;
  const isUser = Number(globalThis.isUser) === 1;

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
 * @param {Object} panel
 * @param {Object} ctx
 * @returns {boolean}
 */
function matchesFilters(panel, ctx) {
  const f = panel.filters || {};
  const catOk = !f.categories?.length || f.categories.some((c) => ctx.categories.includes(c));
  const countryOk = !f.countries?.length || (ctx.country ? f.countries.includes(ctx.country) : true);
  const langOk = !f.languages?.length || (ctx.language ? f.languages.includes(ctx.language) : true);
  const typeOk =
    !f.product_types?.length || (ctx.product_type ? f.product_types.includes(ctx.product_type) : true);
  return catOk && countryOk && langOk && typeOk;
}

/**
 * Visibility for a panel (scope + filters + opt-in).
 * @param {string} sectionId
 * @param {Object} panel
 * @param {Object} ctx
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
 * Check availability for a panel URL. Only 404 matters.
 * Uses HEAD then GET. Caches per session.
 * @param {string} url
 * @returns {Promise<boolean>}
 */
async function isPanelAvailable(url) {
  if (!url) return true;
  if (availabilityCache.has(url)) {
    const hit = availabilityCache.get(url);
    if (hit && hit.status === 404) return false;
    return true;
  }
  try {
    const head = await fetch(url, { method: "HEAD", mode: "cors" });
    if (head.status === 404) {
      availabilityCache.set(url, { checkedAt: Date.now(), status: 404 });
      return false;
    }
    if (head.type !== "opaque" && head.status) {
      availabilityCache.set(url, { checkedAt: Date.now(), status: head.status });
      return true;
    }
  } catch (_) {}
  try {
    const get = await fetch(url, { method: "GET", mode: "cors" });
    if (get.status === 404) {
      availabilityCache.set(url, { checkedAt: Date.now(), status: 404 });
      return false;
    }
    if (get.type !== "opaque" && get.status) {
      availabilityCache.set(url, { checkedAt: Date.now(), status: get.status });
    }
  } catch (_) {}
  return true;
}

/**
 * Fetch external sources (translated) and build ordered sections mapping.
 * @returns {Promise<void>}
 */
async function loadPanelsMapping() {
  const lc = globalThis.productData?.language || "en";
  const resp = await fetch(`/api/v3/external_sources?lc=${encodeURIComponent(lc)}`);
  if (!resp.ok) {
    throw new Error("Failed to load external sources");
  }
  const raw = await resp.json();

  // Flexible parsing: array or wrapped {status, external_sources, errors}
  const sources =
    Array.isArray(raw) ? raw :
    Array.isArray(raw?.external_sources) ? raw.external_sources :
    [];

  const sections = [];
  const sectionMap = Object.create(null);

  for (const panel of sources) {
    const sid = panel.section;
    if (!sectionMap[sid]) {
      const label = panel.section_title || prettySectionName(sid);
      sectionMap[sid] = { sectionId: sid, label, panels: [] };
      sections.push(sectionMap[sid]);
    }
    sectionMap[sid].panels.push(panel);
  }

  allPanelsBySection.length = 0;
  Array.prototype.push.apply(allPanelsBySection, sections);
}

/**
 * Remove all rendered external sections.
 * @returns {void}
 */
function clearExternalSections() {
  for (const el of document.querySelectorAll(".external-section")) {
    el.remove();
  }
}

/**
 * Keep navbar in sync with actually visible sections (order preserved).
 * @param {Array<{sectionId:string,label:string}>} visibleSectionsOrdered
 * @returns {void}
 */
function syncNavbarExternalSections(visibleSectionsOrdered) {
  const navbar = document.querySelector("#navbar ul.inline-list");
  if (!navbar) return;

  for (const link of navbar.querySelectorAll("a[href^='#external_section_']")) {
    link.parentElement?.remove();
  }

  const after = navbar.querySelector('[href="#match"]')?.parentElement || null;
  let insertAfter = after;

  for (const { sectionId, label } of visibleSectionsOrdered) {
    const li = document.createElement("li");
    li.className = "product-section-button";

    const a = document.createElement("a");
    a.className = "nav-link scrollto button small round white-button";
    const id = `external_section_${safeId(sectionId)}`;
    a.setAttribute("href", `#${id}`);

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
  }
}

/**
 * Smooth scroll + active link highlight.
 * @returns {void}
 */
function enableSmoothScrollAndHighlight() {
  const navbar = document.querySelector("#navbar ul.inline-list");
  if (!navbar) return;

  for (const link of navbar.querySelectorAll(".nav-link")) {
    link.addEventListener("click", function (e) {
      const hash = this.getAttribute("href");
      if (hash?.startsWith("#") && document.querySelector(hash)) {
        e.preventDefault();
        document.querySelector(hash).scrollIntoView({ behavior: "smooth" });
        for (const l of navbar.querySelectorAll(".nav-link")) l.classList.remove("active");
        this.classList.add("active");
      }
    });
  }

  globalThis.addEventListener("scroll", function () {
    const sections = Array.from(document.querySelectorAll("section[id]"));
    const scrollY = globalThis.scrollY + 100;
    let currentId = "";
    for (const section of sections) {
      if (section.offsetTop <= scrollY) currentId = section.id;
    }
    if (currentId) {
      for (const link of navbar.querySelectorAll(".nav-link")) {
        link.classList.toggle("active", link.getAttribute("href") === `#${currentId}`);
      }
    }
  });
}

/**
 * Ensure mapping is loaded
 * @returns {Promise<void>}
 */
function ensureMapping() {
  if (allPanelsBySection.length) return Promise.resolve();
  if (mappingPromise) return mappingPromise;
  mappingPromise = loadPanelsMapping().finally(() => { mappingPromise = null; });
  return mappingPromise;
}

/**
 * Render all external sections (only if they have at least 1 visible panel)
 * and sync the navbar. Order strictly follows JSON order.
 * @returns {Promise<void>}
 */
async function buildSectionElement(section, ctx) {
  const visiblePanels = section.panels.filter((panel) => isPanelVisible(section.sectionId, panel, ctx));
  if (!visiblePanels.length) {
    return { sectionId: section.sectionId, el: null, hasAnyRenderedPanel: false };
  }

  const sectionDiv = document.createElement("section");
  sectionDiv.className = "row external-section";
  sectionDiv.id = `external_section_${safeId(section.sectionId)}`;

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

  let hasAnyRenderedPanel = false;

  for (const panel of visiblePanels) {
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
    arrow.innerHTML = "&#9660;";
    summary.appendChild(arrow);

    details.appendChild(summary);

    const hr = document.createElement("hr");
    hr.className = "provider-separator";
    details.appendChild(hr);

    const url = interpolateUrl(panel.knowledge_panel_url, globalThis.productData || {});
    const key = `${section.sectionId}::${panel.id}`;
    const available =
      availabilityCache.has(url) ? availabilityCache.get(url).status !== 404 : await isPanelAvailable(url);

    if (!available) {
      notFoundPanels.add(key);
    } else {
      notFoundPanels.delete(key);
      const knowledgePanel = document.createElement("knowledge-panels");
      knowledgePanel.setAttribute("url", url);
      knowledgePanel.setAttribute("path", "panels");
      knowledgePanel.setAttribute("heading-level", "h4");
      details.appendChild(knowledgePanel);
      hasAnyRenderedPanel = true;
    }

    providerCard.appendChild(details);
    if (available) {
      cardSection.appendChild(providerCard);
    }
  }

  if (!hasAnyRenderedPanel) {
    return { sectionId: section.sectionId, el: null, hasAnyRenderedPanel: false };
  }

  return { sectionId: section.sectionId, el: sectionDiv, hasAnyRenderedPanel: true };
}

/**
 * Render external sections. Full render by default.
 * Pass {only: Set<sectionId>} to rerender only specific sections.
 * @param {{only?: Set<string>}} opts
 * @returns {Promise<void>}
 */
async function renderExternalKnowledgeSections(opts) {
  await ensureMapping();

  const { categories, country, language, product_type } = globalThis.productData || {};
  const ctx = { categories: categories || [], country, language, product_type };

  const parentAnchor = document.getElementById("match");
  if (!parentAnchor?.parentNode) {
    console.error("Cannot find #match section to insert external panels");
    return;
  }
  const parent = parentAnchor.parentNode;

  if (!opts || !opts.only) {
    clearExternalSections();

    const visibleSectionsOrdered = [];
    let insertAfter = parentAnchor;

    for (const section of allPanelsBySection) {
      const built = await buildSectionElement(section, ctx);
      if (!built.hasAnyRenderedPanel || !built.el) continue;

      if (insertAfter?.nextSibling) {
        parent.insertBefore(built.el, insertAfter.nextSibling);
      } else {
        parent.appendChild(built.el);
      }
      insertAfter = built.el;
      visibleSectionsOrdered.push({ sectionId: section.sectionId, label: section.label });
    }

    syncNavbarExternalSections(visibleSectionsOrdered);
    enableSmoothScrollAndHighlight();
    return;
  }

  const only = opts.only;

  for (const section of allPanelsBySection) {
    if (!only.has(section.sectionId)) continue;

    const built = await buildSectionElement(section, ctx);
    const existing = document.getElementById(`external_section_${safeId(section.sectionId)}`);

    if (!built.hasAnyRenderedPanel || !built.el) {
      if (existing) existing.remove();
    } else if (existing) {
      existing.replaceWith(built.el);
    } else {
      const extSections = Array.from(document.querySelectorAll(".external-section"));
      const after = extSections[extSections.length - 1] || parentAnchor;
      if (after.nextSibling) {
        parent.insertBefore(built.el, after.nextSibling);
      } else {
        parent.appendChild(built.el);
      }
    }
  }

  const currentVisible = Array.from(document.querySelectorAll(".external-section[id]")).map((el) => {
    const sid = el.id.replace(/^external_section_/, "");
    const orig = allPanelsBySection.find((s) => safeId(s.sectionId) === sid);
    return orig ? { sectionId: orig.sectionId, label: orig.label } : null;
  }).filter(Boolean);

  syncNavbarExternalSections(currentVisible);
}

/**
 * Render opt-in preferences grouped by section.
 * If a checked panel returned 404, append an availability message.
 * @param {HTMLElement} container
 * @returns {void}
 */
function renderExternalPanelsOptinPreferences(container) {
  if (!container) return;

  ensureMapping().then(function onReady() {
    const { categories, country, language, product_type } = globalThis.productData || {};
    const ctx = { categories: categories || [], country, language, product_type };

    let anyItem = false;

    const card = document.createElement("div");
    card.className = "card";
    card.setAttribute(
      "style",
      "background:#fff;margin-top:2em;margin-bottom:2em;padding:2em 2em 1em 2em;"
    );

    for (const section of allPanelsBySection) {
      const scoppablePanels = section.panels.filter(
        (panel) => canSeeByScope(panel) && matchesFilters(panel, ctx)
      );
      if (!scoppablePanels.length) continue;

      anyItem = true;

      const sectionWrap = document.createElement("div");
      sectionWrap.className = "external-pref-section";
      sectionWrap.setAttribute("style", "margin-bottom:2em;");

      const h3 = document.createElement("h3");
      h3.setAttribute("style", "margin-bottom:0.5em;");
      h3.textContent = section.label || prettySectionName(section.sectionId);
      sectionWrap.appendChild(h3);

      for (const panel of scoppablePanels) {
        const row = document.createElement("div");
        row.setAttribute(
          "style",
          "margin-bottom:1em;padding:1em;background:#fff;border-radius:10px;"
        );

        const label = document.createElement("label");
        label.setAttribute("style", "display:flex;gap:.75em;align-items:flex-start;");

        const checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.className = "optin_external_panel";
        checkbox.dataset.panelId = String(panel.id);
        checkbox.dataset.sectionId = String(section.sectionId);
        checkbox.checked = getExternalKnowledgePanelsOptin(section.sectionId, panel.id);
        label.appendChild(checkbox);

        if (panel.icon_url) {
          const icon = document.createElement("img");
          icon.src = panel.icon_url;
          icon.alt = panel.provider_name || panel.name || "";
          icon.setAttribute(
            "style",
            "width:22px;height:22px;object-fit:contain;border-radius:50%;background:#fff;margin-top:2px;"
          );
          label.appendChild(icon);
        }

        const textWrap = document.createElement("span");
        const mainText = document.createElement("span");
        mainText.textContent = panel.description || panel.name || "";
        textWrap.appendChild(mainText);

        if (panel.provider_website || panel.provider_name) {
          const br = document.createElement("br");
          textWrap.appendChild(br);

          const small = document.createElement("small");
          small.textContent = "Provided by ";
          if (panel.provider_website && /^https?:\/\//i.test(panel.provider_website)) {
            const a = document.createElement("a");
            a.href = panel.provider_website;
            a.target = "_blank";
            a.rel = "noopener";
            a.textContent = panel.provider_name || panel.provider_website;
            small.appendChild(a);
          } else if (panel.provider_name) {
            const spanName = document.createElement("span");
            spanName.textContent = panel.provider_name;
            small.appendChild(spanName);
          }
          textWrap.appendChild(small);
        }

        const key = `${section.sectionId}::${panel.id}`;
        if (checkbox.checked && notFoundPanels.has(key)) {
          const msg =
            (typeof globalThis.lang === "function" && globalThis.lang().external_panel_unavailable) ||
            t("panel_unavailable", language);
          const warn = document.createElement("span");
          warn.className = "external-panel-unavailable";
          warn.setAttribute("style", "margin-left:.5rem;font-size:.9em;color:#b20000;");
          warn.textContent = `— ${msg}`;
          textWrap.appendChild(document.createTextNode(" "));
          textWrap.appendChild(warn);
        }

        label.appendChild(textWrap);
        row.appendChild(label);
        sectionWrap.appendChild(row);
      }

      card.appendChild(sectionWrap);
    }

    if (!anyItem) {
      container.innerHTML = "";
      container.style.display = "none";
      return;
    }

    container.style.display = "";
    container.innerHTML = "";
    container.appendChild(card);

    for (const cb of container.querySelectorAll(".optin_external_panel")) {
      cb.addEventListener("change", async function () {
        setExternalKnowledgePanelsOptin(this.dataset.sectionId, this.dataset.panelId, this.checked);
        await renderExternalKnowledgeSections({ only: new Set([this.dataset.sectionId]) });
        renderExternalPanelsOptinPreferences(container);
      });
    }
  });
}

/**
 * Returns true if at least one panel could produce a preference line
 * @returns {Promise<boolean>}
 */
async function hasAnyScoppablePanels() {
  await ensureMapping();
  const pd = globalThis.productData || {};
  const ctx = {
    categories: Array.isArray(pd.categories) ? pd.categories : [],
    country: pd.country,
    language: pd.language,
    product_type: pd.product_type
  };
  for (const section of allPanelsBySection) {
    if (!section || !Array.isArray(section.panels)) continue;
    for (const p of section.panels) {
      if (canSeeByScope(p) && matchesFilters(p, ctx)) return true;
    }
  }
  return false;
}

globalThis.hasAnyScoppablePanels = hasAnyScoppablePanels;
globalThis.renderExternalPanelsOptinPreferences = renderExternalPanelsOptinPreferences;
globalThis.ensureMapping = ensureMapping;
globalThis.allPanelsBySection = allPanelsBySection;
globalThis.canSeeByScope = canSeeByScope;
globalThis.matchesFilters = matchesFilters;

document.addEventListener("DOMContentLoaded", () => {
  renderExternalKnowledgeSections();
});
