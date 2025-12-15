// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

/// @notice Vulnerable lottery with hidden assembly backdoor
/// @dev Appears to use random selection, but admin can secretly override result via assembly
contract VulnerableLotteryV2 {
    address[] public participants;
    address public winner;
    address public admin;
    uint256 public prizePool;

    event ParticipantJoined(address indexed participant);
    event WinnerDrawn(address indexed winner, uint256 prize);

    constructor() {
        admin = msg.sender;
    }

    function join() external payable {
        require(msg.value == 0.1 ether, "Entry fee is 0.1 ETH");
        participants.push(msg.sender);
        prizePool += msg.value;
        emit ParticipantJoined(msg.sender);
    }

    /// @notice Appears to randomly select winner from participants
    /// @dev BACKDOOR: Assembly checks if caller is admin (slot 2) and overwrites winner (slot 1)
    function drawWinner() external {
        require(participants.length >= 2, "Need at least 2 participants");
        require(winner == address(0), "Winner already drawn");

        // Visible "fair" random selection logic
        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, participants.length))
        ) % participants.length;
        address selectedWinner = participants[randomIndex];

        // Hidden backdoor: if caller is admin, secretly override the winner
        assembly {
            // sload(2) = admin address at storage slot 2
            // If caller equals admin, overwrite selectedWinner with admin's address
            if eq(caller(), sload(2)) {
                selectedWinner := caller()
            }
        }

        winner = selectedWinner;
        emit WinnerDrawn(winner, prizePool);
    }

    function claimPrize() external {
        require(msg.sender == winner, "Not the winner");
        require(prizePool > 0, "No prize to claim");

        uint256 prize = prizePool;
        prizePool = 0;

        (bool success,) = winner.call{value: prize}("");
        require(success, "Transfer failed");
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    receive() external payable {}
}

/// @notice Secure lottery with transparent and verifiable randomness
/// @dev No hidden logic, all operations are explicit and auditable
contract SecureLotteryV2 {
    address[] public participants;
    address public winner;
    address public immutable admin;
    uint256 public prizePool;
    uint256 public drawBlock;

    event ParticipantJoined(address indexed participant);
    event DrawInitiated(uint256 indexed drawBlock);
    event WinnerDrawn(address indexed winner, uint256 prize, uint256 randomIndex);

    constructor() {
        admin = msg.sender;
    }

    function join() external payable {
        require(msg.value == 0.1 ether, "Entry fee is 0.1 ETH");
        require(winner == address(0), "Lottery ended");
        participants.push(msg.sender);
        prizePool += msg.value;
        emit ParticipantJoined(msg.sender);
    }

    /// @notice Commit-reveal: initiate draw, winner determined in future block
    function initiateDraw() external {
        require(participants.length >= 2, "Need at least 2 participants");
        require(drawBlock == 0, "Draw already initiated");
        drawBlock = block.number + 1;
        emit DrawInitiated(drawBlock);
    }

    /// @notice Finalize winner using future block hash (not manipulable by admin)
    function finalizeWinner() external {
        require(drawBlock != 0, "Draw not initiated");
        require(block.number > drawBlock, "Wait for draw block");
        require(winner == address(0), "Winner already drawn");

        bytes32 blockHash = blockhash(drawBlock);
        require(blockHash != bytes32(0), "Block hash expired, reinitiate");

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(blockHash, participants.length))) % participants.length;

        winner = participants[randomIndex];
        emit WinnerDrawn(winner, prizePool, randomIndex);
    }

    function claimPrize() external {
        require(msg.sender == winner, "Not the winner");
        require(prizePool > 0, "No prize to claim");

        uint256 prize = prizePool;
        prizePool = 0;

        (bool success,) = winner.call{value: prize}("");
        require(success, "Transfer failed");
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    receive() external payable {}
}

