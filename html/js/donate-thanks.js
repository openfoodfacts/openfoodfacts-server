/* eslint-disable no-underscore-dangle */

// Matomo tracking
window._paq = window._paq || [];
const paq = window._paq;

/* tracker methods like "setCustomDimension" should be called before "trackPageView" */
paq.push(["setDocumentTitle", document.domain + "/" + document.title]);

// Donorbox puts the donor's name and email on this URL; Matomo gets only the utm_* part
const sanitizedSearch = window.location.search.replace(/[?&](?!utm_)[^&]*/g, "").replace(/^&/, "?");
paq.push(["setCustomUrl", window.location.origin + window.location.pathname + sanitizedSearch]);
paq.push(["setCookieDomain", "*.openfoodfacts.org"]);
paq.push(["setDomains", ["*.openfoodfacts.org"]]);
paq.push(["setDoNotTrack", true]);
paq.push(["disableCookies"]);
paq.push(["enableHeartBeatTimer"]);
paq.push(["trackPageView"]);
paq.push(["enableLinkTracking"]);

function initMatomoTracker() {
  const trackerUrl = "//analytics.openfoodfacts.org/";
  paq.push(["setTrackerUrl", trackerUrl + "matomo.php"]);
  paq.push(["setSiteId", "5"]);

  const scriptEl = document.createElement("script");
  scriptEl.async = true;
  scriptEl.src = trackerUrl + "matomo.js";

  const firstScript = document.getElementsByTagName("script")[0];
  if (firstScript && firstScript.parentNode) {
    firstScript.parentNode.insertBefore(scriptEl, firstScript);
  }
}

initMatomoTracker();

// Donorbox redirect params helper
function intervalFrom(rawInterval) {
  const value = String(rawInterval || "").toLowerCase();

  if ((/month|^1 m$/).test(value)) {
    return "1 M";
  }

  if ((/year|annual|^1 y$/).test(value)) {
    return "1 Y";
  }

  if ((/one|once|^1 t$/).test(value)) {
    return "1 T";
  }

  return "";
}

function setDonateCookie(name, value, days) {
  const expiry = new Date();
  expiry.setTime(expiry.getTime() + (days * 24 * 60 * 60 * 1000));
  const domain = "domain=." + window.location.origin.split(".").slice(1).join(".");
  document.cookie = name + "=" + value + ";expires=" + expiry.toUTCString() + ";" + domain + ";SameSite=None;Secure;path=/";
}

function setupShareButtons(page, shareText, shareLink) {
  const copiedLabel = page.querySelector(".thanks-copied-tpl").textContent;
  const shareButtons = page.querySelectorAll(".thanks-share-btn");
  const shareUrls = {
    mastodon: "https://mastodon.social/share?text=" + encodeURIComponent(shareText),
    bluesky: "https://bsky.app/intent/compose?text=" + encodeURIComponent(shareText),
    linkedin: "https://www.linkedin.com/sharing/share-offsite/?url=" + encodeURIComponent(shareLink)
  };

  for (let i = 0; i < shareButtons.length; i++) {
    const button = shareButtons[i];
    const target = button.getAttribute("data-share");
    if (shareUrls[target]) {
      button.href = shareUrls[target];
    }

    button.addEventListener("click", () => {
      paq.push(["trackEvent", "donation", "share_clicked", target]);
      if (target === "copy" && navigator.clipboard) {
        navigator.clipboard.writeText(shareLink).then(() => {
          button.textContent = copiedLabel;
        });
      }
    });
  }

  page.querySelector(".thanks-share-section").hidden = false;
}

function readSessionStorageFallbacks(initial) {
  const result = {
    amount: initial.amount,
    interval: initial.interval,
    currency: initial.currency,
    source: initial.source
  };

  try {
    if (!(result.amount > 0) && window.sessionStorage.donation_amount) {
      result.amount = Number(window.sessionStorage.donation_amount);
    }
    if (!result.interval && window.sessionStorage.donation_interval) {
      result.interval = intervalFrom(window.sessionStorage.donation_interval);
    }
    if (!result.currency && window.sessionStorage.donation_currency) {
      result.currency = window.sessionStorage.donation_currency;
    }
    if (!result.source && window.sessionStorage.donation_source) {
      result.source = window.sessionStorage.donation_source;
    }
  } catch {

    // SessionStorage may be restricted in some private browsing configurations
  }

  return result;
}

