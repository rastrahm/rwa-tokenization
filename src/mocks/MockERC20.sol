// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Stablecoin de lab (USDC/USDT) con mint libre para tests y scripts.
contract MockERC20 is ERC20 {
    uint8 private immutable DECIMALS_;

    /// @param name_ Nombre del token.
    /// @param symbol_ Símbolo.
    /// @param decimals_ Decimales (6 para USDC lab).
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        DECIMALS_ = decimals_;
    }

    /// @notice Decimales configurables (USDC = 6).
    function decimals() public view override returns (uint8) {
        return DECIMALS_;
    }

    /// @notice Mintea tokens de prueba.
    /// @param to Destinatario.
    /// @param amount Cantidad.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
