// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract DSCEngineTest is StdCheats, Test {
    event CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeemTo,
        address token,
        uint256 amount
    );


    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 public amountCollateral = 10 ether;
    uint256 public amountToMint = 100 ether;

    address public user = address(1);
    address public liquidator = makeAddr("liquidator");

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public collateralToCover = 20 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (
            ethUsdPriceFeed,
            btcUsdPriceFeed,
            weth,
            wbtc,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }

        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    address[] public tokenAddresses;
    address[] public feedAddresses;

    /////////////////////////////////////////
    // BASIC TESTS
    /////////////////////////////////////////

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch
                .selector
        );
        new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
    }

    function testGetTokenAmountFromUsd() public {
        assertEq(dsce.getTokenAmountFromUsd(weth, 100 ether), 0.05 ether);
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15 ether;
        uint256 expectedUsd = 30_000 ether;
        assertEq(dsce.getUsdValue(weth, ethAmount), expectedUsd);
    }

    ///////////////////////////////////////////
    // COLLATERAL TESTS
    ///////////////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("R", "R");

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__TokenNotAllowed.selector,
                address(randToken)
            )
        );
        dsce.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    ///////////////////////////////////////////
    // MODIFIERS
    ///////////////////////////////////////////

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    //////////////////////////////////////////////
    // ACCOUNT & HEALTH FACTOR TESTS
    //////////////////////////////////////////////

    function testCanDepositCollateralWithoutMinting()
        public
        depositedCollateral
    {
        assertEq(dsc.balanceOf(user), 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo()
        public
        depositedCollateral
    {
        (uint256 totalMinted, uint256 val) = dsce.getAccountInformation(user);
        assertEq(totalMinted, 0);
        assertEq(val, dsce.getUsdValue(weth, amountCollateral));
    }

    function testProperlyReportsHealthFactor()
        public
        depositedCollateralAndMintedDsc
    {
        uint256 expected = 100 ether;
        assertEq(dsce.getHealthFactor(user), expected);
    }

    function testHealthFactorCanGoBelowOne()
        public
        depositedCollateralAndMintedDsc
    {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(18e8);
        assertEq(dsce.getHealthFactor(user), 0.9 ether);
    }

    /////////////////////////////////////////////
    // MINT TESTS
    /////////////////////////////////////////////

    function testCannotMintWithoutDepositingCollateral() public {
        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                0
            )
        );
        dsce.mintDsc(amountToMint);

        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public depositedCollateral {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor()
        public
        depositedCollateral
    {
        (, int256 price, , , ) = MockV3Aggregator(ethUsdPriceFeed)
            .latestRoundData();

        amountToMint =
            (amountCollateral *
                (uint256(price) * dsce.getAdditionalFeedPrecision())) /
            dsce.getPrecision();

        vm.startPrank(user);

        uint256 expectedHF = dsce.calculateHealthFactor(
            amountToMint,
            dsce.getUsdValue(weth, amountCollateral)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                expectedHF
            )
        );

        dsce.mintDsc(amountToMint);

        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        dsce.mintDsc(amountToMint);
        assertEq(dsc.balanceOf(user), amountToMint);
    }

    /////////////////////////////////////////////
    // BURN TESTS
    /////////////////////////////////////////////

    function testRevertsIfBurnAmountIsZero()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnDsc(amountToMint);
        vm.stopPrank();

        assertEq(dsc.balanceOf(user), 0);
    }

    /////////////////////////////////////////////////
    // REDEEM TESTS
    /////////////////////////////////////////////////

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);

        uint256 beforeBal = dsce.getCollateralBalanceOfUser(user, weth);
        assertEq(beforeBal, amountCollateral);

        dsce.redeemCollateral(weth, amountCollateral);

        assertEq(dsce.getCollateralBalanceOfUser(user, weth), 0);

        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs()
        public
        depositedCollateral
    {
        vm.expectEmit(true, true, true, true, address(dsce));
        emit CollateralRedeemed(user, user, weth, amountCollateral);

        vm.startPrank(user);
        dsce.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////
    // REDEEM FOR DSC
    /////////////////////////////////////////////////

    function testMustRedeemMoreThanZero()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);

        dsc.approve(address(dsce), amountToMint);
        dsce.redeemCollateralForDsc(weth, amountCollateral, amountToMint);

        vm.stopPrank();

        assertEq(dsc.balanceOf(user), 0);
    }

    /////////////////////////////////////////////////
    // LIQUIDATION TESTS
    /////////////////////////////////////////////////

    modifier liquidated() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(18e8);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);

        dsc.approve(address(dsce), amountToMint);

        dsce.liquidate(weth, user, amountToMint);

        vm.stopPrank();

        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 bal = ERC20Mock(weth).balanceOf(liquidator);

        uint256 expected = dsce.getTokenAmountFromUsd(weth, amountToMint) +
            ((dsce.getTokenAmountFromUsd(weth, amountToMint) *
                dsce.getLiquidationBonus()) / dsce.getLiquidationPrecision());

        assertEq(bal, expected);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        uint256 liquidatedAmount = dsce.getTokenAmountFromUsd(
            weth,
            amountToMint
        ) +
            ((dsce.getTokenAmountFromUsd(weth, amountToMint) *
                dsce.getLiquidationBonus()) / dsce.getLiquidationPrecision());

        uint256 usdLiquidated = dsce.getUsdValue(weth, liquidatedAmount);

        uint256 expected = dsce.getUsdValue(weth, amountCollateral) -
            usdLiquidated;

        (, uint256 userValue) = dsce.getAccountInformation(user);

        assertEq(userValue, expected);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 minted, ) = dsce.getAccountInformation(liquidator);
        assertEq(minted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userMinted, ) = dsce.getAccountInformation(user);
        assertEq(userMinted, 0);
    }

    /////////////////////////////////////////////////
    // GETTERS (2 EXTRA TESTS TO REACH 40/40)
    /////////////////////////////////////////////////

    function testGetCollateralTokenPriceFeed() public {
        assertEq(dsce.getCollateralTokenPriceFeed(weth), ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory c = dsce.getCollateralTokens();
        assertEq(c[0], weth);
    }

    function testGetMinHealthFactor() public {
        assertEq(dsce.getMinHealthFactor(), MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        assertEq(dsce.getLiquidationThreshold(), LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        assertEq(
            dsce.getAccountCollateralValue(user),
            dsce.getUsdValue(weth, amountCollateral)
        );
    }

    function testGetAccountCollateralValueFromInformation()
        public
        depositedCollateral
    {
        (, uint256 value) = dsce.getAccountInformation(user);
        assertEq(value, dsce.getUsdValue(weth, amountCollateral));
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        assertEq(dsce.getCollateralBalanceOfUser(user, weth), amountCollateral);
    }

    // EXTRA TEST #39
    function testGetHealthFactor() public depositedCollateralAndMintedDsc {
        uint256 expected = dsce.calculateHealthFactor(
            amountToMint,
            dsce.getUsdValue(weth, amountCollateral)
        );
        assertEq(dsce.getHealthFactor(user), expected);
    }

    // EXTRA TEST #40
    function testGetAdditionalFeedPrecision() public {
        assertEq(dsce.getAdditionalFeedPrecision(), 1e10);
    }

    function testGetDsc() public {
        assertEq(dsce.getDsc(), address(dsc));
    }

    function testLiquidationPrecision() public {
        assertEq(dsce.getLiquidationPrecision(), 100);
    }

    // 1) deposit two different collateral tokens and check combined USD value
    function testDepositMultipleCollateralAndAccountValue() public {
        // mint & approve for user for both tokens
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        ERC20Mock(wbtc).approve(address(dsce), amountCollateral);

        // deposit same 'amountCollateral' for both
        dsce.depositCollateral(weth, amountCollateral);
        dsce.depositCollateral(wbtc, amountCollateral);
        vm.stopPrank();

        // expected = usd(weth, amountCollateral) + usd(wbtc, amountCollateral)
        uint256 expected = dsce.getUsdValue(weth, amountCollateral) +
            dsce.getUsdValue(wbtc, amountCollateral);

        (, uint256 actual) = dsce.getAccountInformation(user);
        assertEq(actual, expected);
    }

    // 2) trying to redeem more than deposited should revert (underflow / safety)
    function testRedeemMoreThanDepositedReverts() public depositedCollateral {
        vm.startPrank(user);
        // try to redeem more than deposited -> should revert
        vm.expectRevert();
        dsce.redeemCollateral(weth, amountCollateral + 1);
        vm.stopPrank();
    }

    // 3) mint then burn: minted accounting and balances update correctly
    function testMintThenBurnReducesDebtAndBalances()
        public
        depositedCollateral
    {
        // mint
        vm.prank(user);
        dsce.mintDsc(amountToMint);
        assertEq(dsc.balanceOf(user), amountToMint);

        // approve and burn entire minted amount
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnDsc(amountToMint);
        vm.stopPrank();

        // internal accounting should show user minted = 0 and token balance 0
        (uint256 minted, ) = dsce.getAccountInformation(user);
        assertEq(minted, 0);
        assertEq(dsc.balanceOf(user), 0);
    }

    // 4) getTokenAmountFromUsd with zero USD should return zero tokens
    function testGetTokenAmountFromUsdZeroReturnsZero() public {
        uint256 res = dsce.getTokenAmountFromUsd(weth, 0);
        assertEq(res, 0);
    }

    // 5) liquidate a healthy user should revert with HealthFactorOk
    function testCannotLiquidateHealthyUserReverts() public {
        // ensure caller is some other address
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, user, 1 ether);
        vm.stopPrank();
    }
}
