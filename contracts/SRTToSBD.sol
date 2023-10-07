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
    }
    uint public intervalBlock = 3; //arb 3 s
    uint constant ONE_YEAR =  31536000;
    uint public allLock;
    mapping(address => lockDetail[]) public userLock;
    mapping(address => uint) public userLockAmount;
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
        userLock[msg.sender].push(detail);
        userLockAmount[msg.sender] += lockAmount;
        allLock = allLock.add(amount);
        emit Exchange(msg.sender,amount,getAmount,lockAmount,lockAmount);
    }
    function getClaimAmount() public view returns(uint) {
        uint length = userLock[msg.sender].length;
        uint allAmount = 0;
        for(uint i=0;i< length; i++) {
            uint blockReward = userLock[msg.sender][i].amount.div(ONE_YEAR.div(intervalBlock));
            uint allReward = (block.number.sub(userLock[msg.sender][i].startBlock)).mul(blockReward);
            allAmount+=allReward;
        }
        return allAmount;
    }
    function claim(uint256 claimAmount) external nonReentrant{
        uint amount = getClaimAmount();
        require(claimAmount <= amount,"Not enough");
        require(userLockAmount[msg.sender]>=amount,"Not enough quantity");
        require(SBDToken.balanceOf(address(this)) >= amount,"Insufficient quantity in the pool");
        SBDToken.transfer(msg.sender, claimAmount);
        userLockAmount[msg.sender] = userLockAmount[msg.sender].sub(claimAmount);
        allLock = allLock.sub(claimAmount);
        SVTToken.burn(msg.sender,claimAmount);
        emit Claim(msg.sender,claimAmount,claimAmount);
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
