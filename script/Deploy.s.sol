// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import {StdStorage, stdStorage, stdToml} from "forge-std/Test.sol";
import "forge-std/console.sol";

// import {InteropCenter} from "../src/InteropCenter.sol";
import {PaymasterToken} from "../src/PaymasterToken.sol";
import {CrossPaymaster} from "../src/CrossPaymaster.sol";
import {Greeter} from "../src/Greeter.sol";

import "../src/Greeter.sol";
import "../lib/forge-std/src/console2.sol";
// import {Transaction, TransactionHelper} from "../lib/era-contracts/system-contracts/contracts/libraries/TransactionHelper.sol";
import {DeployUtils} from "../lib/era-contracts/l1-contracts/deploy-scripts/DeployUtils.s.sol";
import {Utils} from "../lib/era-contracts/l1-contracts/deploy-scripts/Utils.sol";
// import {SystemContractsArgs} from "../lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractL1DeployerUtils.sol";

import {L2_FORCE_DEPLOYER_ADDR, L2_MESSAGE_ROOT_ADDR, L2_BRIDGEHUB_ADDR} from "../lib/era-contracts/l1-contracts/contracts/common/l2-helpers/L2ContractAddresses.sol";
import {InteropCenter} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/InteropCenter.sol";
import {IInteropCenter} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/IInteropCenter.sol";

import {MessageRoot} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/MessageRoot.sol";
import {IBridgehub} from "../lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";

import {SystemContractsArgs, SharedL2ContractL1DeployerUtils} from "../lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractL1DeployerUtils.sol";
import {SharedL2ContractDeployer} from "../lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-abstract/_SharedL2ContractDeployer.sol";
import {SharedL2ContractL2DeployerUtils} from "../lib/era-contracts/l1-contracts/test/foundry/l2/integration/_SharedL2ContractL2DeployerUtils.sol";

contract Deploy is Script, DeployUtils, SharedL2ContractL2DeployerUtils, SharedL2ContractDeployer {
    using stdToml for string;

    IInteropCenter public interopCenter;
    PaymasterToken public paymasterToken;
    CrossPaymaster public crossPaymaster;

    Greeter public greeter;

    function setUp() public override {
        // console.log(ERA_CHAIN_ID);
        vm.setEnv("CONTRACTS_PATH", "lib/era-contracts");
        super.setUpInner(true);
    }

    function run() public {
        vm.startBroadcast();

        // paymasterToken = new PaymasterToken(address(interopCenter));
        // console2.log("Deployed Paymaster token at:", address(paymasterToken));

        // crossPaymaster = new CrossPaymaster(
        //     address(paymasterToken),
        //     address(interopCenter)
        // );
        // console2.log("Deployed Paymaster  at:", address(crossPaymaster));

        // greeter = new Greeter();
        // console2.log("Deployed greeter at:", address(greeter));

        // // register preferred local paymaster.
        // // interopCenter.setPreferredPaymaster(
        // //     block.chainid,
        // //     address(crossPaymaster)
        // // );

        // address payable paymasterPayable = payable(address(crossPaymaster));

        // // This doesn't pass any value in broadcast mode.. ehh ...
        // (bool success, ) = paymasterPayable.call{value: 50000}("");
        // require(success, "Call failed");

        // console2.log("Balance is ", paymasterPayable.balance);

        vm.stopBroadcast();
    }

    function test() internal virtual override(DeployUtils, SharedL2ContractL2DeployerUtils) {}

    function initSystemContracts(
        SystemContractsArgs memory _args
    ) internal  override(SharedL2ContractDeployer, SharedL2ContractL2DeployerUtils) {
        super.initSystemContracts(_args);
    }

    function deployViaCreate2(
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal override(SharedL2ContractL2DeployerUtils, DeployUtils) returns (address) {
        return super.deployViaCreate2(creationCode, constructorArgs);
    }

    function deployL2Contracts(
        uint256 _l1ChainId
    ) public override(SharedL2ContractL2DeployerUtils, SharedL2ContractDeployer) {
        super.deployL2Contracts(_l1ChainId);
    }
}
