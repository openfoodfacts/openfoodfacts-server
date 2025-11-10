/* eslint-env browser, es2021 */
/* global lang */
/* eslint valid-jsdoc: "error" */
/* exported renderExternalPanelsOptinPreferences */

/**
 * External knowledge panels rendering and preferences.
 * - Renders sections and providers strictly in JSON order.
 * - Enforces scope and product filters.
 * - Opt-in stored per (sectionId, panelId) in localStorage, default false.
 * - Hides a panel if its URL returns 404, and shows an availability message next to the opt-in checkbox when checked.
 * - Supports partial rerender by section to avoid full-page flashing.
 *
 * i18n note (temporary):
 * The UI strings should come from the global `lang()` function. This file uses these keys:
 *   - lang().external_panels
 *   - lang().external_panel_unavailable
 *   - lang().external_panel_unavailable_for_product
 *   - lang().external_sources
 *   - lang().provided_by
 * A small local fallback `t(key, lc)` is provided and should be removed once all keys exist in `lang()`.
 */

const allPanelsBySection = [];
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

  return String(str).toLowerCase().replace(/[^a-z0-9_-]/g, "-"); // NOSONAR (regex replace, replaceAll not applicable)
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
 * Small i18n helper for a few UI strings (fallback only).
 * @param {string} key - Translation key.
 * @param {string} lc - Language code (optional).
 * @returns {string} Localized string for the given key or the key name if missing.
 */
function t(key, lc) {
  const lng = (lc ?? globalThis.productData?.language ?? "en").slice(0, 2);
  const dict = {
    en: {
      external_panels: "External Knowledge Panels",
      external_sources: "External sources",
      provided_by: "Provided by",
      panel_unavailable: "Panel unavailable",
      panel_unavailable_for_product: "Panel unavailable for this product",
    },
    fr: {
      external_panels: "Panneaux d’information externes",
      external_sources: "Sources externes",
      provided_by: "Fourni par.",
      panel_unavailable: "Panneau indisponible",
      panel_unavailable_for_product: "Panneau indisponible pour ce produit",
    },
    es: {
      external_panels: "Paneles de información externos",
      external_sources: "Fuentes externas",
      provided_by: "Proporcionado por",
      panel_unavailable: "Panel no disponible",
      panel_unavailable_for_product: "Panel no disponible para este producto",
    },
    de: {
      external_panels: "Externe Informations-Panels",
      external_sources: "Externe Quellen",
      provided_by: "Bereitgestellt von",
      panel_unavailable: "Panel nicht verfügbar",
      panel_unavailable_for_product: "Panel für dieses Produkt nicht verfügbar",
    },
  };

  return dict[lng]?.[key] ?? dict.en[key] ?? key;
}

/**
 * Read localStorage opt-in (true only if explicitly "true").
 * Default false.
 * @param {string} sectionId - Section identifier in which the panel resides.
 * @param {string} panelId - External panel identifier.
 * @returns {boolean} True if the panel is opted in.
 */
function getExternalKnowledgePanelsOptin(sectionId, panelId) {
  const val = globalThis.localStorage?.getItem?.(`external_panel_${sectionId}_${panelId}`);

  return val === "true";
}

/**
 * Set localStorage opt-in value.
 * @param {string} sectionId - Section identifier in which the panel resides.
 * @param {string} panelId - External panel identifier.
 * @param {boolean} enabled - Whether the panel is enabled.
 * @returns {void}
 */
function setExternalKnowledgePanelsOptin(sectionId, panelId, enabled) {
  globalThis.localStorage.setItem(
    `external_panel_${sectionId}_${panelId}`,
    enabled ? "true" : "false",
  );
}

/**
 * Expand URL templates with productData variables.
 * Supported: $code, $lc (language), $cc (country)
 * @param {string} urlTemplate - Template URL.
 * @param {Object} productData - Current product context.
 * @returns {string} Interpolated URL.
 */
