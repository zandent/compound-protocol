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

    // Information describing a transaction
    struct LockedTx {
        address target;
        uint value;
        string signature;
        bytes data;
        uint user_delay;
        bool ready;
    }
    
    // Transaction queue
    mapping (bytes32 => LockedTx) private queuedTx;

    uint public constant MINIMUM_DELAY = 0 days;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;

    // Signal emitted when a transaction needs to be executed
    signal TimesUp(bytes32);
    // Handler to do function call for queued transaction
    handler TxExecutor(bytes32);

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
        // LockedTx memory new_tx = LockedTx(target, value, signature, data, user_delay, true);
        // Push the new transaction to the queuedTx map
        queuedTx[txHash] = LockedTx(target, value, signature, data, user_delay, true);

        // Emit a signal for delayed execution of this transaction
        TimesUp.emit(txHash).delay(user_delay);

        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint user_delay) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, user_delay));
        queuedTx[txHash].ready=false;

        emit CancelTransaction(txHash, target, value, signature, data, user_delay);
    }

    // Slot that does the executing
    function executeTransaction(bytes32 txHash) public {
        //no need to check sender is admin anymore
        //no need to check the tx is under correct period anymore
        require(queuedTx[txHash].ready, "Timelock::executeTransaction: Transaction hasn't been queued.");
        queuedTx[txHash].ready=false;
        bytes memory callData;

        if (bytes(queuedTx[txHash].signature).length == 0) {
            callData = queuedTx[txHash].data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(queuedTx[txHash].signature))), queuedTx[txHash].data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = queuedTx[txHash].target.call.value(queuedTx[txHash].value)(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, queuedTx[txHash].target, queuedTx[txHash].value, queuedTx[txHash].signature, queuedTx[txHash].data, queuedTx[txHash].user_delay);        
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    constructor(address admin_, uint delay_) public {
        require(delay_ >= MINIMUM_DELAY, "Timelock::construct: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        TimesUp.create_signal();
        TxExecutor.create_handler("executeTransaction(bytes32)", 1000000, 120);
        
        address this_address = address(this);
        TxExecutor.bind(this_address, "TimesUp(bytes32)");
        
        admin = admin_;
        delay = delay_;
    }
}