// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/console2.sol";

contract InteropCenter {
    uint256 public interopMessagesSent;
    address public owner;

    // Constructor to set the owner
    constructor() {
        owner = msg.sender;
    }

    // Modifier to restrict access to only the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Type A - Interop Message

    // Interop Event
    event InteropMessageSent(
        bytes32 indexed msgHash,
        address indexed sender,
        bytes payload
    );

    struct InteropMessage {
        bytes data;
        address sender;
        uint256 sourceChainId;
        uint256 messageNum;
    }

    function sendInteropMessage(bytes memory data) external returns (bytes32) {
        // Increment message count
        interopMessagesSent++;

        // Create the InteropMessage struct
        InteropMessage memory message = InteropMessage({
            data: data,
            sender: msg.sender,
            sourceChainId: block.chainid,
            messageNum: interopMessagesSent
        });

        console2.log("Sending interop from ", msg.sender);
        console2.log("Interop id: ", interopMessagesSent);

        // Serialize the entire InteropMessage struct
        bytes memory serializedMessage = abi.encode(message);

        // Calculate the msgHash directly from the serialized message
        bytes32 msgHash = keccak256(serializedMessage);

        // Emit the event with the serialized message as the payload
        emit InteropMessageSent(msgHash, message.sender, serializedMessage);

        // Return the message hash
        return msgHash;
    }

    // *** Trust-me-bro implementation of the interop ***
    // The real one should be using merkle proofs and root hashes from Gateway.

    // Mapping to store received message hashes
    mapping(bytes32 => bool) public receivedMessages;

    // Function to receive and store a message hash, restricted to the owner
    function receiveInteropMessage(bytes32 msgHash) public onlyOwner {
        receivedMessages[msgHash] = true;
    }

    // Function to verify if a message hash has been received
    function verifyInteropMessage(
        bytes32 msgHash,
        bytes memory // proof
    ) public view returns (bool) {
        return receivedMessages[msgHash];
    }

    // Type B - Interop Call & Bundles

    // Struct for storage without dynamic array (as solidity doesn't support it)
    struct StoredInteropBundle {
        uint256 destinationChain;
    }
    // Mappings to store bundles by their ID
    mapping(uint256 => StoredInteropBundle) public bundles;
    mapping(uint256 => InteropCall[]) public bundleCalls;

    uint256 public nextBundleId = 1; // Unique identifier for each bundle

    struct InteropCall {
        address sourceSender;
        address destinationAddress;
        uint256 destinationChainId;
        bytes data;
        uint256 value;
    }

    struct InteropBundle {
        InteropCall[] calls;
        uint256 destinationChain;
    }

    // Function to start a new bundle
    function startBundle(uint256 destinationChain) public returns (uint256) {
        uint256 bundleId = nextBundleId++;

        // Store only the destination chain in the storage mapping
        bundles[bundleId] = StoredInteropBundle({
            destinationChain: destinationChain
        });

        return bundleId;
    }

    function addToBundle(
        uint256 bundleId,
        uint256 destinationChainId,
        address destinationAddress,
        bytes calldata payload,
        uint256 value
    ) public {
        // Ensure the bundle exists and has the correct destination chain
        require(
            bundles[bundleId].destinationChain == destinationChainId,
            "Destination chain mismatch"
        );

        // Create the InteropCall
        InteropCall memory newCall = InteropCall({
            sourceSender: msg.sender,
            destinationAddress: destinationAddress,
            destinationChainId: destinationChainId,
            data: payload,
            value: value
        });

        // Add the call to the bundle
        bundleCalls[bundleId].push(newCall);
    }

    // Function to finish and send the bundle
    function finishAndSendBundle(uint256 bundleId) public returns (bytes32) {
        // Ensure the bundle exists and has calls
        require(
            bundles[bundleId].destinationChain != 0,
            "Bundle does not exist"
        );
        require(bundleCalls[bundleId].length > 0, "Bundle is empty");

        // Prepare the full InteropBundle in memory for serialization
        InteropBundle memory fullBundle = InteropBundle({
            calls: bundleCalls[bundleId],
            destinationChain: bundles[bundleId].destinationChain
        });

        // Serialize the bundle data
        bytes memory serializedData = abi.encode(fullBundle);

        // Send the serialized data via interop message
        bytes32 msgHash = InteropCenter(address(this)).sendInteropMessage(
            serializedData
        );

        // Clean up
        delete bundles[bundleId];
        delete bundleCalls[bundleId];

        return msgHash;
    }

    function sendCall(
        uint256 destinationChain,
        address destinationAddress,
        bytes calldata payload,
        uint256 value
    ) public returns (bytes32) {
        console2.log("Inside sendCall for", address(this));
        console2.log("sender is", msg.sender);
        // Step 1: Start a new bundle
        uint256 bundleId = startBundle(destinationChain);

        // Step 2: Add a call to the bundle
        addToBundle(
            bundleId,
            destinationChain,
            destinationAddress,
            payload,
            value
        );

        // Step 3: Finish and send the bundle
        return finishAndSendBundle(bundleId);
    }

    // Mapping to store trusted sources by chain ID.
    // In reality - we'll be trusting the 'fixed' pre-deployed addresses on each chain.
    mapping(uint256 => address) public trustedSources;
    // Add a trusted source for a given chain ID
    function addTrustedSource(
        uint256 sourceChainId,
        address trustedSender
    ) public onlyOwner {
        trustedSources[sourceChainId] = trustedSender;
    }

    function executeInteropBundle(
        InteropMessage memory message,
        bytes memory proof
    ) public {
        // Verify the message sender is a trusted source

        require(
            trustedSources[message.sourceChainId] == message.sender,
            "Untrusted source"
        );
        console2.log("inside ");
        require(
            verifyInteropMessage(keccak256(abi.encode(message)), proof),
            "Message not verified"
        );

        // Deserialize the InteropBundle from message data
        InteropBundle memory bundle = abi.decode(message.data, (InteropBundle));
        require(bundle.destinationChain == block.chainid, "wrong chain id");

        for (uint256 i = 0; i < bundle.calls.length; i++) {
            InteropCall memory interopCall = bundle.calls[i];

            // Generate the unique address for the account using CREATE2
            bytes32 salt = keccak256(
                abi.encodePacked(
                    message.sourceChainId,
                    interopCall.sourceSender
                )
            );

            console2.log("creation hash");
            console2.logBytes32(keccak256(type(InteropAccount).creationCode));

            address accountAddress = _getZKSyncCreate2Address(salt);
            console2.log("Aliased account ", accountAddress);

            // If account does not exist, deploy it
            if (!isContract(accountAddress)) {
                console2.log("aliased account missing - deploy new one");
                new InteropAccount{salt: salt}();
            }

            // Call the interop function on the account
            InteropAccount(accountAddress).executeInteropCall(interopCall);
        }
    }

    // Helper to compute the CREATE2 address
    function _getCreate2Address(bytes32 salt) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                salt,
                                keccak256(type(InteropAccount).creationCode)
                            )
                        )
                    )
                )
            );
    }

    function getZKSyncBytecodeHash(
        bytes memory code
    ) internal pure returns (bytes32) {
        require(code.length >= 100, "Data must be at least 100 bytes");

        bytes32 result;
        // Load 32 bytes starting from the 68th byte
        assembly {
            result := mload(add(code, 68)) // 68 + 32 = 100
        }
        return result;
    }

    function _getZKSyncCreate2Address(
        bytes32 salt
    ) internal view returns (address) {
        console2.log("Elements");
        console2.logBytes32(keccak256("zksyncCreate2"));
        console2.logBytes32(bytes32(uint256(uint160(address(this)))));
        console2.logBytes32(salt);
        console2.logBytes32(keccak256(type(InteropAccount).creationCode));
        console2.logBytes32(keccak256(""));
        console2.log("done");
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            bytes.concat(
                                keccak256("zksyncCreate2"), // zkSync-specific prefix
                                bytes32(uint256(uint160(address(this)))), // Address of the contract deployer
                                salt, // Salt for the deployment
                                getZKSyncBytecodeHash(
                                    type(InteropAccount).creationCode
                                ), // Hash of the bytecode
                                keccak256("") // Hash of the constructor input data
                            )
                        )
                    )
                )
            );
    }

    // Check if an address is a contract
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}

contract InteropAccount {
    address public trustedInteropCenter;

    // Constructor to set the trusted interop center
    constructor() {
        trustedInteropCenter = msg.sender;
    }

    // Execute function to forward interop call
    function executeInteropCall(
        InteropCenter.InteropCall calldata interopCall
    ) external {
        require(msg.sender == trustedInteropCenter, "Untrusted interop center");
        console2.log("Inside aliased account", address(this));
        console2.log("destination", interopCall.destinationAddress);

        // Forward the call to the destination address
        (bool success, ) = interopCall.destinationAddress.call{
            value: interopCall.value
        }(interopCall.data);
        require(success, "Interop call failed");
    }
}
