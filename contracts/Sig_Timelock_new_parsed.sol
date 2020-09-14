pragma solidity ^0.6.9;

import "./SafeMath.sol";

contract Sig_Timelock {
    using SafeMath for uint;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint user_delay);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint user_delay);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint user_delay);

    struct LockedTx {
        address target;
        uint value;
        string signature;
        bytes data;
        uint user_delay;
        bool ready;
    }
    
    mapping (bytes32 => LockedTx) private queuedTx;

    uint public constant MINIMUM_DELAY = 0 days;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;

// Original code: signal TimesUp(bytes32);
bytes32 private TimesUp_key;
function set_TimesUp_key() private {
    TimesUp_key = keccak256("TimesUp(bytes32)");
}
////////////////////
// Original code: handler TxExecutor;
bytes32 private TxExecutor_key;
function set_TxExecutor_key() private {
    TxExecutor_key = keccak256("TxExecutor(bytes32)");
}
////////////////////

    fallback() external payable { }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint user_delay) public returns (bytes32) {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");

        require(user_delay >= delay, "Timelock::queueTransaction: Delay must exceed required delay.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, user_delay));
        queuedTx[txHash] = LockedTx(target, value, signature, data, user_delay, true);

// Original code: TimesUp.emit(txHash).delay(user_delay);
bytes memory abi_encoded_TimesUp_data = abi.encode(txHash);
// This length is measured in bytes and is always a multiple of 32.
uint abi_encoded_TimesUp_length = abi_encoded_TimesUp_data.length;
assembly {
    mstore(
        0x00,
        sigemit(
            sload(TimesUp_key.slot), 
            abi_encoded_TimesUp_data,
            abi_encoded_TimesUp_length,
            user_delay
        )
    )
}
////////////////////

        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint user_delay) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, user_delay));
        queuedTx[txHash].ready=false;

        emit CancelTransaction(txHash, target, value, signature, data, user_delay);
    }

    function executeTransaction(bytes32 txHash) public {
        require(queuedTx[txHash].ready, "Timelock::executeTransaction: Transaction hasn't been queued.");
        queuedTx[txHash].ready=false;
        bytes memory callData;

        if (bytes(queuedTx[txHash].signature).length == 0) {
            callData = queuedTx[txHash].data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(queuedTx[txHash].signature))), queuedTx[txHash].data);
        }

        (bool success, bytes memory returnData) = queuedTx[txHash].target.call.value(queuedTx[txHash].value)(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, queuedTx[txHash].target, queuedTx[txHash].value, queuedTx[txHash].signature, queuedTx[txHash].data, queuedTx[txHash].user_delay);        
    }

    function getBlockTimestamp() internal view returns (uint) {
        return block.timestamp;
    }

    constructor(address admin_, uint delay_) public {
        require(delay_ >= MINIMUM_DELAY, "Timelock::construct: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

// Original code: TimesUp.create_signal();
set_TimesUp_key();
assembly {
    mstore(0x00, createsignal(sload(TimesUp_key.slot)))
}
////////////////////
// Original code: TxExecutor.create_handler("executeTransaction(bytes32)",1000000,120);
set_TxExecutor_key();
bytes32 TxExecutor_method_hash = keccak256("executeTransaction(bytes32)");
uint TxExecutor_gas_limit = 1000000;
uint TxExecutor_gas_ratio = 120;
assembly {
    mstore(
        0x00, 
        createhandler(
            sload(TxExecutor_key.slot), 
            TxExecutor_method_hash, 
            TxExecutor_gas_limit, 
            TxExecutor_gas_ratio
        )
    )
}
////////////////////
        
        address this_address = address(this);
// Original code: TxExecutor.bind(this_address,"TimesUp(bytes32)");
bytes32 TxExecutor_signal_prototype_hash = keccak256("TimesUp(bytes32)");
assembly {
    mstore(
        0x00,
        sigbind(
            sload(TxExecutor_key.slot),
            this_address,
            TxExecutor_signal_prototype_hash
        )
    )
}
////////////////////
        
        admin = admin_;
        delay = delay_;
    }
}