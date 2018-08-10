var ARPToken = artifacts.require("ARPToken");
var ARPTeamHolding = artifacts.require("ARPTeamHolding");
var ARPMidTermHolding = artifacts.require("ARPMidTermHolding");
var ARPLongTermHolding = artifacts.require("ARPLongTermHolding");
var ARPHoldingWalletCreator = artifacts.require("ARPHoldingWalletCreator");
var ARPHolding = artifacts.require("ARPHolding");
var ARPWallet = artifacts.require("ARPWallet");
var ARPMultiTransferer = artifacts.require("ARPMultiTransferer");
var ARPRegistry = artifacts.require("ARPRegistry");
var ARPBank = artifacts.require("ARPBank");

const SECONDS_PER_DAY = 60 * 60 * 24;
const SECONDS_PER_YEAR = SECONDS_PER_DAY * 365;

module.exports = function(deployer, network, accounts) {
  if (network == "development") {
    var now = (new Date()).getTime() / 1000;
    var beneficiary = accounts[0];

    deployer.deploy(ARPToken).then(function() {
      // 5 minutes delay for test
      var delay = SECONDS_PER_YEAR * 2;
      var startTime = now - delay;
      startTime += 60 * 5;

      return deployer.deploy(
        ARPTeamHolding,
        ARPToken.address,
        beneficiary,
        startTime
      );
    }).then(function() {
      return deployer.deploy(
        ARPMidTermHolding,
        ARPToken.address,
        now
      );
    }).then(function() {
      return deployer.deploy(
        ARPLongTermHolding,
        ARPToken.address,
        now
      );
    }).then(function() {
      return deployer.deploy(
        ARPHoldingWalletCreator,
        ARPToken.address,
        ARPMidTermHolding.address,
        ARPLongTermHolding.address
      );
    }).then(function() {
      // 5 minutes delay for test
      var delay = SECONDS_PER_YEAR;
      var startTime = now - delay;
      startTime += 60 * 5;

      return deployer.deploy(
        ARPHolding,
        ARPToken.address,
        beneficiary,
        startTime
      );
    }).then(function() {
      return deployer.deploy(
        ARPWallet,
        0x0
      );
    }).then(function() {
      return deployer.deploy(
        ARPMultiTransferer,
        0x0
      );
    }).then(function() {
      return deployer.deploy(
        ARPRegistry,
        ARPToken.address
      );
    }).then(function() {
      return deployer.deploy(
        ARPBank,
        ARPToken.address
      );
    });
  }
};
