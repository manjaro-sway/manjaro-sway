# Changelog

## [2.3.1 - October 21st, 2022]
- Fixed: #78 Fix error when the current workspace is null (@fennerm)
- Not user facing: #79 Fixed a bunch of mypy warnings (@fennerm)

## [2.3.0 - September 12th, 2022]
- Added: #74 pyproject.toml config (@Artturin)
- Fixed: #77 Rare race condition when detecting the current workspace (@fennerm)
- Fixed: #78 Traceback when the current workspace is null (@fennerm)
- Not user facing:
    - #74 Misc. code cleanup/ linter fixes (@Artturin)
    - #75 Fix bug in Dockerfile (@Artturin)
    - #77 Add github action for running tests and fix some flakey tests (@fennerm)
    - #76 Add CODEOWNERS file (@fennerm)

## [2.2.5 - July 9th, 2022]
- Fixed: Relax PyYaml dependency (@Artturin)

## [2.2.4 - July 30th, 2021]
- Fixed: Remove pytest from setup.py requirements (as it is not really required).

## [2.2.3 - July 12th, 2021]
- Bump click dependency to v9

## [2.2.2 - August 9th, 2020]
- Added: #55 Emit warning when flash-fullscreen: true in sway.

## [2.2.1 - July 5th, 2020]
- Fixed: Renamed (--loglevel/-l) param to (--verbosity/-v) due to conflict with
  --flash-lone-windows

## [2.2.0 - May 31st, 2020
- Added: --loglevel CLI option
- Fixed: Removed --opacity documentation in help

## [2.1.3] - March 30th, 2020
- Fixed: #46 Accidental bump of required version of i3ipc

## [2.1.2] - March 14th, 2020
- Catch yaml ParserError correctly if config file is invalid
- Removed trailing spaces from conf file (@dakyskye)
- (Hopefully) fixed: #43 - Error when setting rules in config
- Add support for Click 7.0

## [2.1.1] - September 20th, 2019
- Fixed: #39 Crashes when switching tags on dwm
- Handle null NET_WM_STATE when detecting fullscreen

## [2.1.0] - September 20th, 2019
- Added: flash-fullscreen/no-flash-fullscreen config options
- Fixed: Exit without traceback for non-supported wayland WMs
- Fixed: Cleaned up flakey tests

## [2.0.5] - September 14th, 2019
- Add support for marshmallow v3

## [2.0.3] - September 9th, 2019
- Fix typo in marshmallow pin

## [2.0.2] - September 9th, 2019
- Add __init__.py to display_protocols submodule (due to issue with AUR package)

## [2.0.1] - September 8th, 2019
- Temporarily pin marshmallow to v2

## [2.0.0] - September 7th, 2019
- Added sway support
- Dropped python2 support
- Increased minimum pyyaml version to 5.1
- Added i3ipc requirement

## [1.2.7] - May 27th, 2019
- Set windows to default opacity even if they're not flashed (#25)

## [1.2.6] - May 27th, 2019
Added support for marshmallow v3 which is in prerelease

## [1.2.5] - May 26th, 2019
- Stopped using the deprecated inspect.getargspec API in python3

## [1.2.4] - May 26th, 2019
- Bug fix (issue #25)

## [1.2.3] - May 26th, 2019
- No change, please ignore

## [1.2.2] - May 26th, 2019
- No change, please ignore

## [1.2.1] - Jan 27, 2019
- Reverted Pyyaml requirement to >3.0

## [1.2.0] - Jan 20, 2019
- Added: ability to set custom config file location with --config flag
- Fixed: Use marshmallow strict mode due to deprecation warning
- Fixed: Updated pyaml version in requirements due to security vulnerability

## [1.1.1] - Oct 13, 2018 
- Added flash-lone-windows CLI option.

## [1.1.0] - Oct 13, 2018

- Implemented flash-lone-windows configuration option (see default config file
  for details).

## [1.0.9] - Aug 2nd, 2018

- Fixed bug which broke window flashing when transparent windows are also
  active **#18**

## [1.0.8] - Jul 17th, 2018
- Fixed uncaught AttributeError when switching workspaces **#17**

## [1.0.7] - May 27th, 2018
- Fixed incorrect method call in Flasher

## [1.0.6] - May 27th, 2018
- Improved exception handling with nonexistant windows **#15**

## [1.0.5] - May 24th, 2018
- Added MANIFEST file for package data due to bug which caused default config to not be created **#14**

## [1.0.3 - 1.0.4] - May 16th, 2018
- Fixed bug when Xutil function returns None

## [1.0.1] - May 12th, 2018
- Fixed bug in presetting opacity

## [1.0.0] - May 9th, 2018
- Flash parameters can now be set for specific window class/ids. Regexes are supported.
- A faster alternative to the flash_window script (`nc_flash_window`) was added which requires openbsd-netcat. This script is not fully supported yet, so don't be surprised if it disappears later.
- Added a new `flash-on-focus` parameter for windows which user does not want to flash on focus but still needs the ability to flash on request.


## [0.3.5] - April 24th, 2018
- Improved logging output


## [0.3.0] - April 22nd, 2018

- Added a basic configuration file.
- Deprecate --opacity parameter, --flash-opacity should be used instead.

## [0.2.1] - April 14th, 2018

### Fixed
- Uncaught WindowError when window closed during flash.

## [0.2.0] - April 11th, 2018

### Added
- Ability to flash window on keybinding with flash_window command.

### Changed
- Window conflict behavior changed. Previously, if two flash requests were made for a single window within the flash interval, the second request would be ignored. Now the first request is just restarted, which makes the program feel more responsive.
- Removed tendo dependency.
- Added the default-opacity parameter.

### Fixed

- Division error in the python2 version which lead to 1ms flashes by default.