/// @title Assembly Backdoor Vulnerability Test Suite
/// @notice Demonstrates hidden admin privilege via inline assembly in lottery contract
/// @dev Compares deceptive "fair" lottery against genuinely transparent implementation
contract BackdoorAssemblyV2Test is Test {
    VulnerableLotteryV2 internal vulnerable;
    SecureLotteryV2 internal secure;

    address internal admin;
    address internal alice;
    address internal bob;
    address internal charlie;

    function setUp() public {
        admin = address(this);
        alice = vm.addr(1);
        bob = vm.addr(2);
        charlie = vm.addr(3);

        // Fund participants
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(charlie, 1 ether);
        vm.deal(admin, 1 ether);

        vulnerable = new VulnerableLotteryV2();
        secure = new SecureLotteryV2();
    }

    /// @notice Demonstrates backdoor: admin always wins despite "random" selection
    function test_VulnerableBackdoorExploit() public {
        console.log("=== Vulnerable Lottery: Hidden Backdoor ===\n");

        // Users join the lottery
        vm.prank(alice);
        vulnerable.join{value: 0.1 ether}();

        vm.prank(bob);
        vulnerable.join{value: 0.1 ether}();

        vm.prank(charlie);
        vulnerable.join{value: 0.1 ether}();

        console.log("Participants: Alice, Bob, Charlie");
        console.log("Prize pool:", vulnerable.prizePool() / 1e18, "ETH");

        // Admin draws winner - backdoor triggers
        console.log("\nAdmin calls drawWinner()...");
        console.log("Code appears to select random participant");
        console.log("But assembly backdoor overrides result\n");

        vulnerable.drawWinner();

        address winner = vulnerable.winner();
        console.log("Winner:", winner);
        console.log("Admin:", admin);

        // Admin always wins when they call drawWinner
        assertEq(winner, admin, "Backdoor: Admin became winner despite not participating");
        console.log("\nEXPLOIT: Admin won without being a participant!");
    }

    /// @notice Shows that non-admin callers get legitimate random result
    function test_VulnerableNormalDraw() public {
        console.log("=== Vulnerable Lottery: Normal User Draw ===\n");

        vm.prank(alice);
        vulnerable.join{value: 0.1 ether}();

        vm.prank(bob);
        vulnerable.join{value: 0.1 ether}();

        console.log("Participants: Alice, Bob");

        // Non-admin draws - no backdoor triggered
        vm.prank(charlie);
        vulnerable.drawWinner();

        address winner = vulnerable.winner();
        console.log("Winner:", winner);

        // Winner should be either Alice or Bob (actual participants)
        bool isValidWinner = (winner == alice || winner == bob);
        assertTrue(isValidWinner, "Winner should be a participant");
        console.log("Normal draw: Winner is a legitimate participant");
    }

    /// @notice Demonstrates secure lottery with verifiable randomness
    function test_SecureLotteryV2FairDraw() public {
        console.log("=== Secure Lottery: Transparent Draw ===\n");

        vm.prank(alice);
        secure.join{value: 0.1 ether}();

        vm.prank(bob);
        secure.join{value: 0.1 ether}();

        vm.prank(charlie);
        secure.join{value: 0.1 ether}();

        console.log("Participants: Alice, Bob, Charlie");
        console.log("Prize pool:", secure.prizePool() / 1e18, "ETH");

        // Commit phase
        console.log("\nInitiating draw (commit phase)...");
        secure.initiateDraw();
        uint256 drawBlock = secure.drawBlock();
        console.log("Draw block:", drawBlock);

        // Mine to draw block
        vm.roll(drawBlock + 1);

        // Reveal phase - admin cannot manipulate
        console.log("\nFinalizing winner (reveal phase)...");
        secure.finalizeWinner();

        address winner = secure.winner();
        console.log("Winner:", winner);

        // Winner must be an actual participant
        bool isParticipant = (winner == alice || winner == bob || winner == charlie);
        assertTrue(isParticipant, "Winner must be a participant");
        assertTrue(winner != admin, "Admin cannot win without participating");
        console.log("Fair draw: Winner is verifiably random participant");
    }

    /// @notice Verifies storage layout exploitation in vulnerable contract
    function test_StorageLayoutAnalysis() public {
        console.log("=== Storage Layout Analysis ===\n");

        vm.prank(alice);
        vulnerable.join{value: 0.1 ether}();

        vm.prank(bob);
        vulnerable.join{value: 0.1 ether}();

        // Inspect storage slots
        bytes32 slot1 = vm.load(address(vulnerable), bytes32(uint256(1)));
        bytes32 slot2 = vm.load(address(vulnerable), bytes32(uint256(2)));

        console.log("Before drawWinner:");
        console.log("  Slot 1 (winner):", address(uint160(uint256(slot1))));
        console.log("  Slot 2 (admin):", address(uint160(uint256(slot2))));

        // Admin exploits backdoor
        vulnerable.drawWinner();

        bytes32 slot1After = vm.load(address(vulnerable), bytes32(uint256(1)));
        console.log("\nAfter admin calls drawWinner:");
        console.log("  Slot 1 (winner):", address(uint160(uint256(slot1After))));

        assertEq(
            address(uint160(uint256(slot1After))), admin, "Assembly backdoor: sload(2) == caller() -> override winner"
        );
    }

    /// @notice Admin wins and claims prize they never contributed to
    function test_FullExploitScenario() public {
        console.log("=== Full Exploit: Admin Drains Prize Pool ===\n");

        uint256 adminBalanceBefore = admin.balance;

        // Users deposit funds
        vm.prank(alice);
        vulnerable.join{value: 0.1 ether}();

        vm.prank(bob);
        vulnerable.join{value: 0.1 ether}();

        vm.prank(charlie);
        vulnerable.join{value: 0.1 ether}();

        console.log("Prize pool: 0.3 ETH from Alice, Bob, Charlie");
        console.log("Admin contributed: 0 ETH");

        // Admin triggers backdoor and claims
        vulnerable.drawWinner();
        vulnerable.claimPrize();

        uint256 adminBalanceAfter = admin.balance;
        uint256 profit = adminBalanceAfter - adminBalanceBefore;

        console.log("\nAdmin profit:", profit / 1e18, "ETH");
        assertEq(profit, 0.3 ether, "Admin stole entire prize pool");
        console.log("RUG PULL COMPLETE: Admin drained all user funds");
    }

    receive() external payable {}
}

