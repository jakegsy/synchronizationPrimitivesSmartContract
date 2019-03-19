pragma solidity ^0.5.0;

contract Lockable {

    enum Status {Locked, Expired, Current, Free}

    struct LockInfo {
        bytes32 dataName;
        bytes32 key;
    }

    
    
    struct LockRecord {
        mapping(bytes32 => address payable) locker;
    }

    struct UserRecord {
        LockInfo[] lockInfos;
        //Deposit and timeout related 
        uint256   expiryTime;
        uint256   unlockTime;

        uint256   depositFee;
        bool      depositRefunded;
        //Whitelist and registration related
        uint256   whitelistExpiry;
        bool      whitelistRefunded;
    }

    uint public lockSessionPeriod = 10;
    uint public coolOffPeriod = lockSessionPeriod * 2;
    uint public whitelistPeriod = 30;
    uint public whitelistRefundPeriod = whitelistPeriod * 2;

    uint public depositFee = 0.01 ether ;
    uint public whitelistFee = 1 ether;

    uint public maxLocksPerSession = 10;

    bool public scaleDeposit = true;

    //Takes in name of dataName structure and returns the LockRecord for dataName structure.
    mapping(bytes32 => LockRecord)  lockRecords;
    mapping(address => UserRecord) public userRecords;




    function getLockStatus(bytes32 dataHashKey, bytes32 dataKey, address payable locker) internal view returns(Status)
    {
        address payable currLocker = getCurrLocker(dataHashKey, dataKey);
        //if currLocker is 0x0 then it is obviously not locked.
        if(isZeroAddr(currLocker)) return Status.Free;
        //Checks if `currLocker` has expired, if so, proceed to unlock everything
        // if `currLocker` is `locker` with expired lock, will treat as though its a new
        // lock.
        if(isSessionExpired(currLocker)){
            return Status.Expired;
        }
        //At this point, currLocker != 0 and !expired, so we require that the
        //currLocker has to be the locker, else revert all actions.
        if(currLocker == locker){
            return Status.Current;
        }
        return Status.Locked;
    }
    
    modifier synchronizedDynamic(string memory dataName, bytes32 dataKey) {
        lockDynamic(dataName, dataKey);
        _;
    }

     modifier synchronized(string memory dataName) {
        lockDynamic(dataName, bytes32(0));
        _;
    }


    function lockDynamic(string memory dataName, bytes32 dataKey) internal 
    {

        

        address payable locker = msg.sender;
        bytes32 dataHashKey = getHashKey(dataName);
        Status lockStatus = getLockStatus(dataHashKey, dataKey, locker);

        require(lockStatus != Status.Locked, "dataName is currently locked");

        //Since timeout has not exceeded, if locker is active there is no need to lock again.
        if(lockStatus == Status.Current) return;

        if(isWhitelistType()){
            isWhitelistExpired(locker);
        }

        if(isDepositType()){
            checkAndUpdateDeposit(locker);
        }

        _lock(dataHashKey, dataKey, locker);
    }

    

    function _lock(bytes32 dataHashKey, bytes32 dataKey, address payable locker) 
    internal 
    {
        //Add record of lock into address records
        updateLockInfo(dataHashKey, dataKey, locker);
        //Set lock onto the key of specific dataName structure hash key.
        lockRecords[dataHashKey].locker[dataKey] = locker;

    }

    function updateLockInfo(bytes32 dataHashKey, bytes32 dataKey, address payable locker) internal {
        require(userRecords[locker].lockInfos.length <= maxLocksPerSession, "locker has maximum number of locks");
        LockInfo memory record = LockInfo({dataName : dataHashKey, key : dataKey});
        userRecords[locker].lockInfos.push(record);
    }


    function unlock(address payable locker)
    public
    {
        LockInfo[] memory UserRecords = userRecords[locker].lockInfos;
        for (uint i = 0; i < UserRecords.length; i++) {
            LockInfo memory curr = UserRecords[i];
            _unlock(curr.dataName, curr.key);   
        }

        delete userRecords[locker].lockInfos;
        delete userRecords[locker].expiryTime;

        if(isDepositType()){
            userRecords[locker].unlockTime = block.number;
            refundDeposit(locker);
        }
    }
    

    // 
    // Deposit and Timeout Related Functions
    //
    
    function updateUserRecordWithDeposit(address payable locker) 
    internal 
    {
        userRecords[locker].depositFee = msg.value;
        userRecords[locker].expiryTime = block.number + lockSessionPeriod;
    }

    function unlockWithDeposit(address payable locker) internal{
        unlock(locker);
        userRecords[locker].unlockTime = block.number;
        delete userRecords[locker].lockInfos;
        delete userRecords[locker].expiryTime;
        refundDeposit(locker);
    }

    function refundDeposit(address payable locker)
    internal
    {
        uint256 refund = userRecords[locker].depositFee;
        if(scaleDeposit){
            refund = calculateScaleRefund(locker, refund);
        }
        locker.transfer(refund);
        delete userRecords[locker].depositFee;
    }

    function checkAndUpdateDeposit(address payable locker) internal
    {    
        //To ensure that the locker doesn't pay twice for a depositFee that's still valid
        if(!isSessionExpired(locker)) return;
        uint256 depositFee = calculateDepositFee(locker);
        require(msg.value >= depositFee, "insufficient depositFee");
        updateUserRecordWithDeposit(locker);
    }

    function calculateDepositFee(address payable locker) internal view returns(uint256){
        uint256 depositFee = depositFee;
        //Calculate what the cooling off time is. If COOLING_OFF is 0, which means that cooling off is switched
        //off, then it will always be the base depositFee of DEPOSIT_FEE.
        uint256 coolingOffTime = userRecords[locker].unlockTime + coolOffPeriod;
        if(block.number < coolingOffTime){
            depositFee *= 2 ** (coolingOffTime - block.number);
        }
        return depositFee;
    }

    function calculateScaleRefund(address locker, uint256 depositFee)
    internal view returns(uint256)
    {
        if(isSessionExpired(locker)) return 0;
        return depositFee * (userRecords[locker].expiryTime - block.number) / lockSessionPeriod;
    }
    
    //
    // END OF DEPOSIT AND TIMEOUT RELATED FUNCTIONS
    //

    //
    // WHITELIST RELATED FUNCTIONS
    //

    function registerWhitelist(address locker) public payable
    {
        require(msg.value >= whitelistFee, "insufficient whitelist fee");
        userRecords[locker].whitelistExpiry = block.number + whitelistPeriod;
    }

    function refundWhitelist(address payable locker) public
    {
        require(userRecords[locker].whitelistExpiry != 0, "user is not whitelistExpiry, there is no refund");
        require(userRecords[locker].whitelistExpiry + whitelistRefundPeriod <= block.number, "whitelist refund period has not been reached");
        userRecords[locker].whitelistExpiry = 0;
        locker.transfer(whitelistFee);
    }

    //
    // Helper functions and modifiers
    //
    function getHashKey(string memory arb) 
    pure internal returns (bytes32)
    {
        return keccak256(abi.encodePacked(arb));
    }

    function getCurrLocker(bytes32 dataHashKey, bytes32 dataKey) 
    public view returns(address payable){
        return lockRecords[dataHashKey].locker[dataKey];
    }
   
   
    function _unlock(bytes32 nameOfDataKey, bytes32 hashKey)
    internal
    {   
        delete lockRecords[nameOfDataKey].locker[hashKey];
    }
    
    
   

    
    


    function isZeroAddr(address payable addr) internal pure returns (bool) {
        return(addr == address(0));
    }

    function isSessionExpired(address locker) view public returns(bool)
    {
        return(userRecords[locker].expiryTime < block.number);
    }

   
    function isDepositType() internal view returns(bool){
        return depositFee > 0;
    }

    function isWhitelistType() internal view returns(bool){
        return whitelistFee > 0;
    }

    function isWhitelistExpired(address locker) internal view {
        require(userRecords[locker].whitelistExpiry >= block.number, "registration has expired");
    }





    // DEBUG FUNCTION
    // function expBlock(address locker) view public returns (uint)
    // {
    //     return(userRecords[locker].expiryTime);
    // }
    
    // function lastLock(address locker) view public returns (uint)
    // {
    //     return(userRecords[locker].unlockTime);
    // }
}

