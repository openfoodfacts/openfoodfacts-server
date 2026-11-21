/**
 * Display Open Prices availability on classic product pages.
 */

async function loadOpenPrices() {
  const container = document.getElementById("open-prices-content");
  
  if (!container) {
    return;
  }

  const messages =
    typeof globalThis.lang === "function" ? globalThis.lang() : {};
  const viewLink = document.getElementById("open-prices-view");
  const addLink = document.getElementById("open-prices-add");
  const barcode = window.productData?.code;

  if (!barcode) {
    container.textContent =
      messages.open_prices_unavailable ||
      "Price information is unavailable.";

    return;
  }

  // Configure the links.
  if (viewLink) {
    viewLink.href =
      `https://prices.openfoodfacts.org/products/${encodeURIComponent(barcode)}`;
  }

  if (addLink) {
    const addUrl = new URL(
      "https://prices.openfoodfacts.org/prices/add/multiple",
    );
    addUrl.searchParams.set("code", barcode);
    addLink.href = addUrl.toString();
  }

  try {
    const apiUrl = new URL(
      "https://prices.openfoodfacts.org/api/v1/prices",
    );

    apiUrl.searchParams.set("product_code", barcode);
    apiUrl.searchParams.set("size", "1");

    const response = await fetch(apiUrl.toString());

    if (!response.ok) {
      throw new Error(`Open Prices API returned ${response.status}`);
    }

    const data = await response.json();

    if (typeof data.total !== "number") {
      throw new Error("Invalid Open Prices API response");
    }

    if (data.total > 0) {
      const foundTemplate =
        data.total === 1
          ? messages.open_prices_found_one
          : messages.open_prices_found_many;

      container.textContent = foundTemplate
        ? foundTemplate.replace("{count}", String(data.total))
        : `${data.total} price(s) found for this product.`;

    } else {
      container.textContent =
        messages.open_prices_none ||
        "No prices found for this product. Help us by adding one!";

    }
  } catch (error) {
    container.textContent =
      messages.open_prices_error ||
      "Could not load price information. You can still add a price.";

    console.error("Failed to load Open Prices:", error);
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", loadOpenPrices);
} else {
  loadOpenPrices();
}