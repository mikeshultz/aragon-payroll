# aragon-payroll

Example payroll contract for aragon

## Test

This assumes you have [truffle](http://truffleframework.com/) installed already 
as well as a test node with multiple accounts pre-populated and unlocked.  
[TestRPC](https://github.com/ethereumjs/testrpc) works pretty well for this.

    truffle test

**Note**: Truffle tests don't always run in the right order, which may cause 
errors.  99% of the time, they are run in the right order with the token 
contracts being deployed and setup first, followed by `Payroll`.