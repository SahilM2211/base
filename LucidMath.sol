// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LucidMath {
    struct Distribution {
        uint256 netPayout;
        uint256 totalFee;
        uint256 adminShare;
        uint256 refShare;
    }

    function calculate(
        uint256 userStake,
        uint256 totalPool,
        uint256 winningPool,
        uint256 feeBasis,
        uint256 refBasis,
        bool hasReferrer
    ) external pure returns (Distribution memory dist) {
        uint256 gross = (userStake * totalPool) / winningPool;
        
        if (totalPool > winningPool) {
            dist.totalFee = (gross * feeBasis) / 10000;
            if (hasReferrer) {
                dist.refShare = (gross * refBasis) / 10000;
                dist.adminShare = dist.totalFee - dist.refShare;
            } else {
                dist.adminShare = dist.totalFee;
            }
        }
        dist.netPayout = gross - dist.totalFee;
    }
}