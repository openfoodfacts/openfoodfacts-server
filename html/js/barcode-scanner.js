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
const onBarcodeDetected = (barcode) => {
  const baseUrl = window.location.href.split("/")[0];
  const url =
    baseUrl +
    "/cgi/search.pl?search_terms=" +
    barcode +
    "&search_simple=1&action=process";
  window.location.href = url;
};

// Handle barcode scanner state changes
barcodeScanner.addEventListener("barcode-scanner-state", function (e) {
  document.addEventListener("DOMContentLoaded", function () {
    const barcodeScannerButton = document.getElementById(
      "barcode-scanner-button"
    );
    if (e.detail.state === "detector-available") {
      barcodeScannerButton.parentElement.classList.remove("is_hidden");
    } else if (e.detail.state === "DETECTED") {
      onBarcodeDetected(e.detail.barcode);
    }
  });
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
