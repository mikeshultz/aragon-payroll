var HumanStandardToken = artifacts.require("HumanStandardToken");
var USDToken = artifacts.require("USDToken");
var Payroll = artifacts.require("Payroll");

contract("Payroll", function(accounts) {
    var owner = accounts[0];
    var oracle = accounts[1];
    var mary = accounts[2];
    var frank = accounts[3];
    var sarah = accounts[4];

    var marySalary = 15000000;
    var frankSalary = 10000000;

    /*it("listens for events", function() {

        return Payroll.deployed().then(function(payroll) {

            var payrollEvents = payroll.allEvents();

            return payrollEvents.watch(function(err, evt) {
                if (err) console.error(err);
                console.log(evt);
            })

        });

    });*/

    it("adds an employee", function() {

        return Payroll.deployed().then(function(payroll) {

            return payroll.addEmployee(mary, [HumanStandardToken.address], marySalary, {from: owner, gas: 200000});

        }).then(function(retval) {
            assert.isTrue(true);
        });

    });

    it("returns the added employee", function() {

        return Payroll.deployed().then(function(payroll) {

            var waitTill = new Date(new Date().getTime() + 5 * 1000);
            while(waitTill > new Date()){}

            return payroll.getEmployee(mary, {from: mary});

        }).then(function(retval) {

            assert.isTrue(retval[0], "employee mary should be active");
            assert.equal(retval[1], marySalary, "mary's salary should be " + marySalary + " USD tokens");

        });

    });

    it("returns an accurate count of employees", function() {

        return Payroll.deployed().then(function(payroll) {

            return payroll.getEmployeeCount();

        }).then(function(retval) {

            assert.equal(retval, 1, "should show 1 employees");

        });

    });


    it("give mary a raise to $200k", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;

            marySalary = 20000000;

            return payroll.setEmployeeSalary(mary, marySalary, {from: owner});

        }).then(function(trans) {

            return payroll.getEmployee(mary);

        }).then(function(retval) {

            assert.equal(retval[1], marySalary, "mary's salary should have been changed");

        });

    });

    it("should hire frank", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;

            return payroll.addEmployee(frank, [HumanStandardToken.address], frankSalary, {from: owner});

        }).then(function(trans) {

            return payroll.getEmployee(frank);

        }).then(function(retval) {

            assert.isTrue(retval[0], "frank should be an active employee");

        });

    });

    it("should fire frank", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;

            return payroll.removeEmployee(frank, {from: owner});

        }).then(function(trans) {

            return payroll.getEmployee(frank);

        }).then(function(retval) {

            assert.isFalse(retval[0], "frank should not be an active employee");

        });

    });

    it("should change its mind and begrudgingly rehire frank", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;

            frankSalary = 8000000;

            return payroll.reactivateEmployee(frank, frankSalary, {from: owner});

        }).then(function(trans) {

            return payroll.getEmployee(frank);

        }).then(function(retval) {

            assert.isTrue(retval[0], "frank should be an active employee");
            assert.equal(retval[1], frankSalary, "frank's new salary should have been set");

        });

    });

    it("should see if a token is valid payment for an employee", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;

            return payroll.isValidEmployeeToken(frank, HumanStandardToken.address, {from: owner});

        }).then(function(retval) {

            assert.isTrue(retval, "frank should allow payment in HST");

        });

    });

    it("should get a count of an employee's allowed payment tokens", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            return payroll.getEmployeeTokenCount(frank);

        }).then(function(retval) {

            assert.equal(retval, 1, "frank should only have one token set as payment");

        });

    });

    it("should get all employee tokens by iterating with getEmployeeToken", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            return payroll.getEmployeeTokenCount(frank);

        }).then(function(retval) {

            var tokensPromises = [];

            for (var i = 0; i < retval; i++) {
                tokensPromises[i] = payroll.getEmployeeToken(frank, i);
            }

            return Promise.all(tokensPromises);

        }).then(function(toks) {
            
            assert.equal(toks.length, 1, "frank should only have one token set as payment");
            assert.equal(toks[0][0], HumanStandardToken.address, "frank's one token should be HST");

        });

    });

    it("should get the current monthly burnrate", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            return payroll.calculatePayrollBurnrate();

        }).then(function(retval) {
            
            var burnRate = Math.round((marySalary + frankSalary) / 12);
            assert.equal(burnRate, parseInt(retval), "burn rate appears invalid");

        });

    });

    it("should get the current runway in days", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            return payroll.calculatePayrollRunway();

        }).then(function(retval) {

            assert.equal(1303, parseInt(retval), "runway appears invalid");

        });

    });

    it("should allow mary to set her distribution", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            return payroll.determineAllocation([HumanStandardToken.address.toString()], ["25"], {from: mary});

        }).then(function(trans) {
            
            return payroll.getEmployeeTokenCount(mary);

        }).then(function(retval) {

            var tokensPromises = [];

            for (var i = 0; i < retval; i++) {
                tokensPromises[i] = payroll.getEmployeeToken(mary, i);
            }

            return Promise.all(tokensPromises);

        }).then(function(retval) {

            assert.equal(retval[0][0], HumanStandardToken.address, "HST should be Mary's only token");
            assert.equal(parseInt(retval[0][1]), 25, "HST should be set to 25% of distribution");

        });

    });

    it("should allow the oracle to set the exchange rate", function() {
        var payroll;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            return payroll.setExchangeRate(HumanStandardToken.address, 1, {from: oracle});

        }).then(function(trans){

            return payroll.getExchangeRate(HumanStandardToken.address);

        }).then(function(retval) {
            
            assert.equal(parseInt(retval), 1, "Exchange rate should be 100 USD to 1 token");

        });

    });

    it("should pay mary", function() {
        var payroll;
        var maryStartUSD;
        var maryStartHT;
        var maryEndUSD;
        var maryEndHT;

        return Payroll.deployed().then(function(instance) {

            payroll = instance;
            
            let hstPromise = HumanStandardToken.deployed().then(function(hst) {
                return hst.balanceOf(mary);
            });

            let usdPromise = USDToken.deployed().then(function(usd) {
                return usd.balanceOf(mary);
            });

            return Promise.all([hstPromise, usdPromise]);

        }).then(function(retval) {

            maryStartHT = retval[0];
            maryStartUSD = retval[1];

            return payroll.payday({from: mary, gas: 4000000});

        }).then(function(trans){
            let hstPromise = HumanStandardToken.deployed().then(function(hst) {
                return hst.balanceOf(mary);
            });

            let usdPromise = USDToken.deployed().then(function(usd) {
                return usd.balanceOf(mary);
            });

            return Promise.all([hstPromise, usdPromise]);

        }).then(function(retval) {

            maryEndHT = parseInt(retval[0]);
            maryEndUSD = parseInt(retval[1]);
            
            assert.isAbove(maryEndHT, maryStartHT, "Mary appears to not have been paid in HT");
            assert.isAbove(maryEndUSD, maryStartUSD, "Mary appears to not have been paid in USD");

            // Figure out monthly salary
            let maryMonthly = marySalary / 12;
            
            // Monthly token value in USD
            let maryTokenAmount = maryMonthly * 0.25;

            // Corrected USD payout amount
            let maryUSD = maryMonthly - maryTokenAmount;

            // Convert token value to token count.  100:1 on USD to HT (set 
            // previously by oracle)
            let maryTokens = maryMonthly / 100;

            // Make sure the value is correct for tokens
            assert.equal(Math.floor(maryTokens), maryEndHT, "Calculation for HT distribution is incorrect");

            // Make sure the USD amount is also correct
            assert.equal(Math.floor(maryUSD), maryEndUSD, "USD distribution calculation is incorrect");

        });

    });

});