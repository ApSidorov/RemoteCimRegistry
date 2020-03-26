# This is a Pester test file

##### New Functions #### (the most complex and crucial functions)

Describe 'New functions' {

#region Mock

     ## Normal key
        # Parent key
        $NormalParentKeyName = 'SOFTWARE\Ankh-Morpork'
        $NormalParentKeyPath = 'HKEY_LOCAL_MACHINE\' + $NormalParentKeyName
        Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } { $PSBoundParameters.Key -eq $NormalParentKeyName }

        # New subkey
        $NormalNewKeyName = 'SOFTWARE\Ankh-Morpork\Opera'
        $NormalNewKeyPath = 'HKEY_LOCAL_MACHINE\' + $NormalNewKeyName
        Mock New-cdxmlRegistryKey         { [PSCustomObject]@{ReturnValue = 0} }                   { $PSBoundParameters.Key -eq $NormalNewKeyName }
        Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } { $PSBoundParameters.Key -eq $NormalNewKeyName }

        # Existing subkey
        $ExistingKeyName = 'SOFTWARE\Ankh-Morpork\PseudopolisYard'
        $ExistingKeyPath = 'HKEY_LOCAL_MACHINE\' + $ExistingKeyName
        $ESubkeys = @('Floor1','Floor2','Floor3')
        $Evalues  = @('Commander','Captain','Sergeant','Corporal','Lance-Corporal','Constable','ActingConstable','Lance-Constable')
        $ETypes   = @(1,1,1,1,1,1,1,1)
        Mock New-cdxmlRegistryKey         { [PSCustomObject]@{ReturnValue = 0} }                   { $PSBoundParameters.Key -eq $ExistingKeyName }
        Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } { $PSBoundParameters.Key -eq $ExistingKeyName }
        Mock Get-cdxmlSubkeyName          { [PSCustomObject]@{ReturnValue = 2; sNames = $ESubkeys} }   { $PSBoundParameters.Key -eq $ExistingKeyName }
        Mock Get-cdxmlValueName           { [PSCustomObject]@{ReturnValue = 2; sNames = $Evalues; Types =  $ETypes} } { $PSBoundParameters.Key -eq $ExistingKeyName }



        ## Values
         # New value
         $NewValueName = 'Location'
         Mock Get-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 0; sValue = 'DiscWorld'} } { ($PSBoundParameters.Key -eq $NormalParentKeyName) -and ($PSBoundParameters.ValueName -eq $NewValueName) }
         Mock Set-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 0} }                       { ($PSBoundParameters.Key -eq $NormalParentKeyName) -and ($PSBoundParameters.ValueName -eq $NewValueName) }


         # Existing value same type
         $ValueSameTypeName = 'onRiver'
         Mock Get-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 0; sValue = 'Ankh'} } { ($PSBoundParameters.Key -eq $NormalParentKeyName) -and ($PSBoundParameters.ValueName -eq $ValueSameTypeName) }
         Mock Set-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 0} }                  { ($PSBoundParameters.Key -eq $NormalParentKeyName) -and ($PSBoundParameters.ValueName -eq $ValueSameTypeName) }

         # Existing value other type
         $ValueOtherTypeName = 'Population'
         # Mock Get-cdxmlDWORDValue  { [PSCustomObject]@{ReturnValue = 0; uValue = 1000000} } { ($PSBoundParameters.Key -eq $NormalNewKeyName) -and ($PSBoundParameters.ValueName -eq $ExistingValueName) }
         Mock Get-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 2147749893; sValue = $null} } { ($PSBoundParameters.Key -eq $NormalParentKeyName) -and ($PSBoundParameters.ValueName -eq $ValueOtherTypeName) }
         Mock Set-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 0} }                          { ($PSBoundParameters.Key -eq $NormalParentKeyName) -and ($PSBoundParameters.ValueName -eq $ValueOtherTypeName) }


     ## No access key
        # Parent key
        $MockNAKeyName = 'SOFTWARE\Ankh-Morpork\Shadows'
        $MockNAKeyPath = 'HKEY_LOCAL_MACHINE\' + $MockNAKeyName
        Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 5; bGranted = $false} } { $PSBoundParameters.Key -eq $MockNAKeyName }

        # New key under NoAccess key
        $MockNewNAKeyName = 'SOFTWARE\Ankh-Morpork\Shadows\Parameters'
        $MockNewNAKeyPath = 'HKEY_LOCAL_MACHINE\' + $MockNewNAKeyName
        Mock New-cdxmlRegistryKey         { [PSCustomObject]@{ReturnValue = 5} }                    { $PSBoundParameters.Key -eq $MockNewNAKeyName }
        Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 2; bGranted = $false} } { $PSBoundParameters.Key -eq $MockNewNAKeyName }

    ## Missing parent key
        # Parent key
        $MissingParentKeyName = 'SOFTWARE\Ankh-Morpork\Unseen-U'
        $MissingParentKeyPath = 'HKEY_LOCAL_MACHINE\' + $MissingParentKeyName
        Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 2; bGranted = $false} } { $PSBoundParameters.Key -eq $MissingParentKeyName }
        Mock New-cdxmlRegistryKey         { [PSCustomObject]@{ReturnValue = 0} }                    { $PSBoundParameters.Key -eq $MissingParentKeyName }

        # New key under missing key (created with Force parameter)
        $MissParentSubKeyName = 'SOFTWARE\Ankh-Morpork\Unseen-U\Library'
        $MissParentSubKeyPath = 'HKEY_LOCAL_MACHINE\' + $MissParentSubKeyName
        Mock New-cdxmlRegistryKey         { [PSCustomObject]@{ReturnValue = 0} } { $PSBoundParameters.Key -eq $MissParentSubKeyName }

        # Value under missing key
        $MissingSubKeyValue = 'TowerHeight'
        Mock Set-cdxmlDWORDValue { [PSCustomObject]@{ReturnValue = 0} }  { ($PSBoundParameters.Key -eq $MissingParentKeyName) -and ($PSBoundParameters.ValueName -eq $MissingSubKeyValue) }

