// Barcode Scanner Modal
const barcodeScanner = document.querySelector("barcode-scanner");
const barcodeScannerModal = document.getElementById("barcode-scanner-modal");
const barcodeCloseButton = barcodeScannerModal.querySelector(
  ".modal-close-button"
);

// Get references to the barcode modal button and input
const barcodeModalButton = document.getElementById("barcode-modal-button");
const barcodeModalInput = document.getElementById("barcode-modal-input");

// Enable the barcode modal button when input is entered
barcodeModalInput.addEventListener("input", function () {
  const barcode = barcodeModalInput.value;
  barcodeModalButton.disabled = !barcode;
});

// Handle barcode modal button click
barcodeModalButton.addEventListener("click", function () {
  const barcode = barcodeModalInput.value;
  if (barcode) {
    onBarcodeDetected(barcode);
  }
});

// Function to handle barcode detection
function onBarcodeDetected(barcode) {
  // Support complex GS1 barcodes (DataMatrix/QR payloads may include parentheses,
  // FNC1 (ASCII 29), or other characters). Avoid stripping GS1-specific
  // characters; only remove dangerous control chars that could break headers
  // or logs (CR/LF/NUL). Use the URL API to build the redirect safely.
  function removeControlChars(str) {
    return Array.from(String(str)).filter((ch) => {
      const code = ch.charCodeAt(0);

      return code !== 0 && code !== 10 && code !== 13;
    }).join('');
  }

  const sanitized = removeControlChars(barcode).trim();
  const redirectUrl = new URL('/cgi/search.pl', window.location.origin);
  // URLSearchParams will percent-encode the value as needed.
  redirectUrl.searchParams.set('search_terms', sanitized);
  redirectUrl.searchParams.set('search_simple', '1');
  redirectUrl.searchParams.set('action', 'process');
  window.location.href = redirectUrl.toString();
}

// Handle barcode scanner state changes
barcodeScanner.addEventListener("barcode-scanner-state", function (e) {
  const barcodeScannerButton = document.getElementById(
    "barcode-scanner-button"
  );
  if (e.detail.state === "detector-available") {
    barcodeScannerButton.parentElement.classList.remove("is_hidden");
  } else if (e.detail.state === "detected") {
    onBarcodeDetected(e.detail.barcode);
  }
});

// Handle barcode close button click
barcodeCloseButton.addEventListener("click", function () {
  document.getElementById("barcode-scanner-modal").classList.add("is_hidden");
});

// Function to open the barcode scanner modal
function openModal() {
  barcodeScannerModal.classList.remove("is_hidden");
  barcodeScanner.setAttribute("run-scanner", true);
}

// Initialize the barcode scanner button
document.addEventListener("DOMContentLoaded", function () {
  const barcodeScannerButton = document.getElementById(
    "barcode-scanner-button"
  );
  barcodeScannerButton.addEventListener("click", openModal);
});