function parseDonationParams() {
  const params = new window.URLSearchParams(window.location.search);
  const name = (params.get("first_name") || "").trim().slice(0, 40);
  const rawAmount = Number(params.get("amount"));
  const rawInterval = intervalFrom(params.get("duration"));
  const rawCurrency = (params.get("currency") || "").toLowerCase();
  const rawSource = params.get("utm_content") || params.get("utm_campaign") || "";

  const fallbacks = readSessionStorageFallbacks({
    amount: rawAmount,
    currency: rawCurrency,
    interval: rawInterval,
    source: rawSource
  });

  const isFrenchHost = (/^fr\./).test(window.location.hostname);
  const isFrenchCountry = (/^(fr|france)$/i).test(params.get("country") || "");

  return {
    amount: fallbacks.amount,
    currency: fallbacks.currency,
    inFrance: isFrenchHost || isFrenchCountry,
    interval: fallbacks.interval,
    name,
    source: fallbacks.source
  };
}

function renderDonationImpact(page, donation, leadTemplates) {
  const amount = donation.amount;
  const interval = donation.interval;
  const currency = donation.currency;
  const source = donation.source;

  if (!Number.isFinite(amount) || amount <= 0 || !interval) {
    return;
  }

  const currencySymbol = currency === "usd" ? "$" : "€";
  const fractionDigits = amount % 1 ? 2 : 0;
  const amountFormatted = amount.toLocaleString("en", {
    maximumFractionDigits: 2,
    minimumFractionDigits: fractionDigits
  });
  const amountText = currencySymbol + amountFormatted;
  const intervalDivisor = interval === "1 Y" ? 12 : 1;
  const lookups = (amount * 250) / intervalDivisor;
  const roundedLookups = Math.round(lookups).toLocaleString("en");

  const templateWithAmount = leadTemplates[interval].replace("{amount}", amountText);
  page.querySelector(".thanks-lead").textContent = templateWithAmount.replace("{lookups}", roundedLookups);

  const upgradeTpl = page.querySelector(".thanks-upgrade-tpl").textContent;
  page.querySelector(".thanks-upgrade-text").textContent = upgradeTpl.replace("{amount}", amountText);

  if (interval === "1 T") {
    page.querySelector(".thanks-upgrade").hidden = false;
    paq.push(["trackEvent", "donation", "upgrade_shown", source || "direct"]);
  }
}

function initDonateThanks() {
  const page = document.getElementById("donate-thanks");
  if (!page) {
    return;
  }

  const donation = parseDonationParams();

  if (window.history && window.history.replaceState) {
    const cleanSearch = window.location.search.replace(/[?&](?!utm_)[^&]*/g, "").replace(/^&/, "?");
    window.history.replaceState(null, "", window.location.pathname + cleanSearch);
  }

  if (donation.name) {
    const title = page.querySelector("h1");
    const titleTemplate = page.querySelector(".thanks-title-tpl").textContent;
    title.textContent = titleTemplate.replace("{name}", () => donation.name);
  }

  const leadTemplates = {};
  const leadTplEls = page.querySelectorAll(".thanks-lead-tpl");
  for (let i = 0; i < leadTplEls.length; i++) {
    leadTemplates[leadTplEls[i].getAttribute("data-interval")] = leadTplEls[i].textContent;
  }

  renderDonationImpact(page, donation, leadTemplates);

  page.querySelector(".thanks-fr").hidden = !donation.inFrance;

  const shareLink = page.querySelector(".thanks-share-link").textContent;
  const shareText = page.querySelector(".thanks-share-text").textContent + " " + shareLink;
  setupShareButtons(page, shareText, shareLink);

  setDonateCookie("donation_done", 1, 365);
  setDonateCookie("donation_march_2026", 1, 365);

  paq.push(["trackEvent", "donation", "thanks_landed", donation.source || "direct"]);
}

initDonateThanks();
