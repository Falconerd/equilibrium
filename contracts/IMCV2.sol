// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IMCV2 {
    struct PoolInfo {
        uint128 accBooPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    function BOO() external returns (address);
    function booPerSecond() external returns (uint);
    function getFarmData(uint pid) external returns (uint, address);
    function isLpToken(address token) external returns (bool);
    function lpToken(uint pid) external returns (address);
    function pendingBOO(uint pid, address user) external returns(uint);
    function poolInfo(uint pid) external returns (PoolInfo memory);
    function poolLength() external returns (uint);
    function totalAllocPoint() external returns (uint);
    function userInfo(uint pid, uint account) external returns (UserInfo memory);

    function deposit(uint pid, uint amount) external;
    function withdraw(uint pid, uint amount) external;
}
