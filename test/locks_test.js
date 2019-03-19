
const Example = artifacts.require('./lock_manager/Example.sol');
const Web3 = require('web3')
const truffleAssert = require('truffle-assertions');
const assert = require("chai").assert;
var web3 = new Web3(Web3.givenProvider)
const ar = require('./helpers/assertRevert.js');
const BigNumber = web3.BigNumber;

contract('Example', function(accounts){

    // uint _timeout, uint _depositFee, uint _coolingOff, bool _scaleDeposit,
    //     uint _whitelistFee, uint _whitelistPeriod, uint _whitelistRefundPeriod

    this.timeout = 10;
    this.depositFee = web3.utils.toWei("0.003");
    this.coolingOff = 5;
    this.scaleDeposit = true;
    this.whitelistFee = web3.utils.toWei("5");
    this.whitelistPeriod = 50;
    this.whitelistRefundPeriod = 15;

    describe('test for lock with deposit and timeout, without whitelist', async()=>{

        beforeEach('setup contract before each test', async()=>{
            this.example = await Example.new(
                this.timeout, this.depositFee, this.coolingOff, this.scaleDeposit, 0, 0, 0);
        });

        it('rejects for single data if not sufficient deposit', async()=>{
            await ar.assertRevert(this.example.setSingle(124));
        });

        it('rejects for dynamic data if not sufficient deposit', async()=>{
            await ar.assertRevert(this.example.setDynamic("Tokyo", 125));
        });


        it('is able to lock single data with deposit and prevent others from writing', async()=>{
            await this.example.setSingle(123, {from: accounts[1], value: this.depositFee});
            val = await this.example.single();
            assert.equal(val.toNumber(), 123);

            await ar.assertRevert(this.example.setSingle(124, {from:accounts[2], value: this.depositFee}));
            assert.equal(val.toNumber(), 123);
        });

        it('is able to lock dynamic data with deposit and prevent others from writing', async()=>{
            await this.example.setDynamic("Tokyo", 123, {from: accounts[1], value: this.depositFee});
            val = await this.example.getData("Tokyo");
            assert.equal(val.toNumber(), 123);

            await ar.assertRevert(this.example.setDynamic("Tokyo", 124, {from:accounts[2], value: this.depositFee}));
            val = await this.example.getData("Tokyo")
            assert.equal(val.toNumber(), 123);
        });

        it('is able to unlock data and allow others to write', async()=>{
            await this.example.setDynamic("Tokyo", 123, {from:accounts[1], value:this.depositFee});
            await this.example.setDynamic("Sin", 456, {from:accounts[1], value:this.depositFee});
            await this.example.setSingle(123, {from: accounts[1], value: this.depositFee});

            await this.example.release(accounts[1]);

            this.example.setDynamic("Tokyo", 124, {from:accounts[2], value:this.depositFee})
            this.example.setDynamic("Sin", 457, {from:accounts[2], value:this.depositFee})
            this.example.setSingle(691, {from: accounts[2], value: this.depositFee})

            val1 = await this.example.single();
            val2 = await this.example.getData("Tokyo");
            val3 = await this.example.getData("Sin");
            assert.equal(val1.toNumber(), 691);
            assert.equal(val2.toNumber(), 124);
            assert.equal(val3.toNumber(), 457);

        });


        it('forfeits deposit in a linear scale', async()=>{
            //TODO complete
            beforeBalance = await web3.eth.getBalance(accounts[1], "latest");
            //console.log("beforeBalance:", beforeBalance);
            await this.example.setDynamic("Tokyo", 123, {from:accounts[1], value : this.depositFee});


            afterDeposit = await web3.eth.getBalance(accounts[1], "latest")

            //TODO calculate gas cost
            //console.log("deposited : ", beforeBalance - afterDeposit);
            //console.log("afterDeposit :", afterDeposit);
            //console.log("depositFee :" , this.depositFee);
            advanceBlock(4, accounts[7]);
            await this.example.release(accounts[1]);
            afterRefund = await web3.eth.getBalance(accounts[1], "latest")
            //console.log(beforeBalance - afterRefund);
            //console.log(depositFee);
        })

        it('allows for autounlocking if expired', async()=>{
            await this.example.setSingle(123, {from:accounts[1], value : this.depositFee});
            await advanceBlock(this.timeout, accounts[7]);
            await this.example.setSingle(124, {from:accounts[2], value : this.depositFee});
            val = await this.example.single();
            assert.equal(val.toNumber(), 124);
        })

        it('demands exponentially increasing deposit for multiple attempts within cool off period', async()=>{
            await this.example.setSingle(123, {from:accounts[1], value : this.depositFee});
            await this.example.release(accounts[1]);

            await ar.assertRevert(this.example.setSingle(124, {from:accounts[1], value : this.depositFee}));
            newDeposit = this.depositFee * 2 ** (this.coolingOff);
            this.example.setSingle(124, {from:accounts[1], value : newDeposit});

            val = await this.example.single();
            assert.equal(val.toNumber(), 124);

        })

    })

    describe('test for lock with deposit and timeout, with whitelist', async()=>{

        beforeEach('setup contract before each test', async()=>{
            this.example = await Example.new(
                this.timeout, this.depositFee, this.coolingOff, this.scaleDeposit, this.whitelistFee, this.whitelistPeriod, this.whitelistRefundPeriod);
        });

        it('rejects for lock attempt if not registered', async()=>{
            await ar.assertRevert(this.example.setSingle(123, {from: accounts[3], value: this.depositFee}));
            await ar.assertRevert(this.example.setDynamic("Sin", 456, {from:accounts[3], value:this.depositFee}));
        });

        it('rejects for whitelist register if not sufficient fee', async()=>{
            await ar.assertRevert(this.example.registerWhitelist(accounts[1]));
        });

        it('is able to lock single data with deposit and prevent others from writing if registered', async()=>{
            await this.example.registerWhitelist(accounts[1], {from:accounts[1], value:this.whitelistFee});
            await this.example.registerWhitelist(accounts[2], {from:accounts[2], value:this.whitelistFee});


            await this.example.setSingle(123, {from: accounts[1], value: this.depositFee});
            val = await this.example.single();
            assert.equal(val.toNumber(), 123);

            await ar.assertRevert(this.example.setSingle(124, {from:accounts[2], value: this.depositFee}));
            assert.equal(val.toNumber(), 123);
        });

        it('is able to lock dynamic data with deposit and prevent others from writing if registered', async()=>{
            await this.example.registerWhitelist(accounts[1], {from:accounts[1], value:this.whitelistFee});
            await this.example.registerWhitelist(accounts[2], {from:accounts[2], value:this.whitelistFee});

            await this.example.setDynamic("Tokyo", 123, {from: accounts[1], value: this.depositFee});
            val = await this.example.getData("Tokyo");
            assert.equal(val.toNumber(), 123);

            await ar.assertRevert(this.example.setDynamic("Tokyo", 124, {from:accounts[2], value: this.depositFee}));
            val = await this.example.getData("Tokyo");
            assert.equal(val.toNumber(), 123);
        });

        it('rejects for lock attempt if registration has expired', async()=>{
            await this.example.registerWhitelist(accounts[1], {from:accounts[1], value:this.whitelistFee});
            await advanceBlock(this.whitelistPeriod, accounts[1]);
            await ar.assertRevert(this.example.setDynamic("Tokyo", 123, {from: accounts[1], value: this.depositFee}));

        })

    })
})


async function advanceBlock(numBlocks, account) {
    for(i=0;i<numBlocks;i++){
        await web3.eth.sendTransaction({
            from : account,
            to : account,
            value : 1
        })
    }
}