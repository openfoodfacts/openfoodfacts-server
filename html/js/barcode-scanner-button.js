// Barcode Scanner Button
document.addEventListener("DOMContentLoaded", function () {
  // Get references to the barcode scanner button and scanner element
  const barcodeScannerButton = document.getElementById(
    "barcode-scanner-button"
  );
  const barcodeScanner = document.querySelector("barcode-scanner");

  // Handle barcode scanner button click
  barcodeScannerButton.addEventListener("click", function () {
    // Remove the hidden class from the barcode scanner parent element
    barcodeScanner.parentElement.classList.remove("is_hidden");
  });

  // Handle barcode scanner button click
  barcodeScannerButton.addEventListener("click", function () {
    // Remove the hidden class from the barcode scanner parent element
    barcodeScanner.parentElement.classList.remove("is_hidden");
  });
});
