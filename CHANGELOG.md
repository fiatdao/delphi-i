# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

- Added bounds validation for the Oracle's alpha parameter. Issue [#66](https://github.com/fiatdao/delphi/issues/66)
- Changed how the minimum threshold value is used when deciding when to push new values into Collybus; previously an absolute values was used, now a percentage change is used. Issue #69
- Merged the CollybusDiscountRateRelayer and CollybusSpotPriceRelayer into a more generic Relayer contract. Issue [#68](https://github.com/fiatdao/delphi/issues/68) 
- Updated AggregatorOracle and Oracle Contracts tests for full coverage. Fix for issue[#74](https://github.com/fiatdao/delphi/issues/74)
- Upgrade Solidity version from 0.8.7 to 0.8.12. Issue [#73](https://github.com/fiatdao/delphi/issues/73)

### Removed