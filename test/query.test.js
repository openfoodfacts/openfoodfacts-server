/*global process describe it*/
/*eslint-disable no-unused-expressions,no-process-env*/

const chai = require("chai");
const chaiHttp = require("chai-http");

chai.use(chaiHttp);

const expect = chai.expect;

const protocol = process.env.PRODUCT_OPENER_PROTOCOL || "https";
const domain = process.env.PRODUCT_OPENER_DOMAIN || "productopener.localhost";
const user = process.env.PRODUCT_OPENER_USER || null;
const password = process.env.PRODUCT_OPENER_PASSWORD ||null;

describe("Readiness Tests", () => {
  describe("nginx Tests", () => {
    it("should provide minified CSS", async () => {
      const res = await chai.
        request(`${protocol}://static.${domain}`).
        get("/css/dist/app-ltr.css").
        auth(user, password);
      expect(res).to.have.status(200);
    });

    it("should provide favicon", async () => {
      const res = await chai.
        request(`${protocol}://static.${domain}`).
        get("/images/favicon/favicon.ico").
        auth(user, password);
      expect(res).to.have.status(200);
    });

    it("should provide OFF icon", async () => {
      const res = await chai.
        request(`${protocol}://image.${domain}`).
        get("/images/misc/openfoodfacts-logo-en-178x150.png").
        auth(user, password);
      expect(res).to.have.status(200);
    });
  });

  describe("Apache Tests", () => {
    it("provides basic CGI on world domain", async () => {
      const res = await chai.
        request(`${protocol}://world.${domain}`).
        get("/cgi/manifest.pl").
        auth(user, password);
      expect(res).to.have.status(200);
    });

    it("provides basic CGI on de domain", async () => {
      const res = await chai.
        request(`${protocol}://de.${domain}`).
        get("/cgi/manifest.pl").
        auth(user, password);
      expect(res).to.have.status(200);
    });
  });
});

describe("API Tests", () => {
  describe("Products tests", () => {
    it("Can retrieve product from API v2", async () => {
      const res = await chai.
        request(`${protocol}://world.${domain}`).
        get("/api/v2/product/2000000000001").
        auth(user, password);
      expect(res).to.have.status(200);
      expect(res).to.be.json;
    });
  });
});