function interpolateUrl(urlTemplate, productData) {
  const pd = productData || {};

  return String(urlTemplate
    ).replaceAll("$code", encodeURIComponent(pd.code || "")
    ).replaceAll("$lc", encodeURIComponent(pd.language || "")
    ).replaceAll("$cc", encodeURIComponent(pd.country || ""));
}

/**
 * Scope checking: public | users | moderators.
 * - users: logged-in users AND moderators
 * - moderators: moderators only
 * @param {Object} panel - Panel descriptor.
 * @returns {boolean} True if current viewer can see the panel given its scope.
 */
function canSeeByScope(panel) {
  const scope = panel.scope || "public";
  const isModerator = globalThis?.isModerator === 1;
  const isUser = Number(globalThis?.isUser) === 1;

  return (
    scope === "public" ||
    (scope === "users" && (isUser || isModerator)) ||
    (scope === "moderators" && isModerator)
  );
}

/**
 * Filter matching against current product context.
 * categories: at least one match (unless opts.ignoreCategory)
 * country/language/product_type: strict equality
 * @param {Object} panel - Panel descriptor.
 * @param {Object} ctx - Filtering context {categories,country,language,product_type}.
 * @param {Object} opts - Options {ignoreCategory?: boolean}. If ignoreCategory, category mismatch is ignored.
 * @returns {boolean} True if the panel matches filters.
 */
function matchesFilters(panel, ctx, opts) {
  const f = panel.filters || {};
  const ignoreCategory = Boolean(opts?.ignoreCategory);

  const catOk = ignoreCategory
    ? true
    : !f.categories?.length || f.categories.some((c) => ctx.categories.includes(c));
  const countryOk = !f.countries?.length || (ctx.country ? f.countries.includes(ctx.country) : true);
  const langOk = !f.languages?.length || (ctx.language ? f.languages.includes(ctx.language) : true);
  const typeOk =
    !f.product_types?.length || (ctx.product_type ? f.product_types.includes(ctx.product_type) : true);

  return catOk && countryOk && langOk && typeOk;
}

/**
 * Visibility for a panel (scope + filters + opt-in).
 * Strict filters. No ignoreCategory here.
 * @param {string} sectionId - Section identifier.
 * @param {Object} panel - Panel descriptor.
 * @param {Object} ctx - Filtering context.
 * @returns {boolean} True if the panel is visible.
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
 * @param {string} url - URL to check.
 * @returns {Promise<boolean>} Resolves true if available (non-404 or opaque), false if 404.
 */
