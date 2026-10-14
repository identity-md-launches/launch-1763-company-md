// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Company.md token
/// @notice Fixed supply of one billion COMD with 18 decimals, minted once to the deployer.
/// @dev The deploying factory receives the entire supply when deployed through a factory.
/// There are no administrative roles, external mint/burn functions, or transfer fees.
contract CompanyToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("Company.md", "COMD") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
