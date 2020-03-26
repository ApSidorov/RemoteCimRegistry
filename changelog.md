# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.0.0] - 2020-03-25
### Added
- All functions: ComputerName parameter now accepts 'localhost' and '.' as arguments. To copy registry keys/values from a remote computer to the local registry.
- All functions: Path parameter accepts short root key names, e.g. HKLM instead of HKEY_LOCAL_MACHINE.
- Set-RegistryValue: Force parameter creates registry key if it's not exist on a target computer.
- Get-RegistryKey: now returns a registry key object even if you have no access to a key. SubKeyCount and ValueCount properties will show 'ERROR' instead of numbers.

### Changed
- Table view for the RegistryValue object now shows the type of an invalid data.
- Table view for the RegistryValue and RegistryKey types now have dynamic column width. Let PowerShell decide how to show them.
