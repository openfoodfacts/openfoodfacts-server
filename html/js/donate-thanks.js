// Matomo tracking
var _paq = window._paq = window._paq || [];
/* tracker methods like "setCustomDimension" should be called before "trackPageView" */
_paq.push(["setDocumentTitle", document.domain + "/" + document.title]);
// Donorbox puts the donor's name and email on this URL; Matomo gets only the utm_* part
_paq.push(["setCustomUrl", location.origin + location.pathname + location.search.replace(/[?&](?!utm_)[^&]*/g, "").replace(/^&/, "?")]);
_paq.push(["setCookieDomain", "*.openfoodfacts.org"]);
_paq.push(["setDomains", ["*.openfoodfacts.org"]]);
_paq.push(["setDoNotTrack", true]);
_paq.push(["disableCookies"]);
_paq.push(['enableHeartBeatTimer']);
_paq.push(['trackPageView']);
_paq.push(['enableLinkTracking']);
(function() {
  var u="//analytics.openfoodfacts.org/";
  _paq.push(['setTrackerUrl', u+'matomo.php']);
  _paq.push(['setSiteId', '5']);
  var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
  g.async=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
})();

// Donorbox redirect params (id, first_name, last_name, email, amount, currency, country, duration;
// Pro/Premium or the Tracking add-on, help centre checked 2026-09-18). duration values are
// undocumented, hence the loose match.
(function () {
  var params = new URLSearchParams(location.search);
  var page = document.getElementById('donate-thanks');
  if (!page) return;
  var title = page.querySelector('h1');
  var titleTemplate = page.querySelector('.thanks-title-tpl').textContent;
  var lead = page.querySelector('.thanks-lead');
  var leadTemplates = {};
  var leadTplEls = page.querySelectorAll('.thanks-lead-tpl');
  var i;
  for (i = 0; i < leadTplEls.length; i++) {
    leadTemplates[leadTplEls[i].getAttribute('data-interval')] = leadTplEls[i].textContent;
  }
  var LOOKUPS_PER_UNIT = 250;

  function intervalFrom(value) {
    value = String(value || '').toLowerCase();
    if (/month|^1 m$/.test(value)) {
      return '1 M';
    }
    if (/year|annual|^1 y$/.test(value)) {
      return '1 Y';
    }
    if (/one|once|^1 t$/.test(value)) {
      return '1 T';
    }
    return '';
  }

  var name = (params.get('first_name') || '').trim().slice(0, 40);
  var amount = Number(params.get('amount'));
  var interval = intervalFrom(params.get('duration'));
  var currency = (params.get('currency') || '').toLowerCase();
  var inFrance = /^fr\./.test(location.hostname) || /^(fr|france)$/i.test(params.get('country') || '');
  var source = params.get('utm_content') || params.get('utm_campaign') || '';
  try {
    if (!(amount > 0)) {
      amount = Number(sessionStorage.donation_amount);
    }
    if (!interval) {
      interval = intervalFrom(sessionStorage.donation_interval);
    }
    if (!currency) {
      currency = sessionStorage.donation_currency || '';
    }
    if (!source) {
      source = sessionStorage.donation_source || '';
    }
  } catch (e) {}
  history.replaceState(null, '', location.pathname + location.search.replace(/[?&](?!utm_)[^&]*/g, '').replace(/^&/, '?'));

  if (name) {
    title.textContent = titleTemplate.replace('{name}', function () { return name; });
  }
  if (isFinite(amount) && amount > 0 && interval) {
    var amountText = (currency === 'usd' ? '$' : '€') + amount.toLocaleString('en', { minimumFractionDigits: amount % 1 ? 2 : 0, maximumFractionDigits: 2 });
    var lookups = amount * LOOKUPS_PER_UNIT / (interval === '1 Y' ? 12 : 1);
    lead.textContent = leadTemplates[interval]
      .replace('{amount}', amountText)
      .replace('{lookups}', Math.round(lookups).toLocaleString('en'));
    page.querySelector('.thanks-upgrade-text').textContent = page.querySelector('.thanks-upgrade-tpl').textContent.replace('{amount}', amountText);
    if (interval === '1 T') {
      page.querySelector('.thanks-upgrade').hidden = false;
      _paq.push(['trackEvent', 'donation', 'upgrade_shown', source || 'direct']);
    }
  }
  page.querySelector('.thanks-fr').hidden = !inFrance;

  var shareLink = page.querySelector('.thanks-share-link').textContent;
  var shareText = page.querySelector('.thanks-share-text').textContent + ' ' + shareLink;
  var copiedLabel = page.querySelector('.thanks-copied-tpl').textContent;
  var shareButtons = page.querySelectorAll('.thanks-share-btn');
  var shareUrls = {
    mastodon: 'https://mastodon.social/share?text=' + encodeURIComponent(shareText),
    bluesky: 'https://bsky.app/intent/compose?text=' + encodeURIComponent(shareText),
    linkedin: 'https://www.linkedin.com/sharing/share-offsite/?url=' + encodeURIComponent(shareLink)
  };
  for (i = 0; i < shareButtons.length; i++) {
    var target = shareButtons[i].getAttribute('data-share');
    if (shareUrls[target]) {
      shareButtons[i].href = shareUrls[target];
    }
    shareButtons[i].addEventListener('click', function (event) {
      var button = event.currentTarget;
      _paq.push(['trackEvent', 'donation', 'share_clicked', button.getAttribute('data-share')]);
      if (button.getAttribute('data-share') === 'copy') {
        var copyLabel = button.textContent;
        if (!navigator.clipboard) {
          window.prompt(copyLabel, shareLink);
          return;
        }
        navigator.clipboard.writeText(shareLink).then(function () {
          button.textContent = copiedLabel;
        }, function () {
          window.prompt(copyLabel, shareLink);
        });
      }
    });
  }
  page.querySelector('.thanks-share-section').hidden = false;

  function setDonateCookie(name, value, days) {
    var expiry = new Date();
    expiry.setTime(expiry.getTime() + days * 24 * 60 * 60 * 1000);
    var domain = 'domain=.' + location.origin.split('.').slice(1).join('.');
    document.cookie = name + '=' + value + ';expires=' + expiry.toUTCString() + ';' + domain + ';SameSite=None;Secure;path=/';
  }
  setDonateCookie('donation_done', 1, 365);
  setDonateCookie('donation_march_2026', 1, 365);

  _paq.push(['trackEvent', 'donation', 'thanks_landed', source || 'direct']);
})();
