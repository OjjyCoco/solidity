// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract WhiteList {
    mapping (address => bool) public whiteList;
    event Authorized(address _address);

    // pour initialiser le contrat avec le deployeur comme premier membre whitelisté:
    constructor(){
        whiteList[msg.sender] = true;
    }

    // on peut utiliser un modifier à la place de la fonction check
    modifier onlyAuthorized(){
        require(whiteList[msg.sender] == true, "Not whitelisted");
        _;
    }

    function authorize(address _address) public onlyAuthorized{
        //require(check(), "You are not authorized");
        whiteList[_address] = true;
        emit Authorized(_address); // Triggers event
    }

    // function check() private view returns(bool) {
    //     require(whiteList[msg.sender] == true, "Not whitelisted");
    //     return true;
    // }

}