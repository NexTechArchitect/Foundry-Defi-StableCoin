// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(
        AggregatorV3Interface feed
    ) internal view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        if (updatedAt == 0) revert OracleLib__StalePrice();
        if (block.timestamp - updatedAt > TIMEOUT)
            revert OracleLib__StalePrice();

        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }
}
