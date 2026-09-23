function doGet() {
  return HtmlService.createHtmlOutputFromFile('Pay_at_PU')
    .setTitle('Pay at Pickup - OL y OL CF Dashboard')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}
