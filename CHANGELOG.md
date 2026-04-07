
# Carbon.SmbShare Changelog

## 1.0.0

### Upgrade Instructions

If migrating from Carbon:

* Rename usages of `Install-CFileShare` to `Install-CSmbShare`.
* Rename usages of `Test-CFileShare` to `Test-CSmbShare`.
* Rename usages of `Uninstall-CFileShare` to `Uninstall-CSmbShare`.
* `Install-CSmbShare`, `Uninstall-CSmbShare`, and `Test-CSmbShare` re-written to use PowerShell's built-in `SmbShare`
  PowerShell module. Test accordingly.
* Remove usages of the `Install-CSmbShare` function's `-Force` switch. If you want to always re-create a share, call
  `Uninstall-CSmbShare` before calling `Install-CSmbShare`.
* `Install-CSmbShare` now removes the default `Everyone` `Read` access rule if no read access is given. If you want
  `Everyone` to continue to have access, pass `Everyone` to the `Install-CSmbShare` function's `ReadAccess` parameter.
* Replace usages of `Get-CFileShare` with PowerShell's built-in `Get-SmbShare`.
* Replace usages of `Get-CFileSharePermission` with PowerShell's built-in `Get-SmbShareAccess`.
* Added WhatIf support to `Install-CSmbShare` and `Uninstall-CSmbShare`.
