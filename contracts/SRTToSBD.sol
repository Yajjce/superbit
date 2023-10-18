// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/TransferHelper.sol";
import "./interfaces/ISVT.sol";
import "./interfaces/ISRT.sol";
contract SRTToSBD is Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    IERC20 SRTToken;
    IERC20 SBDToken;
    ISVT SVTToken;
    struct lockDetail{
        uint256 amount;
        uint256 startBlock;
        uint256 extractedAmount;
        uint256 endBlock;
    }
    uint public intervalBlock = 3; //arb 3 s
    uint constant ONE_YEAR =  31536000;
    uint public allLock;
    mapping(address => lockDetail[]) public userLock;
    event Claim(address indexed _user,uint _amount,uint _burnSVT);
    event Exchange(address indexed _user,uint _amount,uint _receiveSBD,uint _lockSBD,uint _receiveSVT);
    event Deposit(address indexed _user,address _token,uint _amount);
    event Withdraw(address indexed _user,address _token,uint _amount);
    constructor(IERC20 _SRTToken, IERC20 _SBDToken,ISVT _SVTToken){
        SRTToken = _SRTToken;
        SBDToken = _SBDToken;
        SVTToken = _SVTToken;
    }
    function exchange(uint256 amount) external  nonReentrant{
        TransferHelper.safeTransferFrom(address(SRTToken), msg.sender, address(this), amount);
        ISRT(address(SRTToken)).burn(amount);
        uint lockAmount = amount.mul(80).div(100);
        uint getAmount = amount.sub(lockAmount);
        SBDToken.transfer(msg.sender,getAmount);
        SVTToken.mint(msg.sender,lockAmount);
        lockDetail memory detail;
        detail.amount = lockAmount;
        detail.startBlock = block.number;
        detail.extractedAmount = 0;
        detail.endBlock = block.number.add(blockPeriod());
        userLock[msg.sender].push(detail);
        allLock = allLock.add(lockAmount);
        emit Exchange(msg.sender,amount,getAmount,lockAmount,lockAmount);
    }
    function getClaimAmount() public view returns(uint) {
        uint length = userLock[msg.sender].length;
        uint allAmount = 0;
        for(uint i=0;i< length; i++) {
            uint userblockReward = blockReward(userLock[msg.sender][i].amount);
            uint allReward = (block.number.sub(userLock[msg.sender][i].startBlock)).mul(userblockReward);
            allAmount+=allReward;
        }
        return allAmount;
    }
    function blockPeriod() public view returns (uint) {
        return ONE_YEAR.div(intervalBlock);
    }
    function blockReward(uint amount) public view returns(uint){
        if (amount == 0) {
            return 0;
        }
        if (amount < blockPeriod()){
            return amount;
        }else{
            return amount.div(blockPeriod());
        }
    }
    function claim(uint256 claimAmount) external nonReentrant{
        uint amount = getClaimAmount();
        uint transferAmount = claimAmount;
        require(claimAmount <= amount && claimAmount > 0,"Not enough");
        require(SBDToken.balanceOf(address(this)) >= amount,"Insufficient quantity in the pool");
        lockDetail[] storage userItems = userLock[msg.sender];
        uint length = userItems.length;
        uint total;
        uint allReward;
        for(uint i=0;i< length; i++) {
            if(userItems[i].amount <= userItems[i].extractedAmount){
                continue;
            }
            uint userblockReward = blockReward(userItems[i].amount);
            if(block.number > userItems[i].endBlock) {
                 allReward = (userItems[i].endBlock.sub(userItems[i].startBlock)).mul(userblockReward);
            }else{
                 allReward = (block.number.sub(userItems[i].startBlock)).mul(userblockReward);
            }
            if (userItems[i].extractedAmount + allReward > userItems[i].amount ){
                allReward = userItems[i].amount.sub(userItems[i].extractedAmount);
            }
            total = total.add(allReward);
            userItems[i].extractedAmount += allReward;
            userItems[i].startBlock = block.number;
            if(total > claimAmount){
                userItems[i].extractedAmount = userItems[i].extractedAmount.sub(total.sub(claimAmount));
                break;
            }
        }
        SBDToken.transfer(msg.sender, transferAmount);
        allLock = allLock.sub(transferAmount);
        SVTToken.burn(msg.sender,transferAmount);
        emit Claim(msg.sender,transferAmount,transferAmount);
    }
    function getUserLockAmount() external view returns(uint){
        uint length = userLock[msg.sender].length;
        uint allAmount = 0;
        for(uint i=0;i< length; i++) {
            allAmount+=userLock[msg.sender][i].amount;
        }
        return allAmount;
    }
    function deposit(address token,uint256 amount) external onlyOwner {
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        emit Deposit(msg.sender,token,amount);
    }
    function withdraw(address token,uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender,amount);
        emit Withdraw(msg.sender,token,amount);
    }

}
