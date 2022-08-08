// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PhenixMultiSig {
    using SafeMath for uint256;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event RejectTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    string public name;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        bool rejected;
        uint256 numConfirmations;
        string info;
    }

    struct TransactionsInfo {
        uint256 numberOfConfirmed;
        uint256 numberOfPending;
        uint256 numberOfExecuted;
    }

    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    mapping(uint256 => mapping(address => bool)) public isRejected;

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notRejected(uint256 _txIndex) {
        require(!transactions[_txIndex].rejected, "tx rejected");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(
        string memory _name,
        address[] memory _owners,
        uint256 _numConfirmationsRequired
    ) {
        require(_owners.length > 0, "No owners provided.");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "Invalid minimum confirmations."
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner was provided.");

            isOwner[owner] = true;
            owners.push(owner);
        }

        name = _name;
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data,
        string memory _info
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                rejected: false,
                numConfirmations: 0,
                info: _info
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
        notRejected(_txIndex)
    {
        _confirmTransaction(_txIndex, msg.sender);
    }

    function _confirmTransaction(uint256 _txIndex, address _signer) internal {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][_signer] = true;

        emit ConfirmTransaction(_signer, _txIndex);
    }

    function confirmAndExecuteTransaction(
        uint256 _txIndex,
        uint256[] memory _timestamps,
        address[] memory _signers,
        bytes[] memory _signatures
    )
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notRejected(_txIndex)
    {
        require(
            _signatures.length == _signers.length && _signatures.length > 0,
            "There must be the same amount as signatures as there is signers."
        );

        // iterate over the _signers to confirm that the signers are owners
        for (uint256 i = 0; i < _signatures.length; i++) {
            require(
                isOwner[_signers[i]] == true,
                "One or more of the signers is not an owner."
            );
            bool _isValid = verify(
                _txIndex,
                _timestamps[i],
                _signers[i],
                _signatures[i]
            );

            if (_isValid == true) {
                _confirmTransaction(_txIndex, _signers[i]);
            }
        }

        _executeTransaction(_txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notRejected(_txIndex)
    {
        _executeTransaction(_txIndex);
    }

    function _executeTransaction(uint256 _txIndex) internal {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Minimum confimations not reached. Execution failed."
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function rejectTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        transaction.rejected = true;
        isRejected[_txIndex][msg.sender] = true;

        emit RejectTransaction(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function deposit() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function getTransactions() external view returns (Transaction[] memory) {
        return transactions;
    }

    function getBalance() external view returns (uint256) {
        return address(this).value;
    }

    function numberOfPendingTransactions() public view returns (uint256) {
        uint256 result = 0;

        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                transactions[i].numConfirmations != numConfirmationsRequired &&
                transactions[i].executed == false &&
                transactions[i].rejected == false
            ) {
                result = result.add(1);
            }
        }

        return result;
    }

    function getPendingTransaction()
        external
        view
        returns (Transaction[] memory)
    {
        Transaction[] memory result = new Transaction[](
            numberOfPendingTransactions()
        );

        uint256 index = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                transactions[i].numConfirmations != numConfirmationsRequired &&
                transactions[i].executed == false &&
                transactions[i].rejected == false
            ) {
                result[index] = transactions[i];
                index = index.add(1);
            }
        }

        return result;
    }

    function numberOfExecutedTransactions() public view returns (uint256) {
        uint256 result = 0;

        for (uint256 i = 0; i < transactions.length; i++) {
            if (transactions[i].executed == true) {
                result = result.add(1);
            }
        }

        return result;
    }

    function getExecutedTransactions()
        external
        view
        returns (Transaction[] memory)
    {
        Transaction[] memory result = new Transaction[](
            numberOfExecutedTransactions()
        );

        uint256 index = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (transactions[i].executed == true) {
                result[index] = transactions[i];
                index = index.add(1);
            }
        }

        return result;
    }

    function numberOfConfirmedTransactions() public view returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                transactions[i].numConfirmations == numConfirmationsRequired &&
                transactions[i].executed == false
            ) {
                result = result.add(1);
            }
        }

        return result;
    }

    function getConfirmedTransactions()
        external
        view
        returns (Transaction[] memory)
    {
        Transaction[] memory result = new Transaction[](
            numberOfConfirmedTransactions()
        );

        uint256 index = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                transactions[i].numConfirmations == numConfirmationsRequired &&
                transactions[i].executed == false
            ) {
                result[index] = transactions[i];
                index = index.add(1);
            }
        }

        return result;
    }

    function getTransactionsInfo()
        external
        view
        returns (TransactionsInfo memory)
    {
        return
            TransactionsInfo(
                numberOfConfirmedTransactions(),
                numberOfPendingTransactions(),
                numberOfExecutedTransactions()
            );
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool rejected,
            bool executed,
            uint256 numConfirmations,
            string memory info
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.rejected,
            transaction.executed,
            transaction.numConfirmations,
            transaction.info
        );
    }

    function getMessageHash(uint256 _txIndex, uint256 _timestamp)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_txIndex, _timestamp));
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function verify(
        uint256 _txIndex,
        uint256 _timestamp,
        address _signer,
        bytes memory _signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_txIndex, _timestamp);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, _signature) == _signer;
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
