// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/TransferHelper.sol";
import "./interfaces/ISVT.sol";
contract SRTToSBD is Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    IERC20 SRTToken;
    IERC20 SBDToken;
    ISVT SVTToken;
    struct lockDetail{
        uint256 amount;
        uint256 startBlock;
    }
    uint public intervalBlock = 3; //arb 3 s
    uint constant ONE_YEAR =  31536000;
    mapping(address => lockDetail) public userLock;
    event Claim(address indexed _user,uint _amount);
    event Exchange(address indexed _user,uint _amount);
    constructor(IERC20 _SRTToken, IERC20 _SBDToken,ISVT _SVTToken){
        SRTToken = _SRTToken;
        SBDToken = _SBDToken;
        SVTToken = _SVTToken;
    }
    function exchange(uint256 amount) external  nonReentrant{
        TransferHelper.safeTransferFrom(address(SRTToken), msg.sender, address(this), amount);
        uint lockAmount = amount.mul(80).div(100);
        uint getAmount = amount.sub(lockAmount);
        SBDToken.transfer(msg.sender,getAmount);
        SVTToken.mint(msg.sender,lockAmount);
        lockDetail storage detail = userLock[msg.sender];
        if(detail.amount != 0) {
            detail.amount = detail.amount.add(lockAmount);
        }else{
            detail.amount = lockAmount;
            detail.startBlock = block.number;
        }
        emit Exchange(msg.sender,amount);
    }
    function getClaimAmount() public view returns(uint) {
        uint blockReward = userLock[msg.sender].amount.div(ONE_YEAR.div(intervalBlock));
        // uint blockReward = intervalBlock.mul(userLock[msg.sender].amount).div(ONE_YEAR);
        return (block.number.sub(userLock[msg.sender].startBlock)).mul(blockReward);
    }
    function claim(uint256 claimAmount) external nonReentrant{
        uint amount = getClaimAmount();
        require(claimAmount <= amount,"Not enough");
        require(userLock[msg.sender].amount>=amount,"Not enough quantity");
        require(SBDToken.balanceOf(address(this)) >= amount,"Insufficient quantity in the pool");
        SBDToken.transfer(msg.sender, claimAmount);
        userLock[msg.sender].amount = userLock[msg.sender].amount.sub(claimAmount);
        SVTToken.burn(msg.sender,claimAmount);
        emit Claim(msg.sender,claimAmount);
    }

}
