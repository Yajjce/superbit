// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./lib/TransferHelper.sol";

contract SBDStaking is ReentrancyGuard,Ownable,Pausable{
    using SafeMath for uint256;
    struct Lock {
        uint rate;
        uint amount;
        uint lockBlock;
        uint endBlock;
        uint reward;
        uint claim;
    }
    uint constant ONE_MONTH = 2626560;
    uint constant intervalBlock = 3;
    uint constant ONE_YEAR_BLOCK = 10512000;
    IERC20 public SBD;
    IERC20 public SFT;
    mapping(uint => uint) public  profit;
    mapping(address => Lock[]) public userLock;
    event Stake(address indexed user,uint indexed amount);
    event Claim(address indexed user,uint indexed amount);
    event Withdraw(address indexed user,uint indexed amount);
    constructor(IERC20 _SBD,IERC20 _SFT){
        SBD = _SBD;
        SFT = _SFT;
        profit[0] = 30;
        profit[3] = 60;
        profit[6] = 80;
        profit[9] = 100;
        profit[12] = 120;
    }
    function stake(uint _date,uint _amount) external whenNotPaused nonReentrant{
        require(profit[_date] != 0 ,'Incorrect lock time');
        TransferHelper.safeTransferFrom(address(SBD), msg.sender, address(this), _amount);
        uint endBlock;
        uint diffBlock;
        uint reward;
        if(_date == 0) {
            endBlock = 0;
            reward = 0;
        }else{
            diffBlock = _date.mul(ONE_MONTH).div(intervalBlock);
            endBlock = block.number.add(diffBlock);
            reward = diffBlock.mul(_amount).mul(profit[_date]).div(ONE_YEAR_BLOCK).div(100);
        }
        Lock memory detail = Lock({
            rate:profit[_date],
            amount:_amount,
            lockBlock:block.number,
            endBlock :endBlock,
            claim:0,
            reward:reward
        });
        userLock[msg.sender].push(detail);
        emit Stake(msg.sender,_amount);
    }
    function claim(uint _amount) external whenNotPaused nonReentrant{
        require(_amount <= canClaim(),'Not enough rewards to claim');
        Lock[] storage userItems = userLock[msg.sender];
        for(uint i = 0 ; i<userItems.length;i++){
            if(userItems[i].endBlock == 0){
                uint diffBlock = block.number.sub(userItems[i].lockBlock);
                uint zeroReward = diffBlock.mul(userItems[i].amount).mul(userItems[i].rate).div(ONE_YEAR_BLOCK).div(100);
                userItems[i].reward += zeroReward;
                userItems[i].lockBlock = block.number;
                if(userItems[i].reward > _amount) {
                    userItems[i].reward -= _amount;
                    _amount = _amount.sub(_amount);
                }else{
                   _amount = _amount.sub(userItems[i].reward);
                    userItems[i].reward = 0;
                }
            }else{
                uint canReward = userItems[i].reward.sub(userItems[i].claim);
                if(canReward > _amount) {
                    userItems[i].claim += _amount;
                    _amount = _amount.sub(_amount);
                }else{
                    userItems[i].claim += canReward;
                    _amount = _amount.sub(canReward);
                }
            }
            if(_amount == 0){
                break ;
            } 
        }
        IERC20(SFT).transfer(msg.sender,_amount);
        emit Claim(msg.sender,_amount);
    }

    function withdraw(uint _amount) external {
        require(_amount <= canWithdraw(),"Not enough tokens to claim");
        Lock[] storage userItems = userLock[msg.sender];
        for(uint i = 0 ; i<userItems.length;i++){
            if(userItems[i].endBlock == 0){
                if(userItems[i].amount > _amount) {
                     userItems[i].amount -= _amount;
                    _amount = _amount.sub(_amount);
                }else{
                    _amount = _amount.sub(userItems[i].amount);
                     userItems[i].amount = 0;
                }
            }else{
                if(block.number> userItems[i].endBlock){
                     if(userItems[i].amount > _amount) {
                     userItems[i].amount -= _amount;
                    _amount = _amount.sub(_amount);
                }else{
                    _amount = _amount.sub(userItems[i].amount);
                     userItems[i].amount = 0;
                }
                }
            }
        }
        IERC20(SBD).transfer(msg.sender,_amount);
        emit Withdraw(msg.sender,_amount);
    }
    function canWithdraw() public view returns(uint){
         Lock[] memory userItems = userLock[msg.sender];
         uint amount = 0;
         for(uint i = 0 ; i<userItems.length;i++){
            if(userItems[i].endBlock == 0){
                amount+=userItems[i].amount;
            }else{
                if(block.number> userItems[i].endBlock){
                    amount+=userItems[i].amount;
                }
            }
         }
         return amount;
    }

    function canClaim() public view  returns(uint){
       Lock[] memory userItems = userLock[msg.sender];
       uint reward = 0;
       for(uint i = 0 ; i<userItems.length;i++){
            uint diffBlock;
          if(userItems[i].endBlock == 0){
            diffBlock = block.number.sub(userItems[i].lockBlock);
            reward += diffBlock.mul(userItems[i].amount).mul(userItems[i].rate).div(ONE_YEAR_BLOCK).div(100);
          }else{
            reward += reward.sub(userItems[i].claim);
          }
       }
       return reward;
    }
}
