//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./PhenixMultiSig.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Pair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PhenixMultiSigFactory is Ownable {
    using SafeMath for uint256;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public payableTokenAddress;
    address public erc721TokenAddress;
    uint256 public erc721DiscountPercentage;
    uint256 public erc721DiscountPercentageDenominator;
    //address public routerAddress = 0x145677FC4d9b8F19B5D56d1820c48e0443049a30; LIVE
    address public routerAddress = 0x2fFAa0794bf59cA14F268A7511cB6565D55ed40b;

    // address public usdcPairAddress = 0xa68466208F1A3Eb21650320D2520ee8eBA5ba623; LIVE
    address public usdcPairAddress = 0x4003bE1b4f747CE2549D5Ffba7A1014477EDF614;

    bool public isEnabled;

    struct Fees {
        uint256 feeETH;
        uint256 feeToken;
        bool usdcMode;
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
        address _erc721TokenAddress
    ) {
        payableTokenAddress = _payableTokenAddress;
        erc721TokenAddress = _erc721TokenAddress;

        erc721DiscountPercentage = 10;
        erc721DiscountPercentageDenominator = 100;

        isEnabled = true;

        _setAdminAddress(msg.sender, true);
        _setTypeFee(
            0,
            _multiSigDeploymentETHFee,
            _multiSigDeploymentTokenFee,
            false
        );
    }

    modifier canPayTokenFee(uint256 _type) {
        require(
            IERC20(payableTokenAddress).allowance(
                address(msg.sender),
                address(this)
            ) >= userCost(getFeeTokenAmount(_type), msg.sender),
            "PhenixMultiSigFactory contract does not have enough allowance to spend tokens on behalf of the user."
        );

        require(
            IERC20(payableTokenAddress).balanceOf(address(msg.sender)) >=
                userCost(getFeeTokenAmount(_type), msg.sender),
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
        uint256 _tokenFee,
        bool _usdcMode
    ) internal {
        multiSigTypeFees[_index].feeETH = _ethFee;
        multiSigTypeFees[_index].feeToken = _tokenFee;
        multiSigTypeFees[_index].usdcMode = _usdcMode;
    }

    function setTypeFee(
        uint256 _index,
        uint256 _ethFee,
        uint256 _tokenFee,
        bool _usdcMode
    ) external onlyOwner {
        _setTypeFee(_index, _ethFee, _tokenFee, _usdcMode);
    }

    function setRouterAddress(address _routerAddress) external onlyOwner {
        routerAddress = _routerAddress;
    }

    function setUSDCPairAddress(address _usdcPairAddress) external onlyOwner {
        usdcPairAddress = _usdcPairAddress;
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

    function setMultiSigWalletType(address _contractAddress, uint256 _type)
        external
        isValidType(_type)
        onlyOwner
    {
        contractType[_contractAddress] = _type;
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

    function takeETHFees() external onlyOwner {
        require(address(this).balance > 0, "No ETH to claim.");
        (bool success, ) = address(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Failed to claim ETH.");
    }

    function takeTokenFees() external onlyOwner {
        require(
            IERC20(payableTokenAddress).balanceOf(address(this)) > 0,
            "No tokens to claim."
        );
        IERC20(payableTokenAddress).transfer(
            msg.sender,
            IERC20(payableTokenAddress).balanceOf(address(this))
        );
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
        return factoryAdmins[_user] == false ? _result : 0;
    }

    function getFeeAmountsOfType(uint256 _type)
        external
        view
        returns (
            uint256,
            uint256,
            bool
        )
    {
        return (
            getFeeETHAmount(_type),
            getFeeTokenAmount(_type),
            multiSigTypeFees[_type].usdcMode
        );
    }

    function getFeeETHAmount(uint256 _type) public view returns (uint256) {
        if (multiSigTypeFees[_type].usdcMode == true) {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(
                usdcPairAddress
            ).getReserves();

            uint256 ethPerUsdc = (reserve0 / reserve1) * 1000000;
            return ethPerUsdc * (multiSigTypeFees[_type].feeETH / 1 ether);
        } else {
            return multiSigTypeFees[_type].feeETH;
        }
    }

    function getFeeTokenAmount(uint256 _type) public view returns (uint256) {
        if (multiSigTypeFees[_type].usdcMode == true) {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(
                usdcPairAddress
            ).getReserves();

            uint256 ethPerUsdc = (reserve0 / reserve1) * 1000000;

            address[] memory path = new address[](2);
            path[0] = IUniswapV2Router02(routerAddress).WETH();
            path[1] = payableTokenAddress;

            uint256[] memory amountsOut = IUniswapV2Router02(routerAddress)
                .getAmountsOut(
                    ethPerUsdc * (multiSigTypeFees[_type].feeToken / 1 ether),
                    path
                );

            return amountsOut[1];
        } else {
            return multiSigTypeFees[_type].feeToken;
        }
    }

    function generateMultiSigWalletWithETH(
        string memory _name,
        address[] calldata _owners,
        uint256 _numConfirmationsRequired,
        uint256 _type
    ) external payable canGenerateMultiSigWallet isValidType(_type) {
        require(getFeeETHAmount(_type) != 0, "No ETH fee set for this type.");

        uint256 amountToPay = userCost(getFeeETHAmount(_type), msg.sender);
        require(
            msg.value >= userCost(amountToPay, msg.sender),
            "Not enough ETH to cover cost."
        );

        if (msg.value > amountToPay) {
            (bool success, ) = address(msg.sender).call{
                value: uint256(msg.value).sub(amountToPay)
            }("");
        }

        _generateMultiSigWallet(
            _name,
            _owners,
            _numConfirmationsRequired,
            _type
        );
    }

    function generateMultiSigWalletWithTokens(
        string memory _name,
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
            getFeeTokenAmount(_type) != 0,
            "No token fee set for this type."
        );

        uint256 amountToPay = userCost(getFeeTokenAmount(_type), msg.sender);
        IERC20(payableTokenAddress).transferFrom(
            msg.sender,
            address(this),
            amountToPay
        );

        _generateMultiSigWallet(
            _name,
            _owners,
            _numConfirmationsRequired,
            _type
        );
    }

    function _generateMultiSigWallet(
        string memory _name,
        address[] calldata _owners,
        uint256 _numConfirmationsRequired,
        uint256 _type
    ) internal {
        PhenixMultiSig _newMultiSigWallet = new PhenixMultiSig(
            _name,
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
    }
}
