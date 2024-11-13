// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Vm} from "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/console2.sol";

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {IInteropCenter} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/IInteropCenter.sol";
import {L2TransactionRequestTwoBridgesOuter} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";
import {L2_INTEROP_CENTER_ADDR, L2_ASSET_ROUTER_ADDR, L2_BRIDGEHUB_ADDR, L2_NATIVE_TOKEN_VAULT_ADDR} from "../lib/era-contracts/l1-contracts/contracts/common/l2-helpers/L2ContractAddresses.sol";
import {Transaction, TransactionHelper} from "../lib/era-contracts/system-contracts/contracts/libraries/TransactionHelper.sol";
import {GasFields, InteropCallStarter, BridgehubL2TransactionRequest} from "../lib/era-contracts/l1-contracts/contracts/common/Messaging.sol";
// import {BridgehubL2TransactionRequest} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";
// import {IERC20} from "..
import {TestnetERC20Token} from "../lib/era-contracts/l1-contracts/contracts/dev-contracts/TestnetERC20Token.sol";

import {Swap} from "../src/Swap.sol";
import {Greeter} from "../src/Greeter.sol";

contract SwapScript is Script {
    IInteropCenter public interopCenter = IInteropCenter(L2_INTEROP_CENTER_ADDR);
    Swap public swap;
    uint256 public mintValue;
    uint256 public swapAmount;
    address aliasedAddress;
    address tokenAAddress1;
    address tokenAAddress2;
    address tokenBAddress1;
    address tokenBAddress2;
    bytes32 tokenAAssetId;
    bytes32 tokenBAssetId;

    uint256 chainId1;
    uint256 chainId2;

    function setUp() public {

        swap = new Swap(tokenAAddress2, tokenBAddress2); 
    }

    function run() public {
        vm.startBroadcast();
        requestCrossChainSwap();
    }

    function requestCrossChainSwap() public payable returns (bytes32) {
        InteropCallStarter[] memory feeStarters = new InteropCallStarter[](1);
        feeStarters[0] = InteropCallStarter({
            directCall: true,
            to: aliasedAddress,
            from: address(0),
            data: "",
            value: mintValue,
            requestedInteropCallValue: mintValue
        });

        InteropCallStarter[] memory executionStarters = new InteropCallStarter[](5);
        
        // L2 Token Transfer
        executionStarters[0] = InteropCallStarter({
            directCall: false,
            to: address(0),
            from: L2_ASSET_ROUTER_ADDR,
            data: getTokenTransferSecondBridgeData(
                tokenAAssetId,
                swapAmount,
                aliasedAddress
            ),
            value: 0,
            requestedInteropCallValue: 0
        });

        // Cross Chain Swap Approval
        executionStarters[1] = InteropCallStarter({
            directCall: true,
            to: tokenAAddress2,
            from: address(0),
            data: abi.encodeCall(
                IERC20.approve,
                (address(swap),
                swapAmount)
            ),
            value: 0,
            requestedInteropCallValue: 0
        });

        // Cross Chain Swap
        executionStarters[2] = InteropCallStarter({
            directCall: true,
            to: address(swap),
            from: address(0),
            data: abi.encodeCall(
                Swap.swap,
                swapAmount
            ),
            value: 0,
            requestedInteropCallValue: 0
        });

        // Cross Chain NTV Approval
        executionStarters[3] = InteropCallStarter({
            directCall: true,
            to: tokenBAddress2,
            from: address(0),
            data: abi.encodeCall(
                IERC20.approve,
                (L2_NATIVE_TOKEN_VAULT_ADDR,
                swapAmount * 2)
            ),
            value: 0,
            requestedInteropCallValue: 0
        });

        // Transfer Back Token
        executionStarters[4] = InteropCallStarter({
            directCall: true,
            to: L2_BRIDGEHUB_ADDR,
            from: address(0),
            data: getRequestL2TransactionTwoBridgesData(
                block.chainid,
                mintValue,
                0,
                getTokenTransferSecondBridgeData(tokenBAssetId, swapAmount, msg.sender),
                msg.sender
            ),
            value: mintValue,
            requestedInteropCallValue: mintValue
        });

        GasFields memory gasFields = GasFields({
            gasLimit: 30000000,
            gasPerPubdataByteLimit: 1000,
            refundRecipient: msg.sender
        });

        return requestInterop(
            chainId2,
            executionStarters,
            feeStarters,
            gasFields
        );
    }

    function requestInterop(
        uint256 chainId2,
        InteropCallStarter[] memory executionCallStarters,
        InteropCallStarter[] memory feePaymentCallStarters,
        GasFields memory gasFields
    ) public payable returns (bytes32) {
        uint256 totalValue = 0;
        for(uint i = 0; i < executionCallStarters.length; i++) {
            totalValue += executionCallStarters[i].requestedInteropCallValue;
        }
        
        require(msg.value >= totalValue, "Not enough value sent");

        return interopCenter.requestInterop(
            chainId2,
            feePaymentCallStarters,
            executionCallStarters,
            gasFields
        );
    }

    function getTokenTransferSecondBridgeData(
        bytes32 assetId,
        uint256 amount,
        address recipient
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            hex"01",
            abi.encode(
                assetId,
                abi.encode(amount, recipient)
            )
        );
    }

    function getRequestL2TransactionTwoBridgesData(
        uint256 chainId,
        uint256 mintValue,
        uint256 l2Value,
        bytes memory secondBridgeCalldata,
        address refundRecipient
    ) public view returns (bytes memory) {
        return abi.encodeCall(
            IInteropCenter.requestL2TransactionTwoBridges,
            L2TransactionRequestTwoBridgesOuter({
                chainId: chainId,
                mintValue: mintValue,
                l2Value: l2Value,
                l2GasLimit: 30000000,
                l2GasPerPubdataByteLimit: 1000,
                refundRecipient: refundRecipient,
                secondBridgeAddress: L2_ASSET_ROUTER_ADDR,
                secondBridgeValue: 0,
                secondBridgeCalldata: secondBridgeCalldata
            })
        );
    }
}

