
function Test-CSmbShare
{
    <#
    .SYNOPSIS
    Tests if an SMB file share exists on the local computer.

    .DESCRIPTION
    The `Test-CSmbShare` function uses `Get-SmbShare` from PowerShell's built-in SmbShare module to check if a file
    share exists on the local computer. If the share exists, `Test-CSmbShare` returns `$true`. Otherwise, it returns
    `$false`.

    Use the `-PassThru` switch to return the share object if it exists.

    .LINK
    Install-CSmbShare

    .LINK
    Uninstall-CSmbShare

    .EXAMPLE
    Test-CSmbShare -Name 'CarbonShare'

    Demonstrates how to test of a file share exists.
    #>
    [CmdletBinding()]
    param(
        # The name of a specific share to check.
        [Parameter(Mandatory)]
        [String] $Name,

        [switch] $PassThru
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $share = Get-SmbShare -Name $Name -ErrorAction Ignore

    $shareExists = $null -ne $share

    if ($PassThru)
    {
        if ($shareExists)
        {
            return $share
        }
        return $null
    }

    return $shareExists
}

