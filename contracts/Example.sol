pragma solidity ^0.5.0;

import "./Lockable.sol";

contract Example is Lockable{

    mapping(bytes32 => uint256) public dynamic;
    uint256 public single;
    


    constructor(uint _timeout, uint _depositFee, uint _coolingOff, bool _scaleDeposit,
                uint _whitelistFee, uint _whitelistPeriod, uint _whitelistRefundPeriod)
    public
    {
        lockSessionPeriod = _timeout;
        depositFee = _depositFee;
        coolOffPeriod = _coolingOff;
        scaleDeposit = _scaleDeposit;
        whitelistFee = _whitelistFee;
        whitelistPeriod = _whitelistPeriod;
        whitelistRefundPeriod = _whitelistRefundPeriod;
    }



    function getData(string memory location) view public returns (uint256) {
        bytes32 hashKey = getHashKey(location);
        return dynamic[hashKey];
    }

    function setDynamic(string memory key, uint256 value)
    public 
    payable 
    synchronizedDynamic("dynamic", getHashKey(key))
    {
       dynamic[keccak256(abi.encodePacked(key))] = value;
    }

    function setSingle(uint256 value)
    public 
    payable 
    synchronized("single")
    {
       single = value;
    }
    
   
    function release(address payable locker)
    public
    {
        unlockWithDeposit(locker);
    }
    

}