# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added StaticRelayer contract which is used to update a pre-determined rate for a predefined token id to Collybus once and only once

### Changed

- Added bounds validation for the Oracle's alpha parameter. Issue [#66](https://github.com/fiatdao/delphi/issues/66)
- Changed how the minimum threshold value is used when deciding when to push new values into Collybus; previously an absolute values was used, now a percentage change is used. Issue [#69](https://github.com/fiatdao/delphi/issues/69)
- Merged the CollybusDiscountRateRelayer and CollybusSpotPriceRelayer into a more generic Relayer contract. Issue [#68](https://github.com/fiatdao/delphi/issues/68) 
- Added reentrancy guard for `Oracle.update()`
- Updated AggregatorOracle and Oracle Contracts tests for full coverage. Fix for issue[#74](https://github.com/fiatdao/delphi/issues/74)
- Added guard checks to the Oracle update flow. Fix for issue[#81](https://github.com/fiatdao/delphi/issues/81)
- Redesigned some events in `AggregatorOracle` to also emit the oracle's address. Issue [#79](https://github.com/fiatdao/delphi/issues/79)
- Upgrade Solidity version from 0.8.7 to 0.8.12. Issue [#73](https://github.com/fiatdao/delphi/issues/73)
- Changed execution flow for `executeWithRevert` to allow for oracle updates even if no update to Collybus was performed. Issue [#83](https://github.com/fiatdao/delphi/issues/83)
- Updated `Relayer.execute()` to return whether a keeper should execute or not the current transaction instead of if Collybus was updated. Fix for issue [#125](https://github.com/fiatdao/delphi/issues/125)
- Added Market sanity checks for the NotionalFinanceValueProvider Oracle. Fix for issue [#127](https://github.com/fiatdao/delphi/issues/127)
- Computed settlementDate internally instead of having it as a required parameter when deploying the NotionalFinanceValueProvider Oracle.
- YieldValueProvider `getValue()` can be called only by the oracle contract.

### Removed