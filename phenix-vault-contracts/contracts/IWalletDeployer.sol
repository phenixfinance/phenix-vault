//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IWalletDeployer {
    function generateMultiSigWallet(
        string memory _name,
        address[] calldata _owners,
        uint256 _numConfirmationsRequired
    ) external returns (address newMultiSigWalletAddress);

    function factory() external view returns (address);
}
