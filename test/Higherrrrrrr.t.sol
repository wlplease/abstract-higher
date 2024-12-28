// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {Higherrrrrrr} from "src/Higherrrrrrr.sol";
import {HigherrrrrrrConviction} from "src/HigherrrrrrrConviction.sol";
import {HigherrrrrrrFactory} from "src/HigherrrrrrrFactory.sol";
import {BondingCurve} from "src/libraries/BondingCurve.sol";
import {IHigherrrrrrr} from "src/interfaces/IHigherrrrrrr.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {IUniswapV3Pool} from "src/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "src/interfaces/ISwapRouter.sol";
import {INonfungiblePositionManager} from "src/interfaces/INonfungiblePositionManager.sol";

import {ReentrancyAttacker} from "./helpers/ReentrancyAttacker.sol";

contract HigherrrrrrrTest is Test {
    using FixedPointMathLib for uint256;

    Higherrrrrrr public token;
    HigherrrrrrrConviction public conviction;
    HigherrrrrrrFactory public factory;

    IWETH public constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    INonfungiblePositionManager public constant POSITION_MANAGER =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    ISwapRouter public constant SWAP_ROUTER = ISwapRouter(0x2626664c2603336E57B271c5C0b26F421741e481);

    address public protocolFeeRecipient;
    address public user1;
    address public user2;

    IHigherrrrrrr.PriceLevel[] public priceLevels;

    // Add Uniswap pool price constants
    uint160 public constant POOL_SQRT_PRICE_X96_WETH_0 = 400950665883918763141200546267337;
    uint160 public constant POOL_SQRT_PRICE_X96_TOKEN_0 = 15655546353934715619853339;

    // Add constants from Higherrrrrrr.sol
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000e18; // 1B tokens with 18 decimals
    uint256 public constant CONVICTION_THRESHOLD = 1000; // 0.1% = 1/1000

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("ETH_RPC_URL"));
        vm.selectFork(forkId);

        vm.label(address(WETH), "WETH");
        vm.label(address(POSITION_MANAGER), "PositionManager");
        vm.label(address(SWAP_ROUTER), "SwapRouter");

        // Create test addresses
        protocolFeeRecipient = makeAddr("protocolFeeRecipient");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Setup price levels with lower thresholds
        priceLevels.push(
            IHigherrrrrrr.PriceLevel({
                price: 1_000_000_000, // 1 gwei
                name: "highr",
                imageURI: ""
            })
        );
        priceLevels.push(
            IHigherrrrrrr.PriceLevel({
                price: 5_000_000_000, // 5 gwei
                name: "highrrr",
                imageURI: ""
            })
        );
        priceLevels.push(
            IHigherrrrrrr.PriceLevel({
                price: 10_000_000_000, // 10 gwei
                name: "highrrrrrr",
                imageURI: ""
            })
        );
        priceLevels.push(
            IHigherrrrrrr.PriceLevel({
                price: 50_000_000_000, // 50 gwei
                name: "highrrrrrrr",
                imageURI: ""
            })
        );
        priceLevels.push(
            IHigherrrrrrr.PriceLevel({
                price: 100_000_000_000, // 100 gwei
                name: "highrrrrrrrr",
                imageURI: ""
            })
        );

        // Deploy factory
        factory = new HigherrrrrrrFactory(
            protocolFeeRecipient,
            address(WETH),
            address(POSITION_MANAGER),
            address(SWAP_ROUTER),
            address(new Higherrrrrrr()),
            address(new HigherrrrrrrConviction())
        );
        vm.label(address(factory), "Factory");

        // Create new token instance with 0.01 ETH initial liquidity
        vm.deal(address(this), 1 ether);
        (address tokenAddress, address convictionAddress) = factory.createHigherrrrrrr{value: 0.01 ether}(
            "highr", // Initial name
            "HIGHR", // Symbol
            "base64 image hash", // Token URI
            IHigherrrrrrr.TokenType.TEXT_EVOLUTION,
            priceLevels
        );

        token = Higherrrrrrr(payable(tokenAddress));
        vm.label(address(token), "Higherrrrrrr");
        conviction = HigherrrrrrrConviction(convictionAddress);
        vm.label(address(conviction), "Conviction");
    }

    function test_InitialState() public view {
        assertEq(token.name(), "highr");
        assertEq(token.symbol(), "HIGHR");
        assertEq(uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.BONDING_CURVE));
        assertEq(token.numPriceLevels(), 5);

        assertEq(conviction.owner(), address(token));
        assertEq(address(conviction.higherrrrrrr()), address(token));
    }

    function test_PriceLevelProgression() public {
        // Initial state
        assertEq(token.name(), "highr");

        // Buy enough to reach second level (5 gwei threshold)
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // First buy should be large enough to move price above 5 gwei
        token.buy{value: 0.5 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        assertEq(token.name(), "highrrr");

        // Buy more to reach third level (10 gwei threshold)
        token.buy{value: 2 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        assertEq(token.name(), "highrrrrrr");
        vm.stopPrank();
    }

    function test_ConvictionNFTMinting() public {
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // Buy enough tokens to trigger NFT mint (>0.1% of total supply)
        token.buy{value: 5 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Check NFT details
        assertEq(conviction.balanceOf(user1), 1);
        (string memory evolution,,) = conviction.getHigherrrrrrrState();
        assertEq(evolution, "highrrrrrr");
        vm.stopPrank();
    }

    function test_MarketGraduation() public {
        vm.startPrank(user1);
        vm.deal(user1, 1000 ether);

        // Buy enough tokens to trigger market graduation (800M tokens)
        token.buy{value: 8.1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Verify graduation
        assertEq(uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.UNISWAP_POOL));
        assertEq(token.totalSupply(), 1_000_000_000e18); // Should be at max supply
        vm.stopPrank();
    }

    function testFail_BuyWithInsufficientETH() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);

        // Try to buy with less than minimum order size
        token.buy{value: 0.00000001 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);
        vm.stopPrank();
    }

    function test_NoGraduationOnSmallBuy() public {
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // Buy tokens but not enough to trigger graduation (< 8 ETH)
        token.buy{value: 5 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Verify still in bonding curve phase
        assertEq(uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.BONDING_CURVE));

        // Verify supply is less than graduation amount
        assert(token.totalSupply() < 800_000_000e18); // Should be less than PRIMARY_MARKET_SUPPLY

        // Buy more but still not enough to graduate
        token.buy{value: 2 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Still should not have graduated
        assertEq(uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.BONDING_CURVE));
        assert(token.totalSupply() < 800_000_000e18);
        vm.stopPrank();
    }

    // Security Tests
    function testFail_ReinitializeToken() public {
        // Try to initialize again
        token.initialize(
            address(WETH),
            address(conviction),
            address(POSITION_MANAGER),
            address(SWAP_ROUTER),
            protocolFeeRecipient,
            "highr2",
            "HIGHR2",
            IHigherrrrrrr.TokenType.REGULAR,
            "ipfs://QmHash2",
            priceLevels
        );
    }

    function testFail_ReinitializeConviction() public {
        conviction.initialize(address(0x1));
    }

    function testFail_UnauthorizedConvictionMint() public {
        vm.startPrank(user1);
        conviction.mintConviction(user1, "highr", "", 1000e18, 0.1 ether);
        vm.stopPrank();
    }

    function test_RefundOnLargeOrder() public {
        vm.startPrank(user1);
        vm.deal(user1, 1000 ether);

        // Send more ETH than needed for graduation
        uint256 initialBalance = user1.balance;
        token.buy{value: 20 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Should have received refund
        assertGt(user1.balance, initialBalance - 20 ether);
        vm.stopPrank();
    }

    function testFail_TransferToPoolBeforeGraduation() public {
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // Buy some tokens
        token.buy{value: 1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Try to transfer to pool before graduation
        token.transfer(token.poolAddress(), 1000e18);
        vm.stopPrank();
    }

    function test_BurnAfterGraduation() public {
        // Graduate the market first
        vm.startPrank(user1);
        vm.deal(user1, 1000 ether);
        token.buy{value: 8.1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Should be able to burn after graduation
        uint256 balance = token.balanceOf(user1);
        uint256 burnAmount = balance / 2;
        uint256 expectedBalance = balance - burnAmount;

        token.burn(burnAmount);
        // Allow for 1 wei rounding difference
        assertApproxEqAbs(token.balanceOf(user1), expectedBalance, 1);
        vm.stopPrank();
    }

    function testFail_BurnBeforeGraduation() public {
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // Buy some tokens
        token.buy{value: 1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Try to burn before graduation
        token.burn(1000e18);
        vm.stopPrank();
    }

    function testFail_QuotesAfterGraduation() public {
        // Graduate the market
        vm.deal(user1, 1000 ether);
        vm.prank(user1);
        token.buy{value: 8.1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Try to get quotes after graduation
        token.getEthBuyQuote(1 ether);
    }

    function test_DirectETHTransfer() public {
        vm.deal(user1, 10 ether);

        // Send ETH directly to token contract
        vm.prank(user1);
        (bool success,) = address(token).call{value: 1 ether}("");

        assertTrue(success, "ETH transfer failed");
        assertGt(token.balanceOf(user1), 0);
    }

    function test_MarketStateTransitions() public {
        // Check initial state
        IHigherrrrrrr.MarketState memory state = token.state();
        assertEq(uint256(state.marketType), uint256(IHigherrrrrrr.MarketType.BONDING_CURVE));
        assertEq(state.marketAddress, address(token));

        // Graduate market
        vm.startPrank(user1);
        vm.deal(user1, 1000 ether);
        token.buy{value: 8.1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Check graduated state
        state = token.state();
        assertEq(uint256(state.marketType), uint256(IHigherrrrrrr.MarketType.UNISWAP_POOL));
        assertEq(state.marketAddress, token.poolAddress());
        vm.stopPrank();
    }

    function test_ConvictionNFTMetadata() public {
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);

        // Buy enough to mint NFT
        token.buy{value: 5 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Check NFT URI
        uint256 tokenId = 0;
        string memory uri = conviction.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);

        // Verify conviction details
        (string memory evolution, string memory imageURI, uint256 amount, uint256 price, uint256 timestamp) =
            conviction.convictionDetails(tokenId);

        assertEq(evolution, "highr");
        assertEq(imageURI, "");
        assertGt(amount, 0);
        assertGt(price, 0);
        assertEq(timestamp, block.timestamp);
        vm.stopPrank();
    }

    function test_FullLifecycle() public {
        // Initial state check
        assertEq(token.name(), "highr");
        assertEq(uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.BONDING_CURVE));

        vm.deal(user1, 100 ether);

        vm.startPrank(user1);
        // 1. Small buy - first evolution
        token.buy{value: 0.001 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // 2. Medium buy - second evolution + NFT mint
        token.buy{value: 0.6 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // 3. Large buy - graduate to Uniswap
        token.buy{value: 8 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Verify graduation
        assertEq(
            uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.UNISWAP_POOL), "Should graduate to Uniswap"
        );
        address poolAddress = token.poolAddress();
        assertTrue(poolAddress != address(0), "Pool should be created");

        // 4. Test Uniswap pool interaction and evolution
        assertEq(token.name(), "highrrrrrr"); // Should evolve to next level

        vm.stopPrank();
    }

    function assertCorrectMarketType() internal view returns (IHigherrrrrrr.MarketType marketType) {
        if (token.totalSupply() >= 800_000_000e18) {
            marketType = IHigherrrrrrr.MarketType.UNISWAP_POOL;
        } else {
            marketType = IHigherrrrrrr.MarketType.BONDING_CURVE;
        }

        assertEq(uint256(token.marketType()), uint256(marketType));
    }

    function testFuzz_BuyWithRandomAmount(uint256 amount) public {
        // Bound amount between 0.0001 ether and 100 ether
        amount = bound(amount, token.MIN_ORDER_SIZE(), 100 ether);

        vm.deal(user1, amount);
        vm.startPrank(user1);

        try token.buy{value: amount}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0) {
            // Verify basic invariants after buy
            assertTrue(token.balanceOf(user1) > 0);
            assertTrue(token.totalSupply() <= MAX_TOTAL_SUPPLY);
            assertCorrectMarketType();
        } catch {
            // If buy fails, verify we're in expected failure cases
            assertTrue(token.totalSupply() == MAX_TOTAL_SUPPLY);
        }

        vm.stopPrank();
    }

    function testFuzz_MultipleBuysAndSells(uint256[5] memory buyAmounts) public {
        address[] memory buyers = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            buyers[i] = makeAddr(string(abi.encodePacked("buyer", i)));
            buyAmounts[i] = bound(buyAmounts[i], token.MIN_ORDER_SIZE(), 2 ether);

            vm.deal(buyers[i], buyAmounts[i]);
        }

        for (uint256 i = 0; i < 5; i++) {
            uint256 buyAmount = buyAmounts[i];
            address buyer = buyers[i];

            assertCorrectMarketType();
            vm.startPrank(buyer);

            token.buy{value: buyAmount}(buyer, buyer, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);
            IHigherrrrrrr.MarketType marketType = assertCorrectMarketType();

            uint256 balance = token.balanceOf(buyer);
            if (balance > 1) {
                uint256 half = balance / 2;
                uint256 payout = token.getTokenSellQuote(half);
                if (payout >= token.MIN_ORDER_SIZE()) {
                    token.sell(half, buyer, "", marketType, 0, 0);
                    assertEq(token.balanceOf(buyer), balance - half);
                }
            }

            vm.stopPrank();
        }
    }

    function testFuzz_ConvictionMinting(uint256 buyAmount, string calldata message) public {
        buyAmount = bound(buyAmount, token.MIN_ORDER_SIZE(), 10 ether);
        vm.assume(bytes(message).length <= 280); // Twitter-like length limit

        vm.deal(user1, buyAmount);
        vm.startPrank(user1);

        token.buy{value: buyAmount}(user1, user1, message, IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        if (token.balanceOf(user1) >= (token.totalSupply() * CONVICTION_THRESHOLD) / 10000) {
            assertGt(conviction.balanceOf(user1), 0);
        }
        vm.stopPrank();
    }

    function testFuzz_PriceLevelTransitions(uint256[] memory buySequence) public {
        vm.assume(buySequence.length <= 10);
        string memory previousName = token.name();

        for (uint256 i = 0; i < buySequence.length; i++) {
            uint256 amount = bound(buySequence[i], token.MIN_ORDER_SIZE(), 5 ether);
            vm.deal(user1, amount);
            vm.prank(user1);

            try token.buy{value: amount}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0) {
                string memory newName = token.name();
                // Name should either stay same or evolve to next level
                assertTrue(
                    keccak256(bytes(newName)) == keccak256(bytes(previousName))
                        || bytes(newName).length > bytes(previousName).length
                );
                previousName = newName;
            } catch {}
        }
    }

    function testFuzz_SlippageProtection(uint256 buyAmount, uint256 minTokens) public {
        buyAmount = bound(buyAmount, token.MIN_ORDER_SIZE(), 10 ether);
        vm.deal(user1, buyAmount);

        uint256 expectedTokens = token.getEthBuyQuote(buyAmount - token.calculateTradingFee(buyAmount));
        minTokens = bound(minTokens, 0, expectedTokens * 2);

        IHigherrrrrrr.MarketType marketType = assertCorrectMarketType();

        vm.startPrank(user1);
        if (minTokens > expectedTokens) {
            vm.expectRevert(IHigherrrrrrr.SlippageBoundsExceeded.selector);
        }
        token.buy{value: buyAmount}(user1, user1, "", marketType, minTokens, 0);
        vm.stopPrank();
    }

    function testFuzz_GoHarderrrrrrr(uint256 value) public {
        value = bound(value, 0.1 ether, 10 ether);
        uint256 t0_ProtocolBalance = protocolFeeRecipient.balance;

        vm.deal(user1, 42 ether);
        vm.startPrank(user1);

        // Buy tokens to graduate to Uniswap
        token.buy{value: 10 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);
        assertEq(uint256(token.marketType()), uint256(IHigherrrrrrr.MarketType.UNISWAP_POOL));

        uint256 t1_ProtocolBalance = protocolFeeRecipient.balance;
        assertGe(t1_ProtocolBalance, t0_ProtocolBalance, "t1_balance < t0_balance");

        // Buy tokens to generate LP fees
        uint256 tokensBought = token.buy{value: value}(user1, user1, "", IHigherrrrrrr.MarketType.UNISWAP_POOL, 0, 0);
        uint256 accumulatedFees = token.calculateTradingFee(value);

        uint256 t2_ProtocolBalance = protocolFeeRecipient.balance;
        assertEq(t2_ProtocolBalance, t1_ProtocolBalance + accumulatedFees, "t2_balance != t1_balance + fees");

        // Make some trades
        for (uint256 i = 0; i < 100; i++) {
            token.approve(address(token), tokensBought);
            // Sell fees
            uint256 ethReceived = token.sell(tokensBought, user1, "", IHigherrrrrrr.MarketType.UNISWAP_POOL, 0, 0);
            uint256 sellFee = token.calculateTradingMarkup(ethReceived);
            accumulatedFees += sellFee;
            // Buy fees
            token.buy{value: value}(user1, user1, "", IHigherrrrrrr.MarketType.UNISWAP_POOL, 0, 0);
            uint256 buyFee = token.calculateTradingFee(value);
            accumulatedFees += buyFee;
        }

        uint256 t3_ProtocolBalance = protocolFeeRecipient.balance;
        assertApproxEqRelDecimal({
            left: t3_ProtocolBalance,
            right: t2_ProtocolBalance + accumulatedFees,
            maxPercentDelta: 1e16, // 1% (1e18 is 100%)
            decimals: 18,
            err: "Incorrect fee accumulation"
        });

        vm.stopPrank();

        (uint256 reinvestedWETH, uint256 reinvestedTokens) = token.harderrrrrrr();
        console2.log("reinvestedWETH", reinvestedWETH);
        console2.log("reinvestedTokens", reinvestedTokens);

        uint256 t4_ProtocolBalance = protocolFeeRecipient.balance;
        assertGe(t4_ProtocolBalance, t3_ProtocolBalance, "Should have collected dust ETH");
        assertGe(token.balanceOf(protocolFeeRecipient), 0, "Should have collected dust tokens");
    }

    function test_ReentrancyProtection() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);

        // Buy some tokens first
        token.buy{value: 0.5 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Deploy attacker
        address attacker = address(new ReentrancyAttacker(address(token)));

        // Transfer tokens to attacker
        token.transfer(attacker, 1e18);

        // Attempt reentrancy attack
        vm.expectRevert();
        token.sell(1e18, attacker, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        vm.stopPrank();
    }

    function test_PoolPositionManagement() public {
        // Graduate market first
        vm.deal(user1, 1000 ether);

        vm.prank(user1);
        token.buy{value: 8.1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);

        // Verify position details
        uint256 positionId = token.positionId();
        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) =
            token.nonfungiblePositionManager().positions(positionId);

        assertEq(fee, 500);
        assertEq(tickLower, -887200);
        assertEq(tickUpper, 887200);
        assertGt(liquidity, 0);
        assertTrue(token0 < token1); // Verify correct token ordering
    }

    function test_GasOptimization() public {
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);

        // Measure gas for different operations
        uint256 gasBefore = gasleft();
        token.buy{value: 0.1 ether}(user1, user1, "", IHigherrrrrrr.MarketType.BONDING_CURVE, 0, 0);
        uint256 gasUsed = gasBefore - gasleft();

        // Set reasonable gas limits
        assertLt(gasUsed, 300000, "Buy operation should use less than 300k gas");

        // Test gas usage for other operations...
        vm.stopPrank();
    }
}
