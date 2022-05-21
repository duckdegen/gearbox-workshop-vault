//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import {ICreditFacade} from "@gearbox-protocol/contracts/src/interfaces/IcreditFacade.sol";
import {ICreditManagerV2} from "@gearbox-protocol/contracts/src/interfaces/ICreditManagerV2.sol";

import {IConvexV1BaseRewardPoolAdapter} from "@gearbox-protocol/contracts/src/interfaces/adapters/convex/IConvexV1BaseRewardPoolAdapter.sol";
import {IYVault} from "@gearbox-protocol/contracts/src/integrations/yearn/IYVault.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CREDIT_MANAGER_V2_DAI, DAI_TOKEN, YEARN_DAI_POOL, CONVEX_3POOL_REWARD_POOL_ADDRESS} from "./Constants.sol";
import "hardhat/console.sol";

enum Strategies {
    Yearn,
    Convex
}

// Pool <-> CreditManager <-> CreditAccount

// GearboxVault ->
// OpenCreditAccount
// Deposit Dai -> GVT
// Withdraw GVT -> DAI
// DAI -> yvDAI
// DAI -> Convex 3CRV pool
// CreditAccount <-> SC Wallet

/// @title Gearbox Vault based on Credit Account
contract GearboxVault is ERC20 {
    using SafeERC20 for ERC20;

    ICreditFacade public immutable creditFacade;
    address public immutable asset;
    address public immutable manager;

    modifier managerOnly() {
        require(msg.sender == manager, "Manager only");
        _;
    }

    constructor() ERC20 ("Gearbox Vault", "GVT") {
        creditFacade = ICreditFacade(
            ICreditManagerV2(CREDIT_MANAGER_V2_DAI).creditFacade()
        );
        asset = DAI_TOKEN;
        manager = msg.sender;
    }

    function openCA() external managerOnly {
        // CHECK: Not to be executed if smartcontract has already opened account

        uint256 amount = ICreditManagerV2(creditFacade.creditManager())
            .minBorrowedAmount() / 4;

        IERC20(amount).transferFrom(msg.sender, address(this), amount);
        
        creditFacade.openCreditAccount(
            amount,
            address(this),
            400, //5x
            0
        );
        _mint(msg.sender, amount);
    }

    function totalAssets() external view returns (uint256) {
        return 0;
    }

    // User -> Amount [Vault] . GVT => Receiver
    function deposit(uint256 amount, address receiver)
        external 
        returns (uint256 shares)
    {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        creditFacade.addCollateral(address(this), asset, amount);

        // increase debt
        // creditFacade.increaseDebt(...)

        // Adapter . deposit()
        address yearnAdapter = creditFacade.contractToAdapter(YEARN_DAI_POOL);
        IYVault(yearnAdapter).deposit();

        // totalValue = sum(pi * ci)
        // share = totalValue / 5 / totalSupply()
        address creditAccount = ICreditManagerV2(creditFacade.creditManager()).getCreditAccountOrRevert(address(this));
        (uint256 totalValue, ) = creditFacade.calcTotalValue(creditAccount);
        uint256 sharePrice = totalValue / 5 / totalSupply();

        shares = amount / sharePrice;
        _mint(receiver, amount);
    } 

    function withdraw(uint256) external returns (uint256 shares) {
        return 0;
    }

    function convertToAssets(uint256 shares) public returns (uint256 assets) {
        return 0;
    }

    function convertToShares(uint256 assets) public returns (uint256 shares) {
        return 0;
    }
}


