
function Uninstall-CSmbShare
{
    <#
    .SYNOPSIS
    Uninstalls/removes a file share from the local computer.

    .DESCRIPTION
    The `Uninstall-CSmbShare` function uses `Remove-SmbShare` to uninstall/remove a file share from the local computer,
    if it exists. Pass the name of the share to delete to the `Name` parameter (or pipe the name or share objects to the
    function). If the file share exists, it is deleted. If it doesn't exist, nothing hapens.

    .LINK
    Install-CSmbShare

    .LINK
    Test-CSmbShare

    .EXAMPLE
    Uninstall-CSmbShare -Name 'CarbonShare'

    Demonstrates how to uninstall/remove a share from the local computer. If the share does not exist,
    `Uninstall-CSmbShare` silently does nothing (i.e. it doesn't write an error).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The name of a specific share to uninstall/delete. Wildcards accepted.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String] $Name
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

        $shares = Test-CSmbShare -Name $Name -PassThru
        if (-not $shares)
        {
            return
        }

        foreach ($share in $shares)
        {
            if ($PSCmdlet.ShouldProcess("SMB file share '$($share.Name)'", "remove"))
            {
                Write-Information "Removing SMB file share ""$($share.Name)"" at ""$($share.Path)""."
                $share | Remove-SmbShare -Force -ErrorAction $ErrorActionPreference -WhatIf:$WhatIfPreference
            }
        }
    }
}