// Original TypeScript code:

// const tx = await from_interop1_requestInterop(
//     [
//         {
//             directCall: true,
//             to: aliased_interop1_wallet_address,
//             from: ethers.ZeroAddress,
//             data: '0x',
//             value: '0x' + mintValue.toString(16),
//             requestedInteropCallValue: '0x' + mintValue.toString(16)
//         }
//     ],
//     //feeStarters
//     [
//         // getL2TokenTransferIndirectStarter(),
//         {
//             directCall: false,
//             to: ethers.ZeroAddress,
//             from: L2_ASSET_ROUTER_ADDR,
//             data: getTokenTransferSecondBridgeData(
//                 tokenA_details.assetId!,
//                 swapAmount,
//                 aliased_interop1_wallet_address
//             ),
//             value: '0x0',
//             requestedInteropCallValue: '0x0'
//         },
//         // getCrossChainSwapApprovalDirectStarter(),
//         {
//             directCall: true,
//             to: tokenA_details.l2AddressSecondChain!,
//             from: ethers.ZeroAddress,
//             data: interop1_tokenA_contract.interface.encodeFunctionData('approve', [
//                 await interop2_swap_contract.getAddress(),
//                 swapAmount
//             ]),
//             value: '0x0',
//             requestedInteropCallValue: '0x0'
//         },
//         // getCrossChainSwapDirectStarter(),
//         {
//             directCall: true,
//             to: await interop2_swap_contract.getAddress(),
//             from: ethers.ZeroAddress,
//             data: interop2_swap_contract.interface.encodeFunctionData('swap', [swapAmount]),
//             value: '0x0',
//             requestedInteropCallValue: '0x0'
//         },
//         // getCrossChainNtvApprovalDirectStarter(),
//         {
//             directCall: true,
//             to: tokenB_details.l2AddressSecondChain!,
//             from: ethers.ZeroAddress,
//             data: interop1_tokenA_contract.interface.encodeFunctionData('approve', [
//                 L2_NATIVE_TOKEN_VAULT_ADDR,
//                 swapAmount * 2n
//             ]),
//             value: '0x0',
//             requestedInteropCallValue: '0x0'
//         },
//         // getTransferBackTokenDirectStarter()
//         {
//             directCall: true,
//             to: L2_BRIDGEHUB_ADDR,
//             from: ethers.ZeroAddress,
//             data: await getRequestL2TransactionTwoBridgesData(
//                 (
//                     await interop1_wallet.provider.getNetwork()
//                 ).chainId,
//                 mintValue,
//                 0n,
//                 getTokenTransferSecondBridgeData(tokenB_details.assetId!, swapAmount, interop1_wallet.address),
//                 interop1_wallet.address
//             ),
//             value: '0x' + mintValue.toString(16), // note in two bridges this is * 2n , because we pay for gas as well. This cleans it up.
//             requestedInteropCallValue: '0x' + mintValue.toString(16)
//         }
//     ],
//     {
//         gasLimit: 30000000,
//         gasPerPubdataByteLimit: 1000,
//         refundRecipient: interop1_wallet.address
//     }
// );

