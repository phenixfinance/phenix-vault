// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PhenixMultiSig.sol";

contract WalletDeployer {
    address public factoryAddress;

    constructor(address _factoryAddress) {
        factoryAddress = _factoryAddress;
    }

    modifier isFactory() {
        require(msg.sender == factoryAddress);
        _;
    }

    function factory() external view returns (address) {
        return factoryAddress;
    }

    function generateMultiSigWallet(
        string memory _name,
        address[] calldata _owners,
        uint256 _numConfirmationsRequired
    ) external isFactory returns (address newMultiSigWalletAddress) {
        PhenixMultiSig _newMultiSigWallet = new PhenixMultiSig(
            _name,
            _owners,
            _numConfirmationsRequired
        );

        return address(_newMultiSigWallet);
    }
}
