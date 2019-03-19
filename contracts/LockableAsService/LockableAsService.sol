 pragma solidity ^0.5.0;

// contract LockableAsService {

//     struct Record {
//         bytes32 data;
//         bytes32 key;
//     }
    
//     struct LockMap {
//         mapping(bytes32 => address payable) lockStatus;
//     }

//     struct UserRecord {
//         Record[]  records;
//         //Deposit and timeout related 
//         uint256   expiry;
//         uint256   deposit;
//         uint256   lastLockTime;
//         //Whitelist and registration related
//         uint256   registered;
//         bool      refunded;
//     }

//     struct ContractRecord {
//         UserRecord userRecords;
//         mapping(bytes32 => LockMap) dataRecord;
//         address payable contractAddr; //unnecessary?
//         Config config;
//     }

//     struct Config {
//         //All periods are offsets, adding on to when the block.number is
//         uint256 lockPeriod;
//         uint256 coolOffPeriod;
//         uint256 whitelistPeriod;
//         uint256 whitelistRefundPeriod;

//         uint256 depositFee;
//         uint256 whitelistFee;

//         bool isScaleDeposit;
//     }

//     mapping(address => ContractRecord) public contractRecords;
//     uint256 constant ETH = 1 ether; 

//     function registerContract(
//         uint256 _lockPeriod,
//         uint256 _coolOffPeriod,
//         uint256 _whitelistPeriod,
//         uint256 _whitelistRefundPeriod,
//         uint256 _depositFee,
//         uint256 _whitelistFee,
//         bool _isScaleDeposit
//     )
//     public
//     returns(bool)
//     {
//         contractRecords[msg.sender] = Config({
//             lockPeriod : _lockPeriod,
//             coolOffPeriod : _coolOffPeriod,
//             whitelistPeriod : _whitelistPeriod,
//             whitelistRefundPeriod : _whitelistRefundPeriod,
//             depositFee : _depositFee * ETH,
//             whitelistFee : _whitelistFee * ETH,
//             isScaleDeposit : _isScaleDeposit
//         });
//         return true;
//     }

//     function defaultRegisterContract() public returns(bool){
//         return registerContract(10, 20, 30, 60, 0.01, 1, true);
//     }


//     //Checks whether key of data structure `nameOfData` is locked.
//     function isLocked(string memory nameOfData, bytes32 key, address payable locker) 
//     internal returns(bool)
//     {
//         address payable currLocker = getCurrLocker(nameOfData, key);
//         //if currLocker is 0x0 then it is obviously not locked.
//         if(isZeroAddr(currLocker)) return false;
//         //Checks if `currLocker` has expired, if so, proceed to unlock everything
//         // if `currLocker` is `locker` with expired lock, will treat as though its a new
//         // lock.
//         if(isExpired(currLocker)){
//             //This is considered a dirty unlock since it wasn't done requested by the user itself.
//             unlock(currLocker);
//             return false;
//         }
//         //At this point, currLocker != 0 and !expired, so we require that the
//         //currLocker has to be the locker, else revert all actions.
//         return (currLocker != locker);
//     }

//     function checkRegister(address locker) internal {
//         require(userRecords[locker].registered + REGISTRATION_TIME >= now, "registration has expired");
//     }

//     function lockDynamic(string memory nameOfData, bytes32 key, address payable locker)
//     public payable
//     {
//         require(!isLocked(nameOfData, key, locker));
//         if(IS_DEPOSIT){
//             checkAndUpdateDeposit(locker);
//         }
//         if(IS_REGISTER){
//             checkRegister(locker);
//         }
//         _lock(nameOfData, key, locker);
//     }

//     function lockSingle(string memory nameOfData, address payable locker)
//     public payable 
//     {
//         lockDynamic(nameOfData, bytes32(0), locker);
//     }

//     function _lock(string memory nameOfData, bytes32 key, address payable locker) 
//     internal 
//     {   
//         bytes32 hashKey = getHashKey(nameOfData);
//         //Since timeout has not exceeded, if locker is active there is no need 
//         // to relock. Just return it.
//         if(dataRecords[hashKey].lockStatus[key] == locker) return; 
//         //Set lock onto the key of specific data structure hash key.
//         dataRecords[hashKey].lockStatus[key] = locker;
//         //Add record of lock into address records
//         userRecords[locker].records.push(Record({
//             data : hashKey,
//             key : key
//         }));
//     }

//     function unlock(address payable locker)
//     public
//     {
//         Record[] memory UserRecords = userRecords[locker].records;
//         for (uint i = 0; i < UserRecords.length; i++) {
//             Record memory curr = UserRecords[i];
//             _unlock(curr.data, curr.key);   
//         }

//         if(IS_DEPOSIT){
//             userRecords[locker].lastLockTime = block.number;
//             delete userRecords[locker].records;
//             delete userRecords[locker].expiry;
//             refundDeposit(locker);
//         }
//     }
    

//     // 
//     // Deposit and Timeout Related Functions
//     //
    
//     function updateUserRecordWithDeposit(address payable locker) 
//     internal 
//     {
//         userRecords[locker].deposit = msg.value;
//         userRecords[locker].expiry = block.number + TIMEOUT;
//     }

//     function unlockWithDeposit(address payable locker) internal{
//         unlock(locker);
//         userRecords[locker].lastLockTime = block.number;
//         delete userRecords[locker].records;
//         delete userRecords[locker].expiry;
//         refundDeposit(locker);
//     }

//     function refundDeposit(address payable locker)
//     internal
//     {
//         uint256 refund = userRecords[locker].deposit;
//         if(IS_SCALE_DEPOSIT){
//             refund = calculateScaleRefund(locker, refund);
//         }
//         locker.transfer(refund);
//         delete userRecords[locker].deposit;
//     }

//     function checkAndUpdateDeposit(address payable locker) internal
//     {    
//         //To ensure that the locker doesn't pay twice for a deposit that's still valid
//         if(!isExpired(locker)) return;
//         uint256 deposit = DEPOSIT_FEE;
//         //Calculate what the cooling off time is. If COOLING_OFF is 0, which means that cooling off is switched
//         //off, then it will always be the base deposit of DEPOSIT_FEE.
//         uint256 coolingOffTime = userRecords[locker].lastLockTime + COOLING_OFF;
       
//         if(block.number < coolingOffTime){
//             deposit *= 2 ** (coolingOffTime - block.number);
//         }
//         require(msg.value >= deposit, "insufficient deposit");
//         updateUserRecordWithDeposit(locker);
//     }
    
//     //
//     // END OF DEPOSIT AND TIMEOUT RELATED FUNCTIONS
//     //



//     //
//     // Helper functions and modifiers
//     //
//     function getHashKey(string memory arb) 
//     pure internal returns (bytes32)
//     {
//         return keccak256(abi.encodePacked(arb));
//     }

//     function getCurrLocker(string memory nameOfData, bytes32 key) 
//     public view returns(address payable){
//         bytes32 hashKey = getHashKey(nameOfData);
//         return dataRecords[hashKey].lockStatus[key];
//     }
   
   
//     function _unlock(bytes32 nameOfDataKey, bytes32 hashKey)
//     private
//     {   
//         delete dataRecords[nameOfDataKey].lockStatus[hashKey];
//     }
    
    
   
//     function isExpired(address locker) 
//     view public returns(bool)
//     {   
        
//         return(userRecords[locker].expiry < block.number);
//     }
    
    
//     function calculateScaleRefund(address locker, uint256 deposit)
//     internal view returns(uint256)
//     {
//         if(isExpired(locker)) return 0;
//         return deposit * (userRecords[locker].expiry - block.number) / TIMEOUT;
//     }

//     function isZeroAddr(address payable addr) internal pure returns (bool) {
//         return(addr == address(0));
//     }


//     // DEBUG FUNCTION
//     // function expBlock(address locker) view public returns (uint)
//     // {
//     //     return(userRecords[locker].expiry);
//     // }
    
//     // function lastLock(address locker) view public returns (uint)
//     // {
//     //     return(userRecords[locker].lastLockTime);
//     // }
// }
