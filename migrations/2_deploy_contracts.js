var HumanStandardToken = artifacts.require("HumanStandardToken");
var USDToken = artifacts.require("USDToken");
var PayrollInterface = artifacts.require("PayrollInterface");

/* It appears I can not test multiple tokens of the same contract using truffle.
   https://github.com/trufflesuite/truffle/issues/237

   So... There's a separate duplicate contract with the name USDToken
 */
module.exports = function(deployer) {
  deployer.deploy(HumanStandardToken, 60000000, "BestToken", 18, "BT");
  deployer.deploy(USDToken, 6000000000, "United States Dollar", 2, "USD");
  deployer.deploy(PayrollInterface);
};
