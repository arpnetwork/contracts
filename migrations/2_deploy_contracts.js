var ARPToken = artifacts.require("./ARPToken.sol");
var ARPTeamHolding = artifacts.require("./ARPTeamHolding.sol");

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
    });
  } else if (network == "live") {
    var arpToken = "0xbeb6fdf4ef6ceb975157be43cbe0047b248a8922";
    var beneficiary = "0x1fafd10cea9d705ee1f37b575987ad0890889121";
    var startTime = 1525132800; // 2018-05-01 00:00:00 UTC

    deployer.deploy(
      ARPTeamHolding,
      arpToken,
      beneficiary,
      startTime
    );
  }
};
