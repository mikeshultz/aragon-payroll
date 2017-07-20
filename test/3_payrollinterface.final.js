var HumanStandardToken = artifacts.require("HumanStandardToken");
var USDToken = artifacts.require("USDToken");
var Payroll = artifacts.require("Payroll");

contract("Payroll", function(accounts) {
    var owner = accounts[0];
    var oracle = accounts[1];
    var mary = accounts[2];
    var frank = accounts[3];
    var sarah = accounts[4];

    it("should terminate if the owner wants an escape", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;

            return payroll.scapeHatch({from: owner});

        });

    });

});