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
    address public payableTokenAddress;
    address public erc721TokenAddress;
    uint256 public erc721DiscountPercentage;
    uint256 public erc721DiscountPercentageDenominator;
    address public feeAllocationAddress;
    uint256 public feeAllocationPercentage;
    uint256 public feeAllocationPercentageDenominator;

    bool public isEnabled;

    struct Fees {
        uint256 feeETH;
        uint256 feeToken;
    }

    struct MultiSigWalletInfo {
        address[] owners;
        uint256 contractType;
    }

    mapping(address => address[]) public contractToOwnersMapping;
    mapping(address => address[]) public ownersToContractMapping;
    mapping(address => uint256) public contractType;
    mapping(address => bool) public factoryAdmins;
    mapping(uint256 => Fees) public multiSigTypeFees;

    address[] public deployedContracts;

    constructor(
        uint256 _multiSigDeploymentETHFee,
        uint256 _multiSigDeploymentTokenFee,
        address _payableTokenAddress,
        address _erc721TokenAddress,
        address _feeAllocationAddress
    ) {
        payableTokenAddress = _payableTokenAddress;
        erc721TokenAddress = _erc721TokenAddress;
        feeAllocationAddress = _feeAllocationAddress;

        erc721DiscountPercentage = 25;
        erc721DiscountPercentageDenominator = 100;

        feeAllocationPercentage = 1;
        feeAllocationPercentageDenominator = 100;

        isEnabled = true;

        _setAdminAddress(msg.sender, true);
        _setTypeFee(0, _multiSigDeploymentETHFee, _multiSigDeploymentTokenFee);
    }

    modifier canPayTokenFee(uint256 _type) {
        require(
            IERC20(payableTokenAddress).allowance(
                address(msg.sender),
                address(this)
            ) >= userCost(multiSigTypeFees[_type].feeToken, msg.sender),
            "PhenixMultiSigFactory contract does not have enough allowance to spend tokens on behalf of the user."
        );

        require(
            IERC20(payableTokenAddress).balanceOf(address(msg.sender)) >=
                userCost(multiSigTypeFees[_type].feeToken, msg.sender),
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

    modifier isValidType(uint256 _type) {
        require(
            multiSigTypeFees[_type].feeETH != 0 ||
                multiSigTypeFees[_type].feeToken != 0,
            "Invalid Fee Type Used."
        );
        _;
    }

    function _setTypeFee(
        uint256 _index,
        uint256 _ethFee,
        uint256 _tokenFee
    ) internal {
        multiSigTypeFees[_index].feeETH = _ethFee;
        multiSigTypeFees[_index].feeToken = _tokenFee;
    }

    function setTypeFee(
        uint256 _index,
        uint256 _ethFee,
        uint256 _tokenFee
    ) external onlyOwner {
        _setTypeFee(_index, _ethFee, _tokenFee);
    }

    function _setAdminAddress(address _admin, bool _state) internal {
        factoryAdmins[_admin] = _state;
    }

    function setAdminAddress(address _admin, bool _state) external onlyOwner {
        _setAdminAddress(_admin, _state);
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

    function getMultiSigWalletType(address _contractAddress)
        public
        view
        returns (uint256)
    {
        return contractType[_contractAddress];
    }

    function getMultiSigWalletInfo(address _contractAddress)
        external
        view
        returns (MultiSigWalletInfo memory)
    {
        return
            MultiSigWalletInfo(
                getOwnersOfContract(_contractAddress),
                getMultiSigWalletType(_contractAddress)
            );
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
        return ownersToContractMapping[_address];
    }

    function getDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }

    function numberOfDeployedContracts() external view returns (uint256) {
        return deployedContracts.length;
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
        return factoryAdmins[msg.sender] == false ? _result : 0;
    }

    function generateMultiSigWalletWithETH(
        address[] calldata _owners,
        uint256 _numConfirmationsRequired,
        uint256 _type
    ) external payable canGenerateMultiSigWallet isValidType(_type) {
        require(
            multiSigTypeFees[_type].feeETH != 0,
            "No ETH fee set for this type."
        );

        uint256 amountToPay = userCost(
            multiSigTypeFees[_type].feeETH,
            msg.sender
        );
        require(
            msg.value >= userCost(amountToPay, msg.sender),
            "Not enough ETH to cover cost."
        );

        _generateMultiSigWallet(_owners, _numConfirmationsRequired, _type);
    }

    function generateMultiSigWalletWithTokens(
        address[] calldata _owners,
        uint256 _numConfirmationsRequired,
        uint256 _type
    )
        external
        canPayTokenFee(_type)
        isValidType(_type)
        canGenerateMultiSigWallet
    {
        require(
            multiSigTypeFees[_type].feeToken != 0,
            "No token fee set for this type."
        );

        uint256 amountToPay = userCost(
            multiSigTypeFees[_type].feeToken,
            msg.sender
        );
        IERC20(payableTokenAddress).transferFrom(
            msg.sender,
            address(this),
            amountToPay
        );

        _generateMultiSigWallet(_owners, _numConfirmationsRequired, _type);
    }

    function _generateMultiSigWallet(
        address[] calldata _owners,
        uint256 _numConfirmationsRequired,
        uint256 _type
    ) internal {
        PhenixMultiSig _newMultiSigWallet = new PhenixMultiSig(
            _owners,
            _numConfirmationsRequired
        );

        deployedContracts.push(address(_newMultiSigWallet));
        contractToOwnersMapping[address(_newMultiSigWallet)] = _owners;
        for (uint256 i = 0; i < _owners.length; i++) {
            ownersToContractMapping[_owners[i]].push(
                address(_newMultiSigWallet)
            );
        }

        contractType[address(_newMultiSigWallet)] = _type;
        deployedContracts.push(address(_newMultiSigWallet));
    }
}
