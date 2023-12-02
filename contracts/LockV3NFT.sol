// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISwapRouter.sol";
contract LockV3NFT is Ownable,Pausable,ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    IERC721 public superNode;
    IERC721 public bigNode;
    IERC721 public smallNode;
    IERC20 public fundToken;
    IERC20 public USDT;
    ISwapRouter public router;
    EnumerableSet.AddressSet private nodeUsers;
    uint256 private constant MAX = ~uint256(0);
    mapping(address =>uint) public weight;
    mapping(address =>uint) public totalWeight;
    mapping(address => mapping(address => uint)) public userTotalWeight;
    mapping(address =>mapping(address => EnumerableSet.UintSet)) private  userLockIds;
    uint public startTime;
    uint public period;
    uint public bonusTime;
    event Lock(address indexed user,address indexed node,uint amount,uint power);
    event Withdraw(address indexed user,address indexed node,uint amount);
    event Bonus(address indexed user,uint indexed power,uint amount);
    constructor(
        IERC721 _superNode,
        IERC721 _bigNode,
        IERC721 _smallNode,
        ISwapRouter _router,
        IERC20 _fundToken,
        IERC20 _USDT,
        uint _startTime,
        uint _period
        ){
        superNode = _superNode;
        bigNode = _bigNode;
        smallNode = _smallNode;
        router = _router;
        fundToken = _fundToken;
        weight[address(_superNode)] = 10; 
        weight[address(_bigNode)] = 3; 
        weight[address(_smallNode)] = 1;
        startTime = _startTime;
        period = _period;
        bonusTime = _startTime;
        USDT = _USDT;
        IERC20(USDT).approve(address(router), MAX);
    }
    function lock(address node,uint tokenId) external whenNotPaused nonReentrant {
        require(weight[node] != 0, "Lock wrong NFT");
        IERC721(node).transferFrom(msg.sender,address(this),tokenId);
        userLockIds[node][msg.sender].add(tokenId);
        totalWeight[node] += weight[node];
        userTotalWeight[node][msg.sender] += weight[node];
        if(!nodeUsers.contains(msg.sender)){
            nodeUsers.add(msg.sender);
        }
        emit Lock(msg.sender,node,1,weight[node]);
    }
    
    function bonus() external whenNotPaused nonReentrant {
        require(block.timestamp > bonusTime + period,"Not in the dividend period");
        uint USDTBalance = USDT.balanceOf(address(this));
        require(USDTBalance > 0 ,"Not enough USDT");
        address[] memory path  = new address[](2);
        path[0] = address(USDT);
        path[1] = address(fundToken);
         router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDTBalance,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint totalPower = getTotalWeight();
        uint length = nodeUsers.length();
        uint fundBalance = fundToken.balanceOf(address(this));
        for (uint i = 0 ; i< length ; i++) {
            address user = nodeUsers.at(i);
            uint userPower = getUserTotalWeight(user);
            uint reward =  fundBalance * userPower / totalPower;
            if(reward > 0) {
                fundToken.transfer(user,reward);
            } 
        }
        bonusTime = block.timestamp;
        emit Bonus(msg.sender,totalPower,USDTBalance);
    }
    function withdraw(address node,uint tokenId) external whenNotPaused nonReentrant {
        require(userLockIds[node][msg.sender].contains(tokenId),"This NFT does not exist");
        IERC721(node).transferFrom(address(this),msg.sender,tokenId);
        userTotalWeight[node][msg.sender] -= weight[node];
        totalWeight[node]-=weight[node];
        userLockIds[node][msg.sender].remove(tokenId);
        emit Withdraw(msg.sender,node,1);
    }
    function changePeriod(uint newPeriod) external onlyOwner {
        period = newPeriod;
    }
    function getLockIds(address node,address user) public view returns(uint[] memory){
        return userLockIds[node][user].values();
    }
    function getUserTotalWeight(address user) public view returns (uint){
        return userTotalWeight[address(superNode)][user] + userTotalWeight[address(bigNode)][user] + userTotalWeight[address(smallNode)][user];
    }
    function getTotalWeight() public view returns(uint){
        return totalWeight[address(superNode)] + totalWeight[address(bigNode)] + totalWeight[address(smallNode)];
    }
}