async function isPanelAvailable(url) {
  if (!url) {

    return true;
  }

  if (availabilityCache.has(url)) {
    const status = availabilityCache.get(url)?.status;

    return status !== 404;
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
  } catch (e) {
    // eslint-disable-next-line no-console
    console.debug("HEAD check failed for external panel", { url, error: e });
  }

  try {
    const get = await fetch(url, { method: "GET", mode: "cors" });
    if (get.status === 404) {
      availabilityCache.set(url, { checkedAt: Date.now(), status: 404 });

      return false;
    }
    if (get.type !== "opaque" && get.status) {
      availabilityCache.set(url, { checkedAt: Date.now(), status: get.status });
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.debug("GET check failed for external panel, treating as available", { url, error: e });
  }

  return true;
}

/**
 * Fetch external sources (translated) and build ordered sections mapping.
 * @returns {Promise<void>} Resolves when mapping is ready.
 */
async function loadPanelsMapping() {
  const lc = globalThis.productData?.language ?? "en";
  const resp = await fetch(`/api/v3/external_sources?lc=${encodeURIComponent(lc)}`);
  if (!resp.ok) {
    throw new Error("Failed to load external sources");
  }

  const raw = await resp.json();

  // Flexible parsing: array or wrapped {status, external_sources, errors}
  let sources = [];
  if (Array.isArray(raw)) {
    sources = raw;
  } else if (Array.isArray(raw?.external_sources)) {
    sources = raw.external_sources;
  } // else keep []

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
 * Inserts external section links right after the “Environment” link,
 * falling back to “Your criteria” then “Product” if needed.
 * @param {Array<{sectionId:string,label:string}>} visibleSectionsOrdered - Sections in order.
 * @returns {void}
 */
function syncNavbarExternalSections(visibleSectionsOrdered) {
  const navbar = document.querySelector("#navbar ul.inline-list");
  if (!navbar) {

    return;
  }

  for (const link of navbar.querySelectorAll("a[href^='#external_section_']")) {
    link.parentElement?.remove();
  }

  const after =
    navbar.querySelector('[href="#environment"]')?.parentElement ??
    navbar.querySelector('[href="#match"]')?.parentElement ??
    navbar.querySelector('[href="#product"]')?.parentElement ??
    null;

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
 * Smooth scroll + active link highlight with event delegation.
 * Idempotent binding using dataset flags.
 * @returns {void}
 */
function enableSmoothScrollAndHighlight() {
  const navbar = document.querySelector("#navbar ul.inline-list");
  if (!navbar) {

    return;
  }

  if (!navbar.dataset.smoothBound) {
    navbar.addEventListener("click", function (e) {
      const a = e.target.closest("a.nav-link");
      if (!a || !this.contains(a)) {
        return;
      }

      const hash = a.getAttribute("href");
      const target = hash?.startsWith("#") ? document.querySelector(hash) : null;
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: "smooth" });

        for (const l of this.querySelectorAll(".nav-link")) {
          l.classList.remove("active");
        }
        a.classList.add("active");
      }
    });
    navbar.dataset.smoothBound = "1";
  }

  if (!globalThis.scrollSpyBoundExtPanels) {
    globalThis.addEventListener(
      "scroll",
      function () {
        const sections = Array.from(document.querySelectorAll("section[id]"));
        const scrollY = globalThis.scrollY + 100;
        let currentId = "";
        for (const section of sections) {
          if (section.offsetTop <= scrollY) {
            currentId = section.id;
          }
        }
        if (currentId) {
          for (const link of navbar.querySelectorAll(".nav-link")) {
            link.classList.toggle("active", link.getAttribute("href") === `#${currentId}`);
          }
        }
      },
      { passive: true },
    );
    globalThis.scrollSpyBoundExtPanels = true;
  }
}

/**
 * Ensure mapping is loaded.
 * @returns {Promise<void>} Resolves when mapping is available.
 */
function ensureMapping() {
  if (allPanelsBySection.length) {
    return Promise.resolve();
  }
  if (mappingPromise) {
    return mappingPromise;
  }
  mappingPromise = loadPanelsMapping().finally(() => {
    mappingPromise = null;
  });

  return mappingPromise;
}

/**
 * Append "Provided by …" inline block to a summary/label.
 * @param {HTMLElement} summaryEl - Parent element where to append.
 * @param {Object} panel - Panel descriptor.
 * @param {string} language - Language code.
 * @returns {void}
 */
