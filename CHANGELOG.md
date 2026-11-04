# Change Log

## !Deploy

* [Fix] `Invoke-SlackBot`'s `-Token`/`-PSSlackConfigPath` defaults referenced a non-existent `$PSscriptPath` variable (typo for `$PSScriptRoot`), silently resolving relative to the current directory instead of the module folder.
* [Fix] Made the module cross-platform: replaced hardcoded `$Env:USERPROFILE`/`C:\...` path defaults and backslash path separators with `[Environment]::GetFolderPath('UserProfile')`/`Join-Path`/forward slashes, and fixed two stray Unicode en-dash characters that corrupted the built module under Windows PowerShell.

## [1.0.62] - 2019-09-10

* Test deployment.
