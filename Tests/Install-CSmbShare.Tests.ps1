
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.SmbShare' -Resolve) -Verbose:$false

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PSModules\Carbon' -Resolve) `
                  -Function @('Install-CGroup') `
                  -Prefix 'T' `
                  -Verbose:$false
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.SmbShare\M\Carbon.Accounts' -Resolve) `
                  -Function @('Resolve-CPrincipalName') `
                  -Prefix 'T' `
                  -Verbose:$false
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.SmbShare\M\Carbon.FileSystem' -Resolve) `
                  -Function @('New-CTempDirectory') `
                  -Prefix 'T' `
                  -Verbose:$false

    $script:baseShareName = $PSCommandPath | Split-Path -Leaf
    $script:ShareName = $null
    $script:SharePath = $PSScriptRoot
    $script:fullAccessGroup = 'Carbon Share Full'
    $script:changeAccessGroup = 'CarbonShareChange'
    $script:readAccessGroup = 'CarbonShareRead'
    $script:noAccessGroup = 'CarbonShareNone'
    $script:Remarks = [Guid]::NewGuid().ToString()
    $script:testNum = 0

    Install-TCGroup -Name $script:fullAccessGroup -Description 'Carbon group for testing full share permissions.'
    Install-TCGroup -Name $script:changeAccessGroup -Description 'Carbon group for testing change share permissions.'
    Install-TCGroup -Name $script:readAccessGroup -Description 'Carbon group for testing read share permissions.'

    function Assert-ShareCreated
    {
        $share = Get-Share
        $share | Should -Not -BeNullOrEmpty
    }

    function Assert-Share
    {
        param(
            $Name = $script:ShareName,
            $Path = $script:SharePath,
            $Description = '',
            $FullAccess,
            $ChangeAccess,
            $ReadAccess
        )

        (Test-CSmbShare -Name $Name) | Should -BeTrue

        $share = Get-SmbShare -Name $Name
        $share | Should -Not -BeNullOrEmpty

        $share.Description | Should -Be $Description
        $share.Path | Should -Be $Path

        function Assert-ShareRight
        {
            param(
                [String[]] $PrincipalName,

                [ValidateSet('Full', 'Change', 'Read')]
                [String] $ExpectedRights
            )

            if ($PrincipalName)
            {
                foreach( $_principalName in $PrincipalName )
                {
                    $_principalName = Resolve-TCPrincipalName -Name $_principalName
                    $because = "expected ${_principalName} to have ${ExpectedRights} access, but they did not."
                    Get-SmbShareAccess -Name $Name |
                        Where-Object 'AccountName' -EQ $_principalName |
                        Where-Object 'AccessRight' -EQ $ExpectedRights |
                        Should -Not -BeNullOrEmpty -Because $because
                }
            }
            else
            {
                Get-SmbShareAccess -Name $Name |
                    Where-Object 'AccessControlType' -EQ 'Allow' |
                    Where-Object 'AccessRight' -EQ $ExpectedRights |
                    Should -BeNullOrEmpty
            }

            # Sanity check for the behavior of Revoke-SmbShareAccess. In testing, Everyone gets read access by default.
            # Install-CSmbShare removes that ACL, which Get-SmbShareAccess returns as a deny rule, even though the
            # security descriptor does not have a deny rule for Everyone. Make sure that Revoke-SmbShareAccess actually
            # removes ACEs instead of just changing them to deny. Except for Everyone.
            Get-SmbShareAccess -Name $Name |
                Where-Object 'AccessControlType' -EQ 'Deny' |
                Where-Object 'AccountName' -NE 'Everyone' |
                Should -BeNullOrEmpty
        }

        Assert-ShareRight $FullAccess Full
        Assert-ShareRight $ChangeAccess Change
        Assert-ShareRight $ReadAccess Read
    }

    function Remove-Share
    {
        Get-Share -ErrorAction Ignore | Uninstall-CSmbShare
    }

    function Invoke-NewShare
    {
        param(
            [String] $Path = $PSScriptRoot,
            $FullAccess = @(),
            $ChangeAccess = @(),
            $ReadAccess = @(),
            $Remarks = ''
        )
        Install-CSmbShare -Name $script:ShareName `
                           -Path $Path `
                           -Description $Remarks `
                           -FullAccess $FullAccess `
                           -ChangeAccess $ChangeAccess `
                           -ReadAccess $ReadAccess | Should -BeNullOrEmpty
        Assert-ShareCreated
    }

    function Get-Share
    {
        [CmdletBinding()]
        param(
        )

        Get-SmbShare -Name $script:ShareName -ErrorAction $ErrorActionPreference
    }

}

AfterAll {
    Get-SmbShare -Name "$($script:baseShareName)*" | Uninstall-CSmbShare
}

Describe 'Install-CSmbShare' {
    BeforeEach {
        $script:shareName = "$($script:baseShareName)$($script:testNum)"
        $Global:Error.Clear()
    }

    AfterEach {
        $script:testNum += 1
        Remove-Share
    }

    It 'should create share' {
        Invoke-NewShare
        Assert-Share
    }

    It 'should grant permissions' {
        $script:fullAccessGroup | Should -BeLike '* *'
        Invoke-NewShare -FullAccess $script:fullAccessGroup -ChangeAccess $script:changeAccessGroup -ReadAccess $script:readAccessGroup
        $details = (net share $script:ShareName) -join ([Environment]::NewLine)
        $details | Should -BeLike ("*{0}, FULL*" -f $script:fullAccessGroup)
        $details | Should -BeLike ("*{0}, CHANGE*" -f $script:changeAccessGroup)
        $details | Should -BeLike ("*{0}, READ*" -f $script:readAccessGroup)
        $details | Should -BeLike "*Remark            *"
    }

    It 'does not grant permissions twice' {
        $script:fullAccessGroup | Should -BeLike '* *'
        Invoke-NewShare -FullAccess $script:fullAccessGroup `
                        -ChangeAccess $script:changeAccessGroup `
                        -ReadAccess $script:readAccessGroup
        Mock -CommandName 'Grant-SmbShareAccess' -ModuleName 'Carbon.SmbShare'
        Invoke-NewShare -FullAccess $script:fullAccessGroup -ChangeAccess $script:changeAccessGroup -ReadAccess $script:readAccessGroup
        Should -Not -Invoke 'Grant-SmbShareAccess' -ModuleName 'Carbon.SmbShare'
    }

    It 'should grant multiple full access permissions' {
        Install-CSmbShare -Name $shareName `
                           -Path $PSScriptRoot `
                           -Description $script:Remarks `
                           -FullAccess $script:fullAccessGroup,$script:changeAccessGroup,$script:readAccessGroup |
            Should -BeNullOrEmpty
        $details = (net share $script:ShareName) -join ([Environment]::NewLine)
        $details | Should -BeLike ("*{0}, FULL*" -f $script:fullAccessGroup)
        $details | Should -BeLike ("*{0}, FULL*" -f $script:changeAccessGroup)
        $details | Should -BeLike ("*{0}, FULL*" -f $script:readAccessGroup)
        $details | Should -BeLike "*Remark            *"
    }

    It 'should grant multiple change access permissions' {
        Install-CSmbShare -Name $shareName `
                           -Path $PSScriptRoot `
                           -Description $script:Remarks `
                           -ChangeAccess $script:fullAccessGroup,$script:changeAccessGroup,$script:readAccessGroup |
            Should -BeNullOrEmpty
        $details = (net share $script:ShareName) -join ([Environment]::NewLine)
        $details | Should -BeLike ("*{0}, CHANGE*" -f $script:fullAccessGroup)
        $details | Should -BeLike ("*{0}, CHANGE*" -f $script:changeAccessGroup)
        $details | Should -BeLike ("*{0}, CHANGE*" -f $script:readAccessGroup)
        $details | Should -BeLike "*Remark            *"
    }

    It 'should grant multiple full access permissions' {
        Install-CSmbShare -Name $shareName `
                           -Path $PSScriptRoot `
                           -Description $script:Remarks `
                           -ReadAccess $script:fullAccessGroup,$script:changeAccessGroup,$script:readAccessGroup |
            Should -BeNullOrEmpty
        $details = (net share $script:ShareName) -join ([Environment]::NewLine)
        $details | Should -BeLike ("*{0}, READ*" -f $script:fullAccessGroup)
        $details | Should -BeLike ("*{0}, READ*" -f $script:changeAccessGroup)
        $details | Should -BeLike ("*{0}, READ*" -f $script:readAccessGroup)
        $details | Should -BeLike "*Remark            *"
    }

    It 'should set remarks' {
        $expectedRemarks = 'Hello, workd.'
        Invoke-NewShare -Remarks $expectedRemarks

        $details = Get-Share
        $details.Description | Should -Be $expectedRemarks
    }

    It 'should handle path with trailing slash' {
        Install-CSmbShare $script:ShareName -Path "$PSScriptRoot\" | Should -BeNullOrEmpty

        Assert-ShareCreated
    }

    It 'should create share directory' {
        $tempDir = New-TCTempDirectory -Prefix 'Carbon_Test-InstallSmbShare'
        $shareDir = Join-Path -Path $tempDir -ChildPath 'Grandparent\Parent\Child'
        $shareDir | Should -Not -Exist
        Invoke-NewShare -Path $shareDir
        Assert-ShareCreated
        $shareDir | Should -Exist
    }

    It 'should update path' {
        $tempDir = New-TCTempDirectory -Prefix $PSCommandPath
        try
        {
            Install-CSmbShare -Name $script:ShareName -Path $script:SharePath | Should -BeNullOrEmpty
            Assert-Share

            Install-CSmbShare -Name $script:ShareName -Path $tempDir | Should -BeNullOrEmpty
            Assert-Share -Path $tempDir.FullName
        }
        finally
        {
            Remove-Item -Path $tempDir
        }
    }

    It 'should update description' {
        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -Description 'first' | Should -BeNullOrEmpty
        Assert-Share -Description 'first'

        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -Description 'second' | Should -BeNullOrEmpty
        Assert-Share -Description 'second'
    }

    It 'should add new permissions to existing share' {
        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath | Should -BeNullOrEmpty
        Assert-Share

        Install-CSmbShare -Name $script:ShareName `
                           -Path $script:SharePath `
                           -FullAccess $script:fullAccessGroup `
                           -ChangeAccess $script:changeAccessGroup `
                           -ReadAccess $script:readAccessGroup |
            Should -BeNullOrEmpty
        Assert-Share -FullAccess $script:fullAccessGroup `
                     -ChangeAccess $script:changeAccessGroup `
                     -ReadAccess $script:readAccessGroup
    }

    It 'should remove existing permissions' {
        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -FullAccess $script:fullAccessGroup |
            Should -BeNullOrEmpty
        Assert-Share -FullAccess $script:fullAccessGroup

        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath | Should -BeNullOrEmpty
        Assert-Share
    }

    It 'should update existing permissions' {
        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -FullAccess $script:changeAccessGroup |
            Should -BeNullOrEmpty
        Assert-Share -FullAccess $script:changeAccessGroup

        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -ChangeAccess $script:changeAccessGroup |
            Should -BeNullOrEmpty
        Assert-Share -ChangeAccess $script:changeAccessGroup
    }

    It 'should share drive' {
        $drive = Split-Path -Qualifier -Path $PSScriptRoot
        Install-CSmbShare -Name $script:ShareName -Path $drive | Should -BeNullOrEmpty
        $Global:Error | Should -BeNullOrEmpty
        Assert-ShareCreated
    }

    It 'supports WhatIf when creating share' {
        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -WhatIf | Should -BeNullOrEmpty
        Test-CSmbShare -Name $script:ShareName | Should -BeFalse
    }

    It 'supports WhatIf when updating share' {
        Install-CSmbShare -Name $script:ShareName -Path $script:SharePath -ReadAccess 'Everyone' |
            Should -BeNullOrEmpty
        Test-CSmbShare -Name $script:ShareName | Should -BeTrue

        # Update description
        Install-CSmbShare -Name $script:ShareName `
                           -Path $script:SharePath `
                           -Description 'new description' `
                           -ReadAccess 'Everyone' `
                           -WhatIf |
            Should -BeNullOrEmpty
        $share = Get-SmbShare -Name $script:ShareName
        $share.Description | Should -Not -Be 'new description'

        # Update permissions
        Install-CSmbShare -Name $script:ShareName `
                           -Path $script:SharePath `
                           -FullAccess $script:fullAccessGroup `
                           -ChangeAccess $script:changeAccessGroup `
                           -ReadAccess $script:readAccessGroup `
                           -WhatIf |
            Should -BeNullOrEmpty
        $access = Get-SmbShareAccess -Name $script:ShareName
        $access | Should -HaveCount 1
        $access[0].AccountName | Should -Be 'Everyone'
        $access[0].AccessRight | Should -Be 'Read'
    }
}
