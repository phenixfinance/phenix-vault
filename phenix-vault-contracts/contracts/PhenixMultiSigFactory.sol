//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./PhenixMultiSig.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PhenixMultiSigFactory is Ownable {
    using SafeMath for uint256;

    // Phenix MultiSig Factory Functionality
    /*
     * - Allow end users to pay a fee to generate their own multi-sig wallet (contract) via this factory contract
     * - The fees paids to generate a multi-sig wallet will be paid in CRO (dynamic fee)
     * - Users can alternatively use PHNX tokens to pay for a multi-sig wallet (utility) (dynamic fee)
     * - Users can select from an array of settings when generating a multi-sig wallet which is fed into the initialize of the main MSW contract
     * - Users can opt into the "Transparency Plus" feature which will allow them to show their community a detailed view of their multi-sig transactiosn (extra fee)
     * - Fees will be store on the multi-sig factory contract and can be withdrawn by the contract owner.
     * -
     */

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 public multiSigDeploymentETHFee;
    uint256 public multiSigDeploymentTokenFee;
    address public payableTokenAddress;
    address public erc721TokenAddress;
    uint256 public erc721DiscountPercentage;
    uint256 public erc721DiscountPercentageDenominator;
    address public feeAllocationAddress;
    uint256 public feeAllocationPercentage;
    uint256 public feeAllocationPercentageDenominator;

    bool public isEnabled;

    mapping(address => address[]) public contractToOwnersMapping;
    mapping(address => address[]) public ownerToContractMapping;
    address[] public deployedContracts;

    constructor(
        uint256 _multiSigDeploymentETHFee,
        uint256 _multiSigDeploymentTokenFee,
        address _payableTokenAddress,
        address _erc721TokenAddress,
        address _feeAllocationAddress
    ) {
        multiSigDeploymentETHFee = _multiSigDeploymentETHFee;
        multiSigDeploymentTokenFee = _multiSigDeploymentTokenFee;
        payableTokenAddress = _payableTokenAddress;
        erc721TokenAddress = _erc721TokenAddress;
        feeAllocationAddress = _feeAllocationAddress;

        erc721DiscountPercentage = 25;
        erc721DiscountPercentageDenominator = 100;

        feeAllocationPercentage = 1;
        feeAllocationPercentageDenominator = 100;

        isEnabled = true;
    }

    modifier canPayTokenFee() {
        require(
            IERC20(payableTokenAddress).allowance(
                address(msg.sender),
                address(this)
            ) >= userCost(multiSigDeploymentTokenFee, msg.sender),
            "PhenixMultiSigFactory contract does not have enough allowance to spend tokens on behalf of the user."
        );

        require(
            IERC20(payableTokenAddress).balanceOf(address(msg.sender)) >=
                userCost(multiSigDeploymentTokenFee, msg.sender),
            "User does not have enough tokens to pay for PhenixMultiSig deployment fee."
        );

        _;
    }

    modifier canGenerateMultiSigWallet() {
        require(
            isEnabled == true,
            "PhenixMultiSigFactory is not currently enabled."
        );
        _;
    }

    function setERC721DiscountFee(uint256 _percentage, uint256 _denominator)
        external
        onlyOwner
    {
        erc721DiscountPercentage = _percentage;
        erc721DiscountPercentageDenominator = _denominator;
    }

    function setFeeAllocationPercentage(
        uint256 _percentage,
        uint256 _denominator
    ) external onlyOwner {
        feeAllocationPercentage = _percentage;
        feeAllocationPercentageDenominator = _denominator;
    }

    function setMultiSigDeploymentETHFee(uint256 _multiSigDeploymentETHFee)
        external
        onlyOwner
    {
        multiSigDeploymentETHFee = _multiSigDeploymentETHFee;
    }

    function setMultiSigDeploymentTokenFee(uint256 _multiSigDeploymentTokenFee)
        external
        onlyOwner
    {
        multiSigDeploymentTokenFee = _multiSigDeploymentTokenFee;
    }

    function setPayableTokenAddress(address _tokenAddress) external onlyOwner {
        payableTokenAddress = _tokenAddress;
    }

    function setIsEnabled(bool _state) external onlyOwner {
        isEnabled = _state;
    }

    function getPayableTokenBalance() external view returns (uint256) {
        return IERC20(payableTokenAddress).balanceOf(address(this));
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getOwnersOfContract(address _address)
        public
        view
        returns (address[] memory)
    {
        return contractToOwnersMapping[_address];
    }

    function getContractsOfOwner(address _address)
        public
        view
        returns (address[] memory)
    {
        return ownerToContractMapping[_address];
    }

    function takeFees() external onlyOwner {
        if (IERC20(payableTokenAddress).balanceOf(address(this)) > 0) {
            IERC20(payableTokenAddress).transfer(
                msg.sender,
                IERC20(payableTokenAddress).balanceOf(address(this))
            );
        }

        if (address(this).balance > 0) {
            (bool success, ) = address(msg.sender).call{
                value: address(this).balance
            }("");
        }
    }

    function userCost(uint256 _amount, address _user)
        public
        view
        returns (uint256)
    {
        uint256 _result = _amount;
        if (IERC721(erc721TokenAddress).balanceOf(_user) > 0) {
            // Apply NFT Fee to amount
            _result = _result.mul(erc721DiscountPercentage).div(
                erc721DiscountPercentageDenominator
            );
            _result = _amount - _result;
        }
        return _result;
    }

    function generateMultiSigWalletWithETH(
        address[] memory _owners,
        uint256 _numConfirmationsRequired
    ) external payable canGenerateMultiSigWallet {
        uint256 amountToPay = userCost(multiSigDeploymentETHFee, msg.sender);
        require(msg.value >= amountToPay, "Not enough ETH to cover cost.");

        _generateMultiSigWallet(_owners, _numConfirmationsRequired);
    }

    function generateMultiSigWalletWithTokens(
        address[] memory _owners,
        uint256 _numConfirmationsRequired
    ) external canPayTokenFee canGenerateMultiSigWallet {
        uint256 amountToPay = userCost(multiSigDeploymentTokenFee, msg.sender);
        IERC20(payableTokenAddress).transferFrom(
            msg.sender,
            address(this),
            amountToPay
        );
        _generateMultiSigWallet(_owners, _numConfirmationsRequired);
    }

    function _generateMultiSigWallet(
        address[] memory _owners,
        uint256 _numConfirmationsRequired
    ) internal {
        /*PhenixMultiSig _newMultiSigWallet = new PhenixMultiSig(
            _owners,
            _numConfirmationsRequired
        );*/

        // TEMP
        address _newMultiSigWallet = DEAD;

        deployedContracts.push(address(_newMultiSigWallet));
        contractToOwnersMapping[address(_newMultiSigWallet)] = _owners;
        for (uint256 i = 0; i < _owners.length; i++) {
            ownerToContractMapping[_owners[i]].push(
                address(_newMultiSigWallet)
            );
        }
    }
}