function appendProvidedByInline(summaryEl, panel, language) {
  const providedByText =
    (typeof globalThis.lang === "function" && lang().provided_by) || t("provided_by", language);

  const sep = document.createElement("span");
  sep.className = "provider-sep";
  sep.textContent = " · ";
  summaryEl.appendChild(sep);

  const small = document.createElement("small");
  small.className = "provider-by";
  small.textContent = `${providedByText} `;

  if ((/^https?:\/\//i).test(panel.provider_website ?? "")) {
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
  summaryEl.appendChild(small);
}

/**
 * Build and append the inner content of a provider card when available.
 * @param {HTMLElement} details - html of the panel
 * @param {string} url - url to fetch
 * @returns {void}
 */
function appendKnowledgePanel(details, url) {
  const kp = document.createElement("knowledge-panels");
  kp.setAttribute("url", url);
  kp.setAttribute("path", "panels");
  kp.setAttribute("heading-level", "h4");
  details.appendChild(kp);
}

/**
 * Render one external section. Only if it has at least 1 visible panel.
 * Adds “(BETA)” to the section title. Adds “Provided by …” in the provider header.
 * @param {{sectionId:string,label:string,panels:Array}} section - Section to render.
 * @param {Object} ctx - Filtering context.
 * @returns {Promise<{sectionId:string,el:HTMLElement|null,hasAnyRenderedPanel:boolean}>} Render result.
 */
/* eslint-disable complexity */
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
  sectionTitle.textContent = `${section.label || ""} (BETA)`;
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

    const providerPanelName = document.createElement("span");
    providerPanelName.className = "provider-panel-name";
    providerPanelName.textContent = panel.name || panel.provider_name || "";
    summary.appendChild(providerPanelName);

    if (panel.description) {
      const providerDesc = document.createElement("span");
      providerDesc.className = "provider-desc";
      providerDesc.textContent = panel.description;
      summary.appendChild(providerDesc);
    }

    if (panel.provider_website || panel.provider_name) {
      appendProvidedByInline(summary, panel, globalThis.productData?.language);
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

    // eslint-disable-next-line no-await-in-loop
    const available = availabilityCache.has(url)
      ? availabilityCache.get(url).status !== 404
      : await isPanelAvailable(url);

    if (!available) {
      notFoundPanels.add(key);
      // skip rendering this provider entirely
      continue;
    }

    notFoundPanels.delete(key);
    appendKnowledgePanel(details, url);
    providerCard.appendChild(details);
    cardSection.appendChild(providerCard);
    hasAnyRenderedPanel = true;
  }

  if (!hasAnyRenderedPanel) {

    return { sectionId: section.sectionId, el: null, hasAnyRenderedPanel: false };
  }

  return { sectionId: section.sectionId, el: sectionDiv, hasAnyRenderedPanel: true };
}
/* eslint-enable complexity */

/**
 * Full render path.
 * @param {HTMLElement} parent - Parent container.
 * @param {HTMLElement} parentAnchor - Anchor node to insert after.
 * @param {Object} ctx - Filtering context.
 * @returns {Promise<void>} - render promise
 */
async function renderFull(parent, parentAnchor, ctx) {
  clearExternalSections();
  const visible = [];
  let insertAfter = parentAnchor;
  for (const section of allPanelsBySection) {
    // eslint-disable-next-line no-await-in-loop
    const built = await buildSectionElement(section, ctx);
    if (!built.hasAnyRenderedPanel || !built.el) {
      continue;
    }
    if (insertAfter?.nextSibling) {
      parent.insertBefore(built.el, insertAfter.nextSibling);
    }
    else {
      parent.appendChild(built.el);
    }
    insertAfter = built.el;
    visible.push({ sectionId: section.sectionId, label: section.label });
  }
  syncNavbarExternalSections(visible);
  enableSmoothScrollAndHighlight();
}

/**
 * Partial render path.
 * @param {HTMLElement} parent - Parent container.
 * @param {HTMLElement} parentAnchor - Anchor node.
 * @param {Object} ctx - Filtering context.
 * @param {Set<string>} onlySet - Section ids to re-render.
 * @returns {Promise<void>} - promise
 */
async function renderPartial(parent, parentAnchor, ctx, onlySet) {
  for (const section of allPanelsBySection) {
    if (!onlySet.has(section.sectionId)) {
      continue;
    }
    // eslint-disable-next-line no-await-in-loop
    const built = await buildSectionElement(section, ctx);
    const existing = document.getElementById(`external_section_${safeId(section.sectionId)}`);
    if (!built.hasAnyRenderedPanel || !built.el) {
      if (existing) {
        existing.remove();
      }
      continue;
    }
    if (existing) {
      existing.replaceWith(built.el);
    } else {
      const extSections = Array.from(document.querySelectorAll(".external-section"));
      const after = extSections.at(-1) || parentAnchor;
      if (after?.nextSibling) {
        parent.insertBefore(built.el, after.nextSibling);
      } else {
        parent.appendChild(built.el);
      }
    }
  }
  const currentVisible = Array.from(document.querySelectorAll(".external-section[id]")
    ).map((el) => {
      const id = el.id;
      const prefix = "external_section_";
      const sid = id.startsWith(prefix) ? id.slice(prefix.length) : id;
      const orig = allPanelsBySection.find((s) => safeId(s.sectionId) === sid);

      return orig ? { sectionId: orig.sectionId, label: orig.label } : null;
    }
    ).filter(Boolean);
  syncNavbarExternalSections(currentVisible);
  enableSmoothScrollAndHighlight();
}

/**
 * Render external sections. Full render by default.
 * Pass {only: Set<sectionId>} to rerender only specific sections.
 * Places the sections after the “Environment” section, falling back to
 * “Your criteria” or the first <section> if #environment is missing.
 *
 * @param {Object} opts - Options for partial rerender.
 * @returns {Promise<void>} Resolves when render is complete.
 */
async function renderExternalKnowledgeSections(opts) {
  await ensureMapping();

  const { categories, country, language, product_type } = globalThis.productData || {};
  const ctx = { categories: categories || [], country, language, product_type };

  const parentAnchor =
    document.getElementById("environment") ||
    document.getElementById("match") ||
    document.querySelector("section.row");

  if (!parentAnchor?.parentNode) {
    // eslint-disable-next-line no-console
    console.error("Cannot find anchor section to insert external panels");

    return;
  }
  const parent = parentAnchor.parentNode;

  const only = opts?.only;
  if (only) {
    await renderPartial(parent, parentAnchor, ctx, only);
  } else {
    await renderFull(parent, parentAnchor, ctx);
  }
}

/**
 * Build one preference row for a single panel.
 * Adds availability and category-mismatch notices.
 * @param {Object} section - section for the panel
 * @param {Object} panel - specific external sources information
 * @param {Object} ctx - context, for example the product page
 * @param {string} language - language code
 * @returns {HTMLElement} row element
 */
function buildPreferenceRow(section, panel, ctx, language) {
  const row = document.createElement("div");
  row.setAttribute("style", "margin-bottom:1em;padding:1em;background:#fff;border-radius:10px;");

  const labelEl = document.createElement("label");
  labelEl.setAttribute("style", "display:flex;gap:.75em;align-items:flex-start;");

  const checkbox = document.createElement("input");
  checkbox.type = "checkbox";
  checkbox.className = "optin_external_panel";
  checkbox.dataset.panelId = String(panel.id);
  checkbox.dataset.sectionId = String(section.sectionId);
  checkbox.checked = getExternalKnowledgePanelsOptin(section.sectionId, panel.id);
  labelEl.appendChild(checkbox);

  if (panel.icon_url) {
    const icon = document.createElement("img");
    icon.src = panel.icon_url;
    icon.alt = panel.provider_name || panel.name || "";
    icon.setAttribute(
      "style",
      "width:22px;height:22px;object-fit:contain;border-radius:50%;background:#fff;margin-top:2px;",
    );
    labelEl.appendChild(icon);
  }

  const textWrap = document.createElement("span");
  const mainText = document.createElement("span");
  mainText.textContent = panel.description || panel.name || "";
  textWrap.appendChild(mainText);

  if (panel.provider_website || panel.provider_name) {
    appendProvidedByInline(textWrap, panel, language);
  }

  // Availability notice when checked but 404
  const key = `${section.sectionId}::${panel.id}`;
  if (checkbox.checked && notFoundPanels.has(key)) {
    const msg = (typeof globalThis.lang === "function" && lang().external_panel_unavailable) || t("panel_unavailable", language);
    const warn = document.createElement("span");
    warn.className = "external-panel-unavailable";
    warn.setAttribute("style", "margin-left:.5rem;font-size:.9em;color:#b20000;");
    warn.textContent = `— ${msg}`;
    textWrap.appendChild(document.createTextNode(" "));
    textWrap.appendChild(warn);
  }

  // Category mismatch notice for the list only
  const f = panel.filters || {};
  const categoryMatches = !f.categories?.length || f.categories.some((c) => ctx.categories.includes(c));
  if (!categoryMatches) {
    const msgCat =
      (typeof globalThis.lang === "function" && lang().external_panel_unavailable_for_product) ||
      t("panel_unavailable_for_product", language);
    const warnCat = document.createElement("span");
    warnCat.className = "external-panel-unavailable-for-product";
    warnCat.setAttribute("style", "margin-left:.5rem;font-size:.9em;color:#b20000;");
    warnCat.textContent = `— ${msgCat}`;
    textWrap.appendChild(document.createTextNode(" "));
    textWrap.appendChild(warnCat);
  }

  labelEl.appendChild(textWrap);
  row.appendChild(labelEl);

  return row;
}

/**
 * Render opt-in preferences grouped by section.
 * If a checked panel returned 404, append an availability message.
 * Also show a per-line notice if category does not match the current product.
 * Category filter is relaxed here to show all potentially relevant lines.
 * @param {HTMLElement} container - Target element to render into.
 * @returns {void}
 */
/* eslint-disable complexity */
function renderExternalPanelsOptinPreferences(container) {
  if (!container) {
    return;
  }

  ensureMapping().then(function onReady() {
    const { categories, country, language, product_type } = globalThis.productData || {};
    const ctx = { categories: categories || [], country, language, product_type };

    let anyItem = false;

    const card = document.createElement("div");
    card.className = "card";
    card.setAttribute("style", "background:#fff;margin-top:2em;margin-bottom:2em;padding:2em 2em 1em 2em;");

    for (const section of allPanelsBySection) {
      // Relax category only for the list
      const scoppablePanels = section.panels.filter(
        (panel) => canSeeByScope(panel) && matchesFilters(panel, ctx, { ignoreCategory: true }),
      );
      if (scoppablePanels.length) {
        anyItem = true;

        const sectionWrap = document.createElement("div");
        sectionWrap.className = "external-pref-section";
        sectionWrap.setAttribute("style", "margin-bottom:2em;");

        const h3 = document.createElement("h3");
        h3.setAttribute("style", "margin-bottom:0.5em;");
        h3.textContent = section.label || prettySectionName(section.sectionId);
        sectionWrap.appendChild(h3);

        for (const panel of scoppablePanels) {
          const row = buildPreferenceRow(section, panel, ctx, language);
          sectionWrap.appendChild(row);
        }

        card.appendChild(sectionWrap);
      }
    }

    if (anyItem) {
      container.style.display = "";
      container.innerHTML = "";
      container.appendChild(card);

      const cbs = container.querySelectorAll?.(".optin_external_panel") ?? [];
      for (const cb of cbs) {
        cb.addEventListener("change", async function onChange() {
          setExternalKnowledgePanelsOptin(this.dataset?.sectionId, this.dataset?.panelId, this.checked);
          await renderExternalKnowledgeSections({ only: new Set([this.dataset?.sectionId]) });
          renderExternalPanelsOptinPreferences(container);
        });
      }
    } else {
      container.innerHTML = "";
      container.style.display = "none";
    }
  });
}
/* eslint-enable complexity */

/**
 * Returns true if at least one panel could produce a preference line.
 * Category filter is relaxed here.
 * @returns {Promise<boolean>} Resolves true if any panel can be listed in preferences.
 */
async function hasAnyScoppablePanels() {
  await ensureMapping();
  const pd = globalThis.productData || {};
  const ctx = {
    categories: Array.isArray(pd.categories) ? pd.categories : [],
    country: pd.country,
    language: pd.language,
    product_type: pd.product_type,
  };

  for (const section of allPanelsBySection) {
    if (section && Array.isArray(section.panels)) {
      for (const p of section.panels) {
        if (canSeeByScope(p) && matchesFilters(p, ctx, { ignoreCategory: true })) {
          return true;
        }
      }
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
