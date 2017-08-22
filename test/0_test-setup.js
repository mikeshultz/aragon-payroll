var HumanStandardToken = artifacts.require("HumanStandardToken");
var USDToken = artifacts.require("USDToken");
var Payroll = artifacts.require("Payroll");

/**
 * These tests are to basically setup state for the following tests.  We are not
 * performing real tests on the token contracts
 */

contract("HumanStandardToken", function(accounts) {

    //web3.personal.unlockAccount(accounts[0], "foo");

    //100000000000000000000000
    it("creation: should have an initial HST balance of 10000000000000000000 for the creator", function() {
        return HumanStandardToken.deployed().then(function(ctr) {
            return ctr.balanceOf.call(accounts[0]);
        }).then(function (result) {
            assert.equal(result.toNumber(), 10000000000000000000);
        });
    });

    it("transfer HST tokens to payroll contract", function() {

        var hst;

        return Payroll.deployed().then(function(payrollInst) {
            return HumanStandardToken.deployed().then(function (hstInst) {
                hst = hstInst;
                return hst.transfer(Payroll.address, 10000000000000000000);
            }).then(function(trans) {
                return hst.balanceOf.call(Payroll.address);
            }).then(function(result) {
                assert.equal(parseInt(result), 10000000000000000000);
            });
        });

    });

});

contract("USDToken", function(accounts) {

    it("creation: should create an initial USD balance of 100000000 for the creator", function() {
        return USDToken.deployed().then(function(usdTract) {
            return usdTract.balanceOf.call(accounts[0]);
        }).then(function (result) {
            assert.equal(result.toNumber(), 100000000);
        });
    });

    it("transfer USD tokens to payroll contract", function() {
        
        var usd;

        return Payroll.deployed().then(function(payrollInst) {
            return USDToken.deployed().then(function (usdInst) {
                usd = usdInst;
                return usd.transfer(Payroll.address, 100000000);
            }).then(function(trans) {
                /*console.log(trans);
                usd.balanceOf.call(accounts[0]).then(function (res) {
                    console.log("Owner balance: " + res);
                });*/
                return usd.balanceOf.call(Payroll.address);
            }).then(function(result) {
                assert.equal(parseInt(result), 100000000);
            });
        });

    });

});