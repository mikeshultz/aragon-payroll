var HumanStandardToken = artifacts.require("HumanStandardToken");
var USDToken = artifacts.require("USDToken");
var Payroll = artifacts.require("Payroll");

/* It appears I can not test multiple tokens of the same contract using truffle.
   https://github.com/trufflesuite/truffle/issues/237

   So... There's a separate duplicate contract with the name USDToken
 */
module.exports = function(deployer, network, accounts) {
  deployer.deploy(HumanStandardToken, 10000000000000000000, "Human Standard Token", 18, "HT");
  deployer.deploy(USDToken, 100000000, "United States Dollar", 2, "USD").then(function() {
    return deployer.deploy(Payroll, accounts[0], accounts[1], USDToken.address);
  });
};
