const synthetics = require("@aws/synthetics-core");
const log = require("SyntheticsLogger");

const requestOptions = {
  hostname: "${api_hostname}",
  method: "GET",
  path: "/healthz",
  port: "443",
  protocol: "https:",
  headers: {
    "User-Agent": "giftgen-api-canary",
  },
};

const validateSuccessfulResponse = async (response) => {
  if (response.statusCode !== 200) {
    throw new Error("Expected 200 response but received " + response.statusCode);
  }
};

exports.handler = async () => {
  log.info("Checking https://${api_hostname}/healthz");
  return synthetics.executeHttpStep("giftgen-api-healthz", requestOptions, validateSuccessfulResponse);
};
