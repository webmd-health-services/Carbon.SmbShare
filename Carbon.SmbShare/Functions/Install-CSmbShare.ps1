
function Install-CSmbShare
{
    <#
    .SYNOPSIS
    Installs an SMB file share.

    .DESCRIPTION
    The `Install-CSmbShare` function installs an SMB file share. If the share doesn't exist, it is created. If a share
    exists, its description and permissions are updated in place. If its path is changing, the share is deleted and
    re-created. If the path to the share doesn't exist, it is created.

    Use the `FullAccess`, `ChangeAccess`, and `ReadAccess` parameters to grant full, change, and read permissions on the
    share. Each parameter takes a list of user/group names. Only the users and groups in the `FullAccess`,
    `ChangeAccess`, and `ReadAccess` parameters will be given access. Any accounts that have access that aren't in one
    of the specified lists will have their permissions removed, including the default `Everyone` read access rule. Make
    sure to pass `Everyone` to the `ReadAccess` parameter if you want everyone to have access!

    Permissions don't apply to the file system, only to the share. Use the Carbon.FileSystem module's
    `Grant-CNtfsPermission` function to grant file system permissions or use the
    [SmbShare](https://learn.microsoft.com/en-us/powershell/module/smbshare/) module's `Set-SmbPathAcl`.

    .LINK
    Test-CSmbShare

    .LINK
    Uninstall-CSmbShare

    .EXAMPLE
    Install-CSmbShare -Name TopSecretDocuments -Path C:\TopSecret -Description 'Share for our top secret documents.' -ReadAccess "Everyone" -FullAccess "Analysts"

    Shares the C:\TopSecret directory as `TopSecretDocuments` and grants `Everyone` read access and `Analysts` full
    control.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The share's name.
        [Parameter(Mandatory)]
        [String] $Name,

        # The path to the share. Is created if it doesn't exist.
        [Parameter(Mandatory)]
        [String] $Path,

        # A description of the share.
        [String] $Description = '',

        # The user/group names who should be granted full access to the share. Only principals in this list will be
        # given full access. All other principals will be removed.
        [String[]] $FullAccess = @(),

        # The user/group names who should be granted change access to the share. Only principals in this list will be
        # given change access. All other principals will be removed.
        [String[]] $ChangeAccess = @(),

        # The user/group names who should be granted read access to the share. Only principals in this list will be
        # given read access. All other principals will be removed.
        #
        # The `Everyone` group will *not* be granted permission by default. They must be in this list to be given
        # access.
        [String[]] $ReadAccess = @()
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    if ([wildcardpattern]::ContainsWildcardCharacters($Name))
    {
        $msg = "Failed to create SMB file share ""${Name}"" because the share name contains wildcard characters."
        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
        return
    }

    $shareInfoWrittenTo = @{}

    function Write-Message
    {
        param(
            [String] $Message,
            [switch] $Verbose
        )

        $writeCmd = 'Write-Information'
        if ($Verbose)
        {
            $writeCmd = 'Write-Verbose'
        }

        if (-not $shareInfoWrittenTo.ContainsKey($writeCmd))
        {
            & $writeCmd "SMB File Share ${Name}"
            $shareInfoWrittenTo[$writeCmd] = $true
        }

        & $writeCmd "               ${Message}"
    }

    function Format-AccessRight
    {
        param(
            [Parameter(Mandatory, ValueFromPipeline)]
            [ValidateSet('Full', 'Change', 'Read')]
            [String] $InputObject
        )

        process
        {
            return '{0,-6}' -f $InputObject
        }
    }

    # Make sure path ends with \. You can only share directories, after all.
    $Path = Join-Path -Path $Path -ChildPath '\'

    if (-not (Test-Path -Path $Path))
    {
        Install-CDirectory -Path $Path
    }

    $share = Test-CSmbShare -Name $Name -PassThru

    # Only way to update a share's path is to delete and re-create the share.
    if ($share -and (Join-Path -Path $share.Path -ChildPath '\') -ne $Path)
    {
        Uninstall-CSmbShare -Name $Name
        $share = $null
    }

    $whatIfTarget = "SMB file share '${Name}'"

    # If no permissions were specified, grant read access to everyone.
    if (-not $share)
    {
        if (-not $PSCmdlet.ShouldProcess($whatIfTarget, "create"))
        {
            return
        }

        Write-Message "created at ""${Path}""."
        foreach ($principal in $FullAccess)
        {
            Write-Message "+ $('Full' | Format-AccessRight)  ${principal}"
        }

        foreach ($principal in $ChangeAccess)
        {
            Write-Message "+ $('Change' | Format-AccessRight)  ${principal}"
        }

        foreach ($principal in $ReadAccess)
        {
            Write-Message "+ $('Read' | Format-AccessRight)  ${principal}"
        }

        $newSmbShareArgs = @{}
        if ($FullAccess)
        {
            $newSmbShareArgs['FullAccess'] = $FullAccess
        }
        if ($ChangeAccess)
        {
            $newSmbShareArgs['ChangeAccess'] = $ChangeAccess
        }
        if ($ReadAccess)
        {
            $newSmbShareArgs['ReadAccess'] = $ReadAccess
        }

        $share = New-SmbShare -Name $Name -Path $Path -Description $Description @newSmbShareArgs
        if (-not $share)
        {
            return
        }
    }

    $Name = $share.Name

    if ($share.Description -ne $Description)
    {
        Write-Message  "Description  - $($share.Description)"
        Write-Message  "             + ${Description}"
        if ($PSCmdlet.ShouldProcess($whatIfTarget, "update description"))
        {
            Set-SmbShare -Name $Name -Description $Description -Force | Out-Null
        }
    }

    # Resolve all the principals.
    $FullAccess = $FullAccess | ForEach-Object { Resolve-CPrincipalName -Name $_ }
    $ChangeAccess = $ChangeAccess | ForEach-Object { Resolve-CPrincipalName -Name $_ }
    $ReadAccess = $ReadAccess | ForEach-Object { Resolve-CPrincipalName -Name $_ }

    $aces = Get-SmbShareAccess -Name $Name | Where-Object 'AccessControlType' -eq 'Allow'

    # Remove extra permissions.
    foreach ($ace in $aces)
    {
        $acePrincipalName = Resolve-CPrincipalName -Name $ace.AccountName
        $ace | Add-Member -MemberType NoteProperty -Name 'PrincipalName' -Value $acePrincipalName -Force
        if (-not $acePrincipalName)
        {
            $acePrincipalName = $ace.AccountName
        }

        if (-not $acePrincipalName -or `
            ($ace.AccessRight -eq 'Read' -and $ReadAccess -notcontains $acePrincipalName) -or `
            ($ace.AccessRight -eq 'Change' -and $ChangeAccess -notcontains $acePrincipalName) -or `
            ($ace.AccessRight -eq 'Full' -and $FullAccess -notcontains $acePrincipalName))
        {
            if (-not $acePrincipalName)
            {
                $acePrincipalName = $ace.AccountName
            }

            if ($PSCmdlet.ShouldProcess($whatIfTarget, "revoke '$($ace.AccountName)' $($ace.AccessRight) access"))
            {
                Write-Message  "- $($ace.AccessRight | Format-AccessRight)  ${acePrincipalName}"
                Revoke-SmbShareAccess -Name $Name -AccountName $ace.AccountName -Force | Out-Null
            }
        }
    }

    function Grant-Access
    {
        param(
            [String[]] $PrincipalName,

            [ValidateSet('Full', 'Change', 'Read')]
            [String] $AccessRight
        )

        foreach ($_principalName in $PrincipalName)
        {
            if ($aces | Where-Object 'PrincipalName' -EQ $_principalName | Where-Object 'AccessRight' -EQ $AccessRight)
            {
                Write-Message "${_principalName}    ${AccessRight}" -Verbose
                continue
            }

            if ($PSCmdlet.ShouldProcess($whatIfTarget, "grant '$($_principalName)' ${AccessRight} access"))
            {
                Write-Message  "+ $($AccessRight | Format-AccessRight)  ${_principalName}"
                Grant-SmbShareAccess -Name $Name -AccountName $_principalName -AccessRight $AccessRight -Force | Out-Null
            }
        }
    }

    Grant-Access -PrincipalName $FullAccess -AccessRight 'Full'
    Grant-Access -PrincipalName $ChangeAccess -AccessRight 'Change'
    Grant-Access -PrincipalName $ReadAccess -AccessRight 'Read'
}
