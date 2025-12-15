// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {
    DecentralizedStableCoin
} from "../../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is Test {
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;
    Handler public handler;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, engine, ) = deployer.run();

        ERC20Mock weth = ERC20Mock(engine.getCollateralTokens()[0]);
        handler = new Handler(engine, dsc, weth);

        targetContract(address(handler));
    }

    /*//////////////////////////////////////////////////////////////
                              INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Total DSC supply must always be backed by collateral
    function invariant_protocolMustBeOverCollateralized() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalCollateralUsd = _getProtocolCollateralValueUsd();

        assert(totalCollateralUsd >= totalSupply);
    }

    function invariant_dscSupplyNeverExceedsCollateral() public view {
        uint256 supply = dsc.totalSupply();
        uint256 collateralUsd = _getProtocolCollateralValueUsd();

        assert(supply <= collateralUsd);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _getProtocolCollateralValueUsd()
        internal
        view
        returns (uint256 totalUsdValue)
    {
        address[] memory tokens = engine.getCollateralTokens();

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 balance = ERC20Mock(token).balanceOf(address(engine));
            totalUsdValue += engine.getUsdValue(token, balance);
        }
    }
}
