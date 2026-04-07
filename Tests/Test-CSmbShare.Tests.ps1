
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

BeforeAll {
    Set-StrictMode -Version 'Latest'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.SmbShare' -Resolve) -Verbose:$false
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Carbon.SmbShare\M\Carbon.FileSystem' -Resolve) `
                  -Function @('New-CTempDirectory', 'Uninstall-CDirectory') `
                  -PRefix 'T' `
                  -Verbose:$false

    $script:shareName = 'CarbonTestSmbShare'
    $script:sharePath = $null
    $script:shareDescription = 'Share for testing Carbon''s Test-CSmbShare function.'

    $script:sharePath = New-TCTempDirectory -Prefix $PSCommandPath
    Install-CSmbShare -Path $script:sharePath -Name $script:shareName -Description $script:shareDescription
}

AfterAll {
    Uninstall-CSmbShare -Name $script:shareName
    Uninstall-TCDirectory -Path $script:sharePath
}

Describe 'Test-CSmbShare' {
    BeforeEach {
        $Global:Error.Clear()
    }

    It 'should test share' {
        $shares = Get-SmbShare
        $shares | Should -Not -BeNullOrEmpty
        $sharesNotFound = $shares | Where-Object { -not (Test-CSmbShare -Name $_.Name) }
        $sharesNotFound | Should -BeNullOrEmpty
        $Global:Error | Should -BeNullOrEmpty
    }

    It 'should detect shares that do not exist' {
        (Test-CSmbShare -Name 'fdjfkdsfjdsf') | Should -BeFalse
        $Global:Error | Should -BeNullOrEmpty
    }
}
