// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LockV3NFT {
    address public superNode;
    address public bigNode;
    address public smallNode;
    address public router;
    address public fundToken;
    constructor(address _superNode,address _bigNode,address _smallNode,address _router,address _fundToken){
        superNode = _superNode;
        bigNode = _bigNode;
        smallNode = _smallNode;
        router = _router;
        fundToken = _fundToken;
    }
    function LockV3NFT(uint _level,){
        
    }
}
