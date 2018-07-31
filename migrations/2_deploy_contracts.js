var ARPToken = artifacts.require("ARPToken");
var ARPTeamHolding = artifacts.require("ARPTeamHolding");
var ARPHolding = artifacts.require("ARPHolding.sol");
var ARPMidTermHolding = artifacts.require("ARPMidTermHolding");
var ARPLongTermHolding = artifacts.require("ARPLongTermHolding");
var ARPHoldingWalletCreator = artifacts.require("ARPHoldingWalletCreator");

module.exports = function (deployer, network, accounts) {
  if (network == "development") {
    deployer.deploy(ARPToken).then(function () {
      var now = (new Date()).getTime() / 1000;
      var startTime = now - 60 * 60 * 24 * 365 * 2;
      startTime += 60 * 5; // 5 minutes delay for test

      deployer.deploy(
        ARPTeamHolding,
        ARPToken.address,
        accounts[0],
        startTime
      );

      startTime = now - 60 * 60 * 24 * 365;
      startTime += 60 * 5; // 5 minutes delay for test
      deployer.deploy(
        ARPHolding,
        ARPToken.address,
        accounts[0],
        startTime
      );

      deployer.deploy(
        ARPMidTermHolding,
        ARPToken.address,
        now
      ).then(function () {
        deployer.deploy(
          ARPLongTermHolding,
          ARPToken.address,
          now
        ).then(function () {
          deployer.deploy(
            ARPHoldingWalletCreator,
            ARPToken.address,
            ARPMidTermHolding.address,
            ARPLongTermHolding.address
          );
        });
      });
    });
  }
};