#endregion

    Context 'New-RegistryKey' {
        $NewKeyResult = New-RegistryKey -Path $NormalNewKeyPath
        It 'Return the key object if it was created ' {
            $NewKeyResult.Path | Should -Be $NormalNewKeyPath
        }

        It 'Returns new key object with no subkeys/values' {
            $NewKeyResult.SubKeyCount | Should -BeNullOrEmpty
            $NewKeyResult.ValueCount | Should -BeNullOrEmpty
        }

        It 'Returns existing key object with proper numbers of subkeys/values' {
            $ExistingResult = New-RegistryKey -Path $ExistingKeyPath
            $ExistingResult.SubKeyCount | Should -Be 3
            $ExistingResult.ValueCount | Should -Be 8
        }

        It 'Throws if it has no permissions on the parent key' {
            { New-RegistryKey -Path $MockNewNAKeyPath -ErrorAction Stop } | Should -Throw 'Access is denied'
        }

        It 'Throws if the parent key does not exist' {
            { New-RegistryKey -Path $MissParentSubKeyPath -ErrorAction Stop} | Should -Throw 'Registry key does not exist'
        }

        It 'Creates a key under missing parent key with Force parameter.' {
            $NewEnforcedKeyResult = New-RegistryKey -Path $MissParentSubKeyPath -Force
            $NewEnforcedKeyResult.Path | Should -Be $MissParentSubKeyPath
        }



        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName New-RegistryKey -WrongPathReturn NA -CheckOutput
        }
    }

    Context 'Set-RegistryValue' {

        $PSDefaultParameterValues=@{"Set-RegistryValue:Confirm"=$False}

        Context 'Output data' {

            $NewKeyResult = Set-RegistryValue -Path $NormalParentKeyPath -ValueName 'Location' -ValueType REG_SZ -Data 'DiscWorld'

            It 'Return one object for one value' {
                @($NewKeyResult).Count | Should -Be 1
            }

            It 'Return an object of a proper type' {
                ($NewKeyResult.GetType()).Fullname | Should -Be CIMRegistryValue
            }

            It 'Return proper Value name' {
                $NewKeyResult.ValueName | Should -Be 'Location'
            }

            It 'Return proper registry type' {
                $NewKeyResult.ValueType | Should -Be 'REG_SZ'
            }

            It 'Return proper data' {
                $NewKeyResult.Data | Should -Be 'DiscWorld'
            }

            It 'ErrorCode must be zero' {
                $NewKeyResult.ErrorCode | Should -Be 0
            }

            It 'Calls proper cdxml functions for single String value' {
                 Assert-MockCalled Test-cdxmlRegistryKeyAccess -Times 1 -Exactly
                 Assert-MockCalled Get-cdxmlStringValue -Times 1 -Exactly
                 Assert-MockCalled Set-cdxmlStringValue -Times 1 -Exactly
            }

        }

        It 'Works if the existing value has the same type' {
            { Set-RegistryValue -Path $NormalParentKeyPath -ValueName $ValueSameTypeName -ValueType REG_SZ -Data 'BigRiver' -ErrorAction Stop} | Should -Not -Throw
        }


        It 'Throws if the value exits and has other data type' {
            { Set-RegistryValue -Path $NormalParentKeyPath -ValueName $ValueOtherTypeName -ValueType REG_SZ -Data 'Unknown' -ErrorAction Stop} | Should -Throw 'Type mismatch'
             Assert-MockCalled Test-cdxmlRegistryKeyAccess -Times 1 -Exactly -Scope it
             Assert-MockCalled Get-cdxmlStringValue -Times 1 -Exactly -Scope it
             Assert-MockCalled Set-cdxmlStringValue -Times 0 -Exactly -Scope it
        }

        It 'Ignors Type msimatch if Force used' {
            { Set-RegistryValue -Path $NormalParentKeyPath -ValueName $ValueOtherTypeName -ValueType REG_SZ -Data 'Unknown' -Force -ErrorAction Stop} | Should -Not -Throw
            Assert-MockCalled Set-cdxmlStringValue -Times 1 -Exactly -Scope it
        }

        It 'Throws if the key does not exist' {
            { Set-RegistryValue -Path $MissingParentKeyPath  -ValueName 'Location' -ValueType REG_SZ -Data 'DiscWorld' -ErrorAction Stop} | Should -Throw 'Registry key does not exist'
        }

        It 'Creates missing key and value in it if Force used' {
            $ValUnderNewKey = Set-RegistryValue -Path $MissingParentKeyPath  -ValueName $MissingSubKeyValue -ValueType REG_DWORD -Data 800 -ErrorAction Stop -Force
            Assert-MockCalled New-cdxmlRegistryKey -Times 1 -Exactly -Scope it
            $ValUnderNewKey.Path | Should -Be $MissingParentKeyPath

        }

        It 'Throws if it has no permissions on the key' {
            { Set-RegistryValue -Path $MockNAKeyPath -ValueName 'Location' -ValueType REG_SZ -Data 'DiscWorld' -ErrorAction Stop} | Should -Throw 'Access is denied'
        }


        Context 'Calls poper cdxml functions for each registry type' {
            $GetValueFunction = 'Get-cdxmlStringValue','Get-cdxmlExpandedStringValue','Get-cdxmlBinaryValue','Get-cdxmlDWORDValue','Get-cdxmlMultiStringValue','Get-cdxmlQWORDValue'
            $SetValueFunction = 'Set-cdxmlStringValue','Set-cdxmlExpandedStringValue','Set-cdxmlBinaryValue','Set-cdxmlDWORDValue','Set-cdxmlMultiStringValue','Set-cdxmlQWORDValue'
            $GetValueFunction | ForEach-Object { Mock $_ { [PSCustomObject]@{ReturnValue = 0; sValue = $null} } }
            $SetValueFunction | ForEach-Object { Mock $_ { [PSCustomObject]@{ReturnValue = 0} } }

            It 'String (REG_SZ)' {
                Set-RegistryValue -Path $NormalParentKeyPath -ValueName StringName -ValueType REG_SZ -Data 'String'
                Assert-MockCalled Set-cdxmlStringValue -Times 1 -Exactly
            }

            It 'Expandable String (REG_EXPAND_SZ)' {
                Set-RegistryValue -Path $NormalParentKeyPath -ValueName ExStringName -ValueType REG_EXPAND_SZ -Data 'ExString'
                Assert-MockCalled Set-cdxmlExpandedStringValue -Times 1 -Exactly
            }

            It 'Binary (REG_BINARY)' {
                Set-RegistryValue -Path $NormalParentKeyPath -ValueName StringName -ValueType REG_BINARY -Data 123
                Assert-MockCalled Set-cdxmlBinaryValue -Times 1 -Exactly
            }

            It 'DWORD (REG_DWORD)' {
                Set-RegistryValue -Path $NormalParentKeyPath -ValueName DwordName -ValueType REG_DWORD -Data 300
                Assert-MockCalled Set-cdxmlDWORDValue -Times 1 -Exactly
            }

            It 'MultiString (REG_MULTI_SZ)' {
                Set-RegistryValue -Path $NormalParentKeyPath -ValueName MultiStringName -ValueType REG_MULTI_SZ -Data 'MutliString'
                Assert-MockCalled Set-cdxmlMultiStringValue -Times 1 -Exactly
            }

            It 'QWORD (REG_QWORD)' {
                Set-RegistryValue -Path $NormalParentKeyPath -ValueName StringName -ValueType REG_QWORD -Data 90000
                Assert-MockCalled Set-cdxmlQWORDValue -Times 1 -Exactly
            }
        }

        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName Set-RegistryValue -WrongPathReturn Error -ExtraParams @{ValueName = 'Tst'; ValueType = 'REG_SZ'; Data = '123'} -CheckOutput
        }
    }

}

