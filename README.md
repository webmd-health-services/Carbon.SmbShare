# Overview

The Carbon.SmbShare module installs, tests, and uninstalls SMB file shares. It depends on PowerShell's built-in
[SmbShare](https://learn.microsoft.com/en-us/powershell/module/smbshare/) module.

# System Requirements

* OS: Windows
* PowerShell: 5.1 on .NET 4.6.1+, or 7+
* Dependencies: SmbShare PowerShell module

# Installing

To install globally:

```powershell
Install-Module -Name 'Carbon.SmbShare'
Import-Module -Name 'Carbon.SmbShare'
```

To install privately:

```powershell
Save-Module -Name 'Carbon.SmbShare' -Path '.'
Import-Module -Name '.\Carbon.SmbShare'
```

# Commands

* `Install-CSmbShare`: installs an SMB file share.
* `Test-CSmbShare`: tests if an SMB file share exists.
* `Uninstall-CSmbShare`: uninstalls an SMB file share.
