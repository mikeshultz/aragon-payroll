pragma solidity ^0.4.11;

import "./HumanStandardToken.sol";
import "./USDToken.sol";

/**
 * @dev Handle all payroll for the company including hiring, firing, raises,
 * and automated payment distribution.
 *
 * NOTES:
 *  - "For the sake of simplicity lets asume USD is a ERC20 token. Also lets 
 *      asume we can 100% trust the exchange rate oracle"
 *
 * TODO: 
 *  - Make sure exchange rates are calculated properly.  Is 100:1 and 1:100 
 *      both accurate?
 *  - What about payment in Ether?  While not in the spec, I imagine an 
 *      employee may want that ability.
 *  - What if the employer wants to allow distribution correction in case 
 *      something goes wrong?
 *  - There should be a way to track all of the tokens that this contract should
 *      have a balance of.
 */
contract Payroll {

    struct Employee {
        bool active;
        uint salary;
        address[] tokens;
        int[] tokenDistribution;
        uint start;
    }

    struct TokenDistribution {
        address token;
        int percentage;
    }

    // Is this contract valid and still in use?
    bool valid;

    // Mapping of owners or ones who can set payroll and hire/fire Mapping used 
    // because it's cheap to check against.  Value simply shows existence.
    mapping (address => bool) internal owners;

    // Mapping of employees
    mapping (address => Employee) internal employees;

    // The last time an employee last reallocated their pay ratio
    mapping (address => uint) internal employeeRealloc;

    // The last time the employee was paid
    mapping (address => uint) internal lastPayday;

    // The token exchange rate
    mapping (address => uint) internal exchangeRates;

    // The USD token
    address usdTokenAddress;
    
    // Total current employees
    uint public employeeCount;

    // The oracle that will handle exchange rates between tokens and USD
    address internal exchangeOracle;

    // The amount spent yearly on payroll
    uint internal annualPayroll;

    ///
    /// Events
    ///

    /** 
     * @dev Signal an error 
     */
    event Error(address sender, string msg);

    /**
     * @dev Signal an error with token operations
     */
    event ErrorToken(address sender, string message);

    /**
     * @dev Employee was paid
     */
    event Paid(address sender);

    /**
     * @dev Event used for debugging purposes
     */
    event Debug(string message);

    /**
     * @dev Event used for debugging purposes
     */
    event DebugUint(uint message);

    /**
     * @dev Event used for debugging purposes
     */
    event DebugInt(int message);

    ///
    /// Modifiers
    ///

    /**
     * @dev Only the owner can execute
     */
    modifier onlyOwner() {
        require(owners[msg.sender] == true); 
        _; 
    }

    /**
     * @dev Only the employee can execute
     */
    modifier onlyEmployee() {
        // Make sure the caller is an active employee
        require(employees[msg.sender].active == true);
        _;
    }

    /**
     * @dev Only the oracle can execute
     */
    modifier onlyOracle() {
        // Make sure the caller is the set oracle
        require(msg.sender == exchangeOracle);
        _;
    }

    /**
     * @dev Employee must be active and employed
     * @param employeeAddress - The address argument for the employee for the function 
     *      being validated
     */
    modifier employeeIsActive(address employeeAddress) {
        require(employees[employeeAddress].active == true);
        _; 
    }

    /**
     * @dev Validate salary input for sanity
     * @param salary - The salary arg for the function call being validated
     */
    modifier validSalary(uint salary) {
        require(salary > 0);
        _; 
    }

    /**
     * @dev Make sure this contract is still valid
     */
    modifier contractValid() {
        assert(valid == true);
        _; 
    }

    /**
     * @dev Only the owner can execute
     * @param firstOwner - The first owner of the contract, usually CEO or 
     *      hiring manager
     * @param oracle - The exchange oracle that will provide the contract with 
     *      token to USD exchange rates
     * @param usdTokenAddr - The token contract address for the USD token
     */
    function Payroll(address firstOwner, address oracle, address usdTokenAddr) {
        
        // Set first owner
        owners[firstOwner] = true;
       
        // Set oracle
        exchangeOracle = oracle;

        // Set contract valid
        valid = true;

        // Set the USD token address
        usdTokenAddress = usdTokenAddr;

    }

    ///
    /// Utility functions
    ///

    /** 
     * @dev Get the sum of an array of integers
     * @param arr - The array of integers
     * @return Sum of integers
     */
    function sumArrayInt(int[] arr) constant internal returns (int) {

        int sum = 0;

        for (uint i = 0; i < arr.length; i++) {
            sum += arr[i];
        }

        return sum;

    }

    ///
    /// Management functions
    ///

    /**
     * @dev Add an employee to the roster
     * @param accountAddress - The employee's public address
     * @param allowedTokens - The tokens that can be used as part of payroll 
     *      payment
     * @param initialYearlyUSDSalary - The initial salary to set for the 
     *      employee in USD
     */
    function addEmployee(address accountAddress, address[] allowedTokens, uint initialYearlyUSDSalary) onlyOwner contractValid {

        // Default to 0 distribution of tokens. Let the employee set that later.
        int[] defaultDistribution;
        for (uint i = 0; i < allowedTokens.length; i++) {
            defaultDistribution[i] = 0;
        }

        // Add the employee
        employees[accountAddress] = Employee(true, initialYearlyUSDSalary, allowedTokens, defaultDistribution, now);

        // Bump count
        employeeCount += 1;

        // Bump the annual payroll amount
        annualPayroll += initialYearlyUSDSalary;

    }

    /**
     * @dev Set the salary of an employee
     * @param employeeAddress - The address of the employee
     * @param yearlyUSDSalary - The yearly salary to set for the employee in USD
     */
    function setEmployeeSalary(address employeeAddress, uint yearlyUSDSalary) contractValid onlyOwner validSalary(yearlyUSDSalary) employeeIsActive(employeeAddress) {

        // Get difference in salary
        uint salaryDiff = yearlyUSDSalary - employees[employeeAddress].salary;

        // Set new salary
        employees[employeeAddress].salary = yearlyUSDSalary;

        // Adjust the annual payroll projection
        annualPayroll += salaryDiff;

    }

    /**
     * @dev Terminate an employee
     * @param employeeAddress - The address of the employee
     */
    function removeEmployee(address employeeAddress) contractValid onlyOwner employeeIsActive(employeeAddress) {

        // Terminate the employee
        employees[employeeAddress].active = false;

        // Adjust count
        employeeCount -= 1;

        // Remove salary from payroll projection
        annualPayroll -= employees[employeeAddress].salary;

        // TODO: final payment?

    }

    /**
     * @dev Reactivate a returning employee
     * @param employeeAddress - The address of the employee
     * @param yearlyUSDSalary - The yearly salary to set for the employee in USD
     */
    function reactivateEmployee(address employeeAddress, uint yearlyUSDSalary) contractValid onlyOwner validSalary(yearlyUSDSalary) {

        // Make sure the employee exists. This is the best way to check for a 
        // valid Employee struct without using active
        require(employees[employeeAddress].start > 0);
        // Make sure the employee isn't already an active employee
        require(employees[employeeAddress].active != true);

        // Reactivate the employee
        employees[employeeAddress].active = true;

        // Set their new salary
        employees[employeeAddress].salary = yearlyUSDSalary;

        // Add salary to the payroll projection
        annualPayroll += employees[employeeAddress].salary;

    }

    /**
     * @dev Add funds to the payroll fund
     *
     * TODO: 
     *  - Main payment mechanism is USD and tokens.  Is it even possible to 
     *      purchase tokens with ERC20?  According to the ERC20 standard 
     *      interface, there are no purchase options.  It requires the owner 
     *      or contract owner to make the transfer.  Needs more research. For
     *      now, tokens will have to be transferred to this contract from an
     *      external entity.  Due to this, and the lack of ether payout in the 
     *      spec, there's no need to deposit ether to this contract.
     *      More info: https://theethereum.wiki/w/index.php/ERC20_Token_Standard
     */
    //function addFunds() payable contractValid onlyOwner {
    //    payrollBalance += msg.value;
    //}

    /** 
     * @dev Drop all funds and lock everything down. No selfdestruct here in case 
     * we still need data
     */
    function scapeHatch() contractValid onlyOwner {

        // Send everything the contract has to the sending owner
        msg.sender.transfer(this.balance);

        // Set contract invalid
        valid = false;

    }

    /**
     * @dev Notify contract of deposit of tokens in its name
     *
     * Notes:
     *  - "Use approveAndCall or ERC223 tokenFallback"
     *  - This was in the original spec, but I can't see the need for it.  
     *      Internally storing token balances seems a bit more fragile than just
     *      checking balanceOf when needed, though it may save gas.  I'm 
     *      choosing to leave this out of the contract without a clear use case.
     */
    // function addTokenFunds() {}

    /**
     * @dev Return the current count of employees
     * @return employeeCount - Count of employees
     */
    function getEmployeeCount() constant returns (uint) {

        return employeeCount;

    }

    /**
     * @dev Return the Employee requested, except for tokens
     *
     * The variable token array can not be returned due to an EVM limitation:
     *      See: http://solidity.readthedocs.io/en/develop/frequently-asked-questions.html#can-you-return-an-array-or-a-string-from-a-solidity-function-call
     *
     * Use isValidEmployeeToken or getEmployeeToken
     *
     * @return act - Is this a current employee?
     * @return sal - The employees current or last salary
     * @return st - The start datetime of the employee
     */
    function getEmployee(address employeeAddress) constant returns (bool act, uint sal, uint st) {
        return (employees[employeeAddress].active, 
            employees[employeeAddress].salary,
            employees[employeeAddress].start);
    }

    /**
     * @dev Check if a token is acceptable for an employee
     * @param employeeAddress - The address of the employee to check
     * @param tokenAddress - The address of the token contract
     * @return bool - If it's valid
     */
    function isValidEmployeeToken(address employeeAddress, address tokenAddress) constant employeeIsActive(employeeAddress) returns (bool) {

        // Let's peek through the (hopefully) small array of tokens
        for (uint i = 0; i < employees[employeeAddress].tokens.length; i++) {

            // If we find the one we're looking for...
            if (tokenAddress == employees[employeeAddress].tokens[i]) {

                // Good to go!
                return true;

            }

        }

        // Otherwise, tokenAddress was invalid
        return false;

    }

    /**
     * @dev Function to to get amount of tokens allowed for distribution for an
     * employee
     * @param employeeAddress - The address for the employee to check
     * @return count of tokens
     */
    function getEmployeeTokenCount(address employeeAddress) constant employeeIsActive(employeeAddress) returns (uint) {

        return employees[employeeAddress].tokens.length;

    }

    /**
     * @dev Function to to get specific entries in the employee token array. This 
     * is should be suitable for iteration since we can't return arrays with 
     * the EVM.
     * @param employeeAddress - The address for the employee to check
     * @param i - The array location
     * @return The token contract address
     * @return The distribution percentage
     */
    function getEmployeeToken(address employeeAddress, uint i) constant employeeIsActive(employeeAddress) returns (address, int) {

        // Throw early, in case we can't predict the EVM with OOB array calls
        require(i < employees[employeeAddress].tokens.length);

        // Return it
        return (employees[employeeAddress].tokens[i], employees[employeeAddress].tokenDistribution[i]);

    }

    /** 
     * @dev Return the current monthly payroll spent in USD
     * @return burnrate - The value in USD being spent on payroll per month
     */
    function calculatePayrollBurnrate() constant returns (uint) {
        return annualPayroll / 12;
    }

    /**
     * @dev Return the amount of days until broke
     * @return runway - Days until the world ends
     */
    function calculatePayrollRunway() constant returns (uint) {

        // Figure out daily payroll
        uint daily = annualPayroll / 365;

        // Get USD token instance
        USDToken usdToken = USDToken(usdTokenAddress);

        // Get our balance
        uint usdBalance = usdToken.balanceOf(this);
        
        // Calculate the days until empty
        return usdBalance / daily;

    }

    /**
     * @dev Get the exchange rate for a token
     * @param token - The address for the token contract
     * @return The exchange rate between token and USD
     */
    function getExchangeRate(address token) constant returns (uint) {

        return exchangeRates[token];

    }

    /**
     * @dev Set the exchange rate for a token
     * @param token - The address for the token contract
     * @param usdExchangeRate - The exchange rate between token and USD. For
     *      instance, if 1 token was 1USD, usdExchangeRate would be 1
     */
    function setExchangeRate(address token, uint usdExchangeRate) onlyOracle {

        // Set the rate
        exchangeRates[token] = usdExchangeRate;

    }

    /**
     * @dev Allocate paycheck
     * @param tokens - Array token contract addresses to be paid out by
     * @param distribution - Array of percentages of the employees salary that 
     *      should be provisioned for each token
     */
    function determineAllocation(address[] tokens, int[] distribution) external onlyEmployee {
        
        // Make sure they haven't reallocated in the last half of a year
        require(now - 16425000 > employeeRealloc[msg.sender]);

        // verify we have the same amount of tokens and percentages
        require(tokens.length == distribution.length);

        // Verify the distribution count isn't greater than 100%
        int distSum = sumArrayInt(distribution);
        require(distSum <= 100);

        // Set tokens
        employees[msg.sender].tokens = tokens;

        // Set distribution
        employees[msg.sender].tokenDistribution = distribution;

    }

    /** 
     * @dev PAY ME!  
     * 
     * For the sake of not having to do date calculations and save time for this
     * exercise this is using 2737500 seconds since that's exactly 1/12th of a 
     * year.  For production use, something like ethereum-datetime  would 
     * probably be best, since people usually work on calendar months.
     *
     * This also has the problem where if an employee is slow on triggering 
     * payday(), their pay will be delayed and they will be paid less that year.
     *
     * TODO: Refactor. This needs to be month and day of month aware
     *
     */
    function payday() external onlyEmployee {

        if (lastPayday[msg.sender] > 0) {
            // Make sure it's been one "month" since last payday
            require(now - lastPayday[msg.sender] >= 2737500);
        }

        // Initial distrubtion percentage to USD
        int usdDistPercent = 100;

        // Figure out the monthly USD payment
        int monthlyPayment = int(employees[msg.sender].salary) / 12;

        // Initial USD payment
        int usdPayment = monthlyPayment;

        // See if we need to handle tokens.
        if (employees[msg.sender].tokens.length > 0) {
            
            // Get the total distrubtion
            int distSum = sumArrayInt(employees[msg.sender].tokenDistribution);

            // Double check it's not nonsense
            if (distSum < 0 || distSum >= 100) revert();

            // Subtract this percentage from the USD payout
            usdDistPercent -= distSum;

            // Iterate through the tokens
            for (uint i = 0; i < employees[msg.sender].tokens.length; i++) {

                // The remainder from token purchases
                int remainder = 0;

                // Make sure we have an exchange rate for this token
                assert(exchangeRates[employees[msg.sender].tokens[i]] > 0);

                // Figure out the percentage of USD to use for this token.
                int tokenPayUSD = (usdPayment * employees[msg.sender].tokenDistribution[i]) / 100;

                // First bit of remainder
                remainder = (usdPayment * employees[msg.sender].tokenDistribution[i]) % 100;

                // Subtract this from the USD payment
                usdPayment -= tokenPayUSD;

                // Figure out the amount of tokens we can get
                int tokens = tokenPayUSD * int(exchangeRates[employees[msg.sender].tokens[i]]);

                // Remainder USD from token purchases calculation
                // TODO: Check this math!
                remainder += (tokenPayUSD % int(exchangeRates[employees[msg.sender].tokens[i]])) * int(exchangeRates[employees[msg.sender].tokens[i]]);
                
                // Add the remainder to be distributed in USD
                usdPayment += remainder;

                // Get token instance
                HumanStandardToken tok = HumanStandardToken(employees[msg.sender].tokens[i]);

                // Get our current token balance
                uint tokenBalance = tok.balanceOf(this);

                // If we don't have enough tokens, bail
                assert(int(tokenBalance) >= tokens);

                // make token payment
                tok.transfer(msg.sender, uint(tokens));

            }

        }

        // Get USD Token contract instance
        USDToken usdToken = USDToken(usdTokenAddress);

        // Get our current USD balance
        uint usdTokenBalance = usdToken.balanceOf(this);

        // Make sure we have the funds
        assert(int(usdTokenBalance) >= usdPayment);

        // Make USD payment
        usdToken.transfer(msg.sender, uint(usdPayment));

        // Notify
        Paid(msg.sender);
        
    }
}