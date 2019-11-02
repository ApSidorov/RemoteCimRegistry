# This is a Pester test file

##### New Functions #### (the most dangerous functions)

Describe 'Remove functions' {

#region Mocks (used only by Get Functions test)
    ## Mock Remove-cdxmlRegistryKey

     ## Normal key
        $NormalDelKeyName = 'SOFTWARE\BorgInc\Probe'
        $NormalDelKeyPath = 'HKEY_LOCAL_MACHINE\' + $NormalDelKeyName
        Mock Test-cdxmlRegistryKeyAccess { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } { $PSBoundParameters.Key -eq $NormalDelKeyName } # Permissions OK
        Mock Remove-cdxmlRegistryKey   { [PSCustomObject]@{ReturnValue = 0} }                     { $PSBoundParameters.Key -eq $NormalDelKeyName }

     ## Nonexistent key + Value
        $NoKeyName = 'SOFTWARE\BorgInc\Cube\MessHall'
        $NoKeyPath = 'HKEY_LOCAL_MACHINE\' + $NoKeyName
        Mock Test-cdxmlRegistryKeyAccess { [PSCustomObject]@{ReturnValue = 2; bGranted = $false} } { $PSBoundParameters.Key -eq $NoKeyName }
        Mock Remove-cdxmlRegistryKey     { [PSCustomObject]@{ReturnValue = 2} }                    { $PSBoundParameters.Key -eq $NoKeyName }
        Mock Remove-cdxmlRegistryValue   { [PSCustomObject]@{ReturnValue = 2} }                    { $PSBoundParameters.Key -eq $NoKeyName }

     ## No delete access key + Value
        $NoDelAccessKeyName = 'SOFTWARE\BorgInc\Cube\Vinculum'
        $NoDelAccessKeyPath = 'HKEY_LOCAL_MACHINE\' + $NoDelAccessKeyName
        Mock Remove-cdxmlRegistryKey     { [PSCustomObject]@{ReturnValue = 5} }                    { $PSBoundParameters.Key -eq $NoDelAccessKeyName } # Assess denied
        Mock Test-cdxmlRegistryKeyAccess { [PSCustomObject]@{ReturnValue = 5; bGranted = $false} } { $PSBoundParameters.Key -eq $NoDelAccessKeyName } # No Permissions
        Mock Get-cdxmlSubkeyName         { [PSCustomObject]@{ReturnValue = 0; sNames = @()} }      { $PSBoundParameters.Key -eq $NoDelAccessKeyName } # No subkeys
        Mock Remove-cdxmlRegistryValue   { [PSCustomObject]@{ReturnValue = 5} }                    { $PSBoundParameters.Key -eq $NoDelAccessKeyName }

     ## Key with a subkey + Values
        $SubKeyExistName = 'SOFTWARE\BorgInc\Cube'
        $SubKeyExistPath = 'HKEY_LOCAL_MACHINE\' + $SubKeyExistName
        $SubKeyExistList = @('CentralPlexus','Vinculum')
        Mock Remove-cdxmlRegistryKey     { [PSCustomObject]@{ReturnValue = 5} }                             { $PSBoundParameters.Key -eq $SubKeyExistName } # Assess denied
        Mock Test-cdxmlRegistryKeyAccess { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} }           { $PSBoundParameters.Key -eq $SubKeyExistName } # Permissions OK
        Mock Get-cdxmlSubkeyName         { [PSCustomObject]@{ReturnValue = 0; sNames = $SubKeyExistList} }  { $PSBoundParameters.Key -eq $SubKeyExistName } # There is subkeys

        ## Values
        $ExistingValue    = 'DistributionNode'
        $NonExistingValue = 'VendingMachine'
        Mock Remove-cdxmlRegistryValue { [PSCustomObject]@{ReturnValue = 0} } { ($PSBoundParameters.Key -eq $SubKeyExistName) -and ($PSBoundParameters.ValueName -eq $ExistingValue) }
        Mock Remove-cdxmlRegistryValue { [PSCustomObject]@{ReturnValue = 2} } { ($PSBoundParameters.Key -eq $SubKeyExistName) -and ($PSBoundParameters.ValueName -eq $NonExistingValue) }


     ##
#endregion

    Context 'Remove-RegistryKey' {

        $PSDefaultParameterValues=@{"Remove-RegistryKey:Confirm"=$False}

        It 'Return nothing if a key was deleted' {
            Remove-RegistryKey -Path $NormalDelKeyPath | Should -BeNullOrEmpty
        }

        It 'Throws if a key does not exist' {
            { Remove-RegistryKey -Path $NoKeyPath -ErrorAction Stop } | Should -Throw $PathNotFoundError # 'Registry key does not exist' # 'Access is denied'
        }

        It 'Throws if user has no permission' {
            { Remove-RegistryKey -Path $NoDelAccessKeyPath -ErrorAction Stop } | Should -Throw 'Access is denied'
        }

        It 'Throws if key has subkeys' {
            { Remove-RegistryKey -Path $SubKeyExistPath -ErrorAction Stop } | Should -Throw 'Registry key cannot be deleted'
        }

        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName Remove-RegistryKey -WrongPathReturn Error
        }

    }

    Context 'Remove-RegistryValue' {

        $PSDefaultParameterValues=@{"Remove-RegistryValue:Confirm"=$False}

        It 'Return nothing if a value was deleted' {
            Remove-RegistryValue -Path $SubKeyExistPath -ValueName $ExistingValue | Should -BeNullOrEmpty
        } # -Skip

        It 'Throws if a value does not exist' {
            { Remove-RegistryValue -Path $SubKeyExistPath -ValueName $NonExistingValue -ErrorAction Stop } | Should -Throw $ValueNotFoundError
        } # -Skip

        It 'Throws if a key does not exist' {
            { Remove-RegistryValue -Path $NoKeyPath -ValueName $ExistingValue -ErrorAction Stop } | Should -Throw $PathNotFoundError
        } # -Skip

        It 'Throws if user has no permission' {
            { Remove-RegistryValue -Path $NoDelAccessKeyPath -ValueName $ExistingValue -ErrorAction Stop } | Should -Throw $AccessDeniedError
        } # -Skip


        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName Remove-RegistryValue -WrongPathReturn Error -ExtraParams @{ValueName = 'Tst'}
        }

    }

}


