
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.SmbShare' -Resolve) -Verbose:$false

    $script:shareName = $null
    $script:sharePath = $null
    $script:shareDescription = 'Share for testing Carbon''s Uninstall-CSmbShare function.'
}

Describe 'Uninstall-CSmbShare' {

    BeforeEach {

        $script:sharePath = Get-Item -Path 'TestDrive:'
        $script:shareName = 'CarbonUninstallSmbShare{0}' -f [IO.Path]::GetRandomFileName()
        Install-CSmbShare -Path $script:sharePath -Name $script:shareName -Description $script:shareDescription
        Test-CSmbShare -Name $script:shareName | Should -BeTrue
        $Global:Error.Clear()
    }

    AfterEach {
        Get-SmbShare -Name $script:shareName -ErrorAction Ignore | Uninstall-CSmbShare
    }

    It 'should delete share' {
        $output = Uninstall-CSmbShare -Name $script:shareName
        $output | Should -BeNullOrEmpty
        $Global:Error | Should -BeNullOrEmpty
        (Test-CSmbShare -Name $script:shareName) | Should -BeFalse
        $script:sharePath | Should -Exist
    }

    It 'should support should process' {
        $output = Uninstall-CSmbShare -Name $script:shareName -WhatIf
        $output | Should -BeNullOrEmpty
        (Test-CSmbShare -Name $script:shareName) | Should -BeTrue
    }

    It 'should handle share that does not exist' {
        $output = Uninstall-CSmbShare -Name 'fdsfdsurwoim'
        $output | Should -BeNullOrEmpty
        $Global:Error | Should -BeNullOrEmpty
    }

    It 'should uninstall file share if share directory does not exist' {
        Remove-Item -Path $script:sharePath
        try
        {
            Uninstall-CSmbShare -Name $script:shareName
            $Global:Error | Should -BeNullOrEmpty
            $script:sharePath | Should -Not -Exist
        }
        finally
        {
            New-Item -Path $script:sharePath -ItemType 'Directory'
        }
    }

}