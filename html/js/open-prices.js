/**
 * Display Open Prices availability on classic product pages.
 */

async function loadOpenPrices() {
  const container = document.getElementById("open-prices-content");

  if (!container) {
    return;
  }

  const barcode = window.productData?.code;

  if (!barcode) {
    container.textContent = "Price information is unavailable.";

    return;
  }

  const viewLink = document.getElementById("open-prices-view");
  const addLink = document.getElementById("open-prices-add");

  if (viewLink) {
    viewLink.href = `https://prices.openfoodfacts.org/products/${encodeURIComponent(barcode)}`;
  }

  if (addLink) {
    const url = new URL("https://prices.openfoodfacts.org/prices/add/multiple");
    url.searchParams.set("code", barcode);
    addLink.href = url.toString();
  }

  try {
    const url = new URL("https://prices.openfoodfacts.org/api/v1/prices");
    url.searchParams.set("product_code", barcode);
    url.searchParams.set("size", "1");

    const response = await fetch(url.toString());

    if (!response.ok) {
      throw new Error(`Open Prices API returned ${response.status}`);
    }

    const data = await response.json();

    if (typeof data.total !== "number") {
      throw new Error("Invalid Open Prices API response");
    }

    if (data.total > 0) {
      container.textContent =
        `${data.total} price(s) found for this product.`;
    } else {
      container.textContent =
        "No prices found for this product. Help us by adding one!";
    }
  } catch (error) {
    container.textContent =
      "Could not load price information. You can still visit Open Prices.";
    console.error("Failed to load Open Prices:", error);
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", loadOpenPrices);
} else {
  loadOpenPrices();
}