// async function from_interop1_requestInterop(
//     feePaymentCallStarters: InteropCallStarter[],
//     executionCallStarters: InteropCallStarter[],
//     gasFields: GasFields
// ) {
//     const input = [
//         // destinationChainId:
//         (await interop2_provider.getNetwork()).chainId.toString(),
//         // feePaymentCallStarters:
//         feePaymentCallStarters,
//         // executionCallStarters:
//         executionCallStarters,
//         // gasFields:
//         {
//             gasLimit: 600000000,
//             gasPerPubdataByteLimit: REQUIRED_L2_GAS_PRICE_PER_PUBDATA,
//             refundRecipient: interop1_wallet.address
//         }
//         // refundRecipient: interop1_wallet.address
//     ];

//     // console.log("input", input)
//     // console.log("interop1_interop_center_contract", interop1_interop_center_contract.interface.fragments[32])
//     const request = await interop1_interop_center_contract.requestInterop.populateTransaction(...input);
//     request.value =
//         mintValue +
//         BigInt(
//             executionCallStarters.reduce(
//                 (acc: bigint, curr: InteropCallStarter) => acc + BigInt(curr.requestedInteropCallValue),
//                 0n
//             )
//         );
//     request.from = interop1_wallet.address;
//     // console.log("request", request)

//     const tx = await interop1_interop_center_contract.requestInterop(...input, {
//         value: '0x' + request.value.toString(16),
//         gasLimit: 30000000
//     });

//     await tx.wait();
//     return tx;
// }


// function getTokenTransferSecondBridgeData(assetId: string, amount: bigint, recipient: string) {
//     return ethers.concat([
//         '0x01',
//         new ethers.AbiCoder().encode(
//             ['bytes32', 'bytes'],
//             [assetId, new ethers.AbiCoder().encode(['uint256', 'address'], [amount, recipient])]
//         )
//     ]);
// }

// function getRequestL2TransactionTwoBridgesData(
//     chainId: bigint,
//     mintValue: bigint,
//     l2Value: bigint,
//     secondBridgeCalldata: string,
//     refundRecipient: string
// ) {
//     return interop1_bridgehub_contract.interface.encodeFunctionData('requestL2TransactionTwoBridges', [
//         {
//             chainId: chainId.toString(),
//             mintValue,
//             l2Value,
//             l2GasLimit: 30000000,
//             l2GasPerPubdataByteLimit: REQUIRED_L2_GAS_PRICE_PER_PUBDATA,
//             refundRecipient: refundRecipient,
//             secondBridgeAddress: L2_ASSET_ROUTER_ADDR,
//             secondBridgeValue: 0,
//             secondBridgeCalldata
//         }
//     ]);
// }