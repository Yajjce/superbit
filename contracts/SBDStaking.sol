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
        uint lockTime;
        uint month;
        uint blockReward;
    }
    uint constant ONE_MONTH = 2626560;
    uint constant intervalBlock = 3;
    uint constant ONE_YEAR_BLOCK = 10512000;
    IERC20 public SBD;
    IERC20 public SFT;
    mapping(uint => uint) public  profit;
    mapping(address => Lock[]) public userLock;
    event Stake(address indexed user,uint indexed amount,uint month,uint rate);
    event Claim(address indexed user,uint indexed amount);
    event Withdraw(address indexed user,uint indexed amount);
    event Deposit(address indexed _user,address _token,uint _amount);
    event AdminWithdraw(address indexed _user,address _token,uint _amount);
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
        uint blockReward;
        if(_date == 0) {
            endBlock = 0;
            reward = 0;
            blockReward = 0;
        }else{
            diffBlock = _date.mul(ONE_MONTH).div(intervalBlock);
            endBlock = block.number.add(diffBlock);
            reward = diffBlock.mul(_amount).mul(profit[_date]).div(ONE_YEAR_BLOCK).div(100);
            blockReward = reward.div(diffBlock);
        }
        Lock memory detail = Lock({
            rate:profit[_date],
            amount:_amount,
            lockBlock:block.number,
            endBlock :endBlock,
            claim:0,
            reward:reward,
            lockTime:block.timestamp,
            month:_date,
            blockReward:blockReward
        });
        userLock[msg.sender].push(detail);
        emit Stake(msg.sender,_amount,_date,profit[_date]);
    }
    function claim(uint _amount) external whenNotPaused nonReentrant{
        uint transferAmount = _amount;
        require(_amount <= canClaim(),"Not enough rewards to claim");
        require(SFT.balanceOf(address(this)) >= _amount,"Not enough SFT to claim");
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
                
                uint diffBlock;
                if(block.number>userItems[i].endBlock){
                    diffBlock = userItems[i].endBlock.sub(userItems[i].lockBlock);
                    userItems[i].lockBlock =userItems[i].endBlock;
                }else{
                    diffBlock=block.number.sub(userItems[i].lockBlock);
                    userItems[i].lockBlock = block.number;
                }
                uint canclaim = userItems[i].blockReward.mul(diffBlock);
                userItems[i].claim += canclaim;
                if(userItems[i].claim > 0 ){
                    if(userItems[i].claim > _amount) {
                    userItems[i].claim -= _amount;
                    _amount = _amount.sub(_amount);
                    }else{
                        _amount = _amount.sub(userItems[i].claim);
                        userItems[i].claim = 0;
                    }
                }
                
            }
            if(_amount == 0){
                break ;
            } 
        }
    
        IERC20(SFT).transfer(msg.sender,transferAmount);
        emit Claim(msg.sender,transferAmount);
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
    function deposit(address token,uint256 amount) external onlyOwner {
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        emit Deposit(msg.sender,token,amount);
    }
    function adminWithdraw(address token,uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender,amount);
        emit AdminWithdraw(msg.sender,token,amount);
    }
    function changeRate(uint[] memory month,uint[] memory rate) external onlyOwner {
        require(month.length == rate.length,"Incorrect ratio");
        for (uint i = 0 ; i < month.length ;i++){
            profit[month[i]] = rate[i];
        }
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
       uint diffBlock;
       for(uint i = 0 ; i<userItems.length;i++){
          if(userItems[i].endBlock == 0){
            diffBlock = block.number.sub(userItems[i].lockBlock);
            uint leftReward= diffBlock.mul(userItems[i].amount).mul(userItems[i].rate).div(ONE_YEAR_BLOCK).div(100);
            reward = reward + leftReward + userItems[i].reward;
          }else{
            if(userItems[i].claim < userItems[i].reward){
                if(block.number>userItems[i].endBlock){
                    diffBlock = userItems[i].endBlock.sub(userItems[i].lockBlock);
                }else{
                    diffBlock=block.number.sub(userItems[i].lockBlock);
                }
                uint canReward = userItems[i].blockReward.mul(diffBlock);
                reward = canReward + reward + userItems[i].claim;
            }
          }
       }
       return reward;
    }
    function getUserLockCount(address user) external view returns(uint){
        return userLock[user].length;
    }
}
