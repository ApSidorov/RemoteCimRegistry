# This is a Pester test file

##### Get Functions #### (the most complex and crucial functions)

Describe 'Get functions' {

#region Mocks (used only by Get Functions test)
    # Pseudo Registry decription:
    <#
     HKLM
     ├───SOFTWARE\TestInc
     │   ├───Reechani
     │   │   └───Aqua
     │   ├───Sentrosi
     │   │   └───Ignis
     │   └───Vasi
     │       └───Aer
     │
     ├───SOFTWARE\Microsoft\EmptyKey
     │
     ├───SOFTWARE\Microsoft\HiddenDefaultValueKey
     |
     └───SOFTWARE\Microsoft\InvalidValueKey


    1) TestInc key has (default) value and six registry values = 7 ($MockKeyName)
    2) Subkeys: Reechani, Sentrosi and Vasi have one value name: 'MagicType', string. Data of the values: Chime1, Chime2, Chime3 accordingly.
    3) Subkeys: Reechani, Sentrosi and Vasi contain one subkey each: Aqua, Ignis, Aer accordingly.
    4) Sub-subkeys: Aqua, Ignis, Aer have one Default value each. Data of the valus: 'Water', 'Fire', 'Air' accordingly.

    5) EmptyKey has no subkeys and values ($MockEmptyKeyName)
    6) HiddenDefaultValueKey ($HiddenValueKeyName) contains only the Default value that is not enumerated by WMI, string: 'Temple of the Winds'
       (it was the only value that was ever created in the key)

    #>

    ## 1) Mock registry key with data.
        # Subkey list

            $MockKeyName = 'SOFTWARE\TestInc'
            $MockKeyPath = 'HKEY_LOCAL_MACHINE\' + $MockKeyName

            $MockSubKeyNameL1 = @('Sentrosi','Vasi','Reechani')
            $MockSubKeyNameL2 = @('Aqua','Ignis','Aer')

            Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ ReturnValue = 0; sNames = @('Sentrosi','Vasi','Reechani')} } { $PSBoundParameters.Key -eq $MockKeyName }
            Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ ReturnValue = 0; sNames = @('Aqua')} }                       { $PSBoundParameters.Key -eq 'SOFTWARE\TestInc\Reechani' }
            Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ ReturnValue = 0; sNames = @('Ignis')} }                      { $PSBoundParameters.Key -eq 'SOFTWARE\TestInc\Sentrosi' }
            Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ ReturnValue = 0; sNames = @('Aer')} }                        { $PSBoundParameters.Key -eq 'SOFTWARE\TestInc\Vasi' }
            Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ ReturnValue = 0; sNames = @()} } {$PSBoundParameters.Key -in @('SOFTWARE\TestInc\Reechani\Aqua',
                'SOFTWARE\TestInc\Sentrosi\Ignis',
                'SOFTWARE\TestInc\Vasi\Aer')
            }

            Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } # { $PSBoundParameters.Key -eq $NormalNewKeyName }

       # Value-Type list
            $MockValueList = [PSCustomObject]@{
                ReturnValue = 0
                sNames = @('','String', 'ExpString', 'Bin', 'Dword', 'MultiString','Qword')
                Types =  @(1,1,2,3,4,7,11)
            }
            Mock Get-cdxmlValueName { $MockValueList } { $PSBoundParameters.Key -eq $MockKeyName }
            Mock Get-cdxmlValueName { [PSCustomObject]@{ReturnValue = 0; sNames = @('MagicType'); Types =  @(1)} } {
                $PSBoundParameters.Key -in @('SOFTWARE\TestInc\Reechani',
                                             'SOFTWARE\TestInc\Sentrosi',
                                             'SOFTWARE\TestInc\Vasi')
            }

            Mock Get-cdxmlValueName { [PSCustomObject]@{ReturnValue = 0; sNames = @(''); Types =  @(1)} } {
                $PSBoundParameters.Key -in @('SOFTWARE\TestInc\Reechani\Aqua',
                                             'SOFTWARE\TestInc\Sentrosi\Ignis',
                                             'SOFTWARE\TestInc\Vasi\Aer')
            }


        # Values
            # Level 1
            $MockBinData = @([Byte]'65',[Byte]'66',[Byte]'67')
            $MockMulStrDt = @('Eins', 'Zwei', 'Drei')
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'DefaultData'}} {($PSBoundParameters.Key -eq $MockKeyName) -and ($PSBoundParameters.ValueName -eq '')}
            Mock Get-cdxmlStringValue         {[PSCustomObject]@{ReturnValue = 0; sValue = 'StringData'}}    {($PSBoundParameters.ValueName -eq 'String')}
            Mock Get-cdxmlExpandedStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'ExpStringData'}} {($PSBoundParameters.ValueName -eq 'ExpString')}
            Mock Get-cdxmlBinaryValue         {[PSCustomObject]@{ReturnValue = 0; uValue = $MockBinData}}    {($PSBoundParameters.ValueName -eq 'Bin')}
            Mock Get-cdxmlDWORDValue          {[PSCustomObject]@{ReturnValue = 0; uValue = [UInt32]123}}     {($PSBoundParameters.ValueName -eq 'Dword')}
            Mock Get-cdxmlMultiStringValue    {[PSCustomObject]@{ReturnValue = 0; sValue = $MockMulStrDt}}   {($PSBoundParameters.ValueName -eq 'MultiString')}
            Mock Get-cdxmlQWORDValue          {[PSCustomObject]@{ReturnValue = 0; uValue = [UInt64]456}}     {($PSBoundParameters.ValueName -eq 'Qword')}

            # Level 2
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'Chime1'}}  {($PSBoundParameters.Key -eq "$MockKeyName\Reechani") -and ($PSBoundParameters.ValueName -eq 'MagicType')}
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'Chime2'}}  {($PSBoundParameters.Key -eq "$MockKeyName\Sentrosi") -and ($PSBoundParameters.ValueName -eq 'MagicType')}
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'Chime3'}}  {($PSBoundParameters.Key -eq "$MockKeyName\Vasi")     -and ($PSBoundParameters.ValueName -eq 'MagicType')}


            # Level 3
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'Water'}}       {($PSBoundParameters.Key -eq "$MockKeyName\Reechani\Aqua")  -and ($PSBoundParameters.ValueName -eq '')}
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'Fire'}}        {($PSBoundParameters.Key -eq "$MockKeyName\Sentrosi\Ignis") -and ($PSBoundParameters.ValueName -eq '')}
            Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 0; sValue = 'Air'}}         {($PSBoundParameters.Key -eq "$MockKeyName\Vasi\Aer")       -and ($PSBoundParameters.ValueName -eq '')}


    ## 2) Mock empty key
         # Subkey list
         $MockEmptyKeyName = 'SOFTWARE\Microsoft\EmptyKey'
         $MockEmptyKeyPath = 'HKEY_LOCAL_MACHINE\' + $MockEmptyKeyName
         Mock Get-cdxmlSubkeyName  {[PSCustomObject]@{ReturnValue = 0; sNames = $null}}                {$PSBoundParameters.Key -eq $MockEmptyKeyName}
         Mock Get-cdxmlValueName   {[PSCustomObject]@{ReturnValue = 0; sNames = $null; Types = $null}} {$PSBoundParameters.Key -eq $MockEmptyKeyName}
         # Value not found
         Mock Get-cdxmlStringValue {[PSCustomObject]@{ReturnValue = 1; sValue = $null}}                {$PSBoundParameters.Key -eq $MockEmptyKeyName}

    ## 3) Mock key with WMI hidden default value.
         $HiddenValueKeyName = 'SOFTWARE\Microsoft\HiddenDefaultValueKey'
         $HiddenValueKeyPath = 'HKEY_LOCAL_MACHINE\' + $HiddenValueKeyName
         Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ReturnValue = 0; sNames = $null}}                 {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # Default value not enumerated
         Mock Get-cdxmlValueName  {[PSCustomObject]@{ReturnValue = 0; sNames = $null; Types = $null}}  {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # But it can be read directly
         Mock Get-cdxmlStringValue         {[PSCustomObject]@{ReturnValue = 0; sValue = 'Temple of the Winds'}}  {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # Mock Get-cdxmlExpandedStringValue {[PSCustomObject]@{ReturnValue = 2147749893; sValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # Mock Get-cdxmlBinaryValue         {[PSCustomObject]@{ReturnValue = 2147749893; uValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # Mock Get-cdxmlDWORDValue          {[PSCustomObject]@{ReturnValue = 2147749893; uValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # Mock Get-cdxmlMultiStringValue    {[PSCustomObject]@{ReturnValue = 2147749893; sValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
         # Mock Get-cdxmlQWORDValue          {[PSCustomObject]@{ReturnValue = 2147749893; uValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}

    ## 4) Mock key with an invalid value
         $InvalidValueKeyName = 'SOFTWARE\Microsoft\InvalidValueKey'
         $InvalidValueKeyPath = 'HKEY_LOCAL_MACHINE\' + $InvalidValueKeyName
         Mock Get-cdxmlValueName  {[PSCustomObject]@{ReturnValue = 0; sNames = @('BinData'); Types = @(4)}}  {$PSBoundParameters.Key -eq $InvalidValueKeyName}
         Mock Get-cdxmlDWORDValue {[PSCustomObject]@{ReturnValue = 1; uValue = $null}}  {$PSBoundParameters.Key -eq $InvalidValueKeyName}

#endregion
    #
    Context 'Get-RegistryKey' {

        $NormalKeyResult = Get-RegistryKey -Path $MockKeyPath

        It 'Calls Test-cdxmlRegistryKeyAccess function once' {
            Assert-MockCalled Test-cdxmlRegistryKeyAccess -Times 1 -Exactly
        }

        It 'Calls Get-cdxmlSubkeyName cdxml function once' {
            Assert-MockCalled Get-cdxmlSubkeyName -Times 1 -Exactly
        }

        It 'Calls Get-cdxmlValueName cdxml function once' {
            Assert-MockCalled Get-cdxmlValueName -Times 1 -Exactly
        }

        It 'Returns objects of custom CIMRegistryKey type' {
            $NormalKeyResult.GetType().Fullname | Should -Be 'CIMRegistryKey'
        }

        It 'Path is correct' {
           $NormalKeyResult.Path | Should -Be $MockKeyPath
        }

        It 'Returns proper subkeys counter' {
            $NormalKeyResult.SubKeyCount | Should -Be 3
        }

        It 'Returns proper values counter' {
            $NormalKeyResult.ValueCount | Should -Be 7
        }

        It 'Returns no Default value by default' {
            $NormalKeyResult.DefaultValue | Should -BeNullOrEmpty
        }

        It 'Returns Default value on demand' {
            $DefaultValueResult = Get-RegistryKey -Path $MockKeyPath -GetDefaultValue
            $DefaultValueResult.DefaultValue | Should -Be 'DefaultData'
        }

        It 'Returns no Default value if it is hidden' {
            $HiddenValueResult = Get-RegistryKey -Path $HiddenValueKeyPath -GetDefaultValue
            $HiddenValueResult.DefaultValue | Should -BeNullOrEmpty
        }

        It 'Returns hidden Default value if enforced' {
            $HiddenValueResult = Get-RegistryKey -Path $HiddenValueKeyPath -GetDefaultValue -Force
            $HiddenValueResult.DefaultValue | Should -Be 'Temple of the Winds'
        }

        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName Get-RegistryKey -WrongPathReturn Null -CheckOutput
        }

    } #  Context Get-RegistryKey

    Context 'Get-RegistrySubkey' {

        Context 'Normal registry key' {
            $NormalKeyResult = Get-RegistrySubkey -Path $MockKeyPath

            It 'Calls Get-cdxmlSubkeyName cdxml function once' {
                Assert-MockCalled Get-cdxmlSubkeyName -Times 1 -Exactly
            }

            It 'Returns objects of custom CIMRegistryKey type' {
                $NormalKeyResult[0].GetType().Fullname | Should -Be 'CIMRegistryKey'
            }

            It 'Returns proper number of subkeys' {
                $NormalKeyResult.Count | Should -Be 3
            }

            It 'SubKey names are correct' {
                $_tmpSubKeysNames = $MockSubKeyNameL1 | Sort-Object
                foreach ($i in (0..($NormalKeyResult.Count - 1))) {
                    ($NormalKeyResult.Key)[$i] | Should -Be $_tmpSubKeysNames[$i]
                }
            }

            It 'ParentKey is correct' {
                $NormalKeyResult  | ForEach-Object {
                    $_.ParentKey | Should -Be $MockKeyPath
                }
            }

            It 'Path is correct' {
               $NormalKeyResult  | foreach {
                    $_.Path | Should -Be ($_.ParentKey + '\' +  $_.Key)
                }
            }
        }

        Context 'Empty registry key' {
            $EmptyKeyResult = Get-RegistrySubkey -Path $MockEmptyKeyPath

            It 'Calls Get-cdxmlSubkeyName cdxml function once' {
                Assert-MockCalled Get-cdxmlSubkeyName -Times 1 -Exactly
            }

            It 'Returns nothing if a key has no subkeys' {
                $EmptyKeyResult | Should -Be $null
            }
        }

        Context 'Fitering' {
            It 'Filtering with wildcards' {
                (Get-RegistrySubkey -Path $MockKeyPath -SubkeyName '*si').Count | Should -Be 2
            }

            It 'Filtering with specific single name' {
                (Get-RegistrySubkey -Path $MockKeyPath -SubkeyName Vasi).Count | Should -Be 1
            }

        }

        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName Get-RegistrySubkey -WrongPathReturn Error -CheckOutput
        }

    } # Context 'Get-RegistrySubkey'

    Context 'Get-RegistryValue' {

        Context 'Normal registry key' {
            $NormalKeyResult = Get-RegistryValue -Path $MockKeyPath

            It 'Calls Get-Get-cdxmlValueName cdxml function once' {
                Assert-MockCalled Get-cdxmlValueName -Times 1 -Exactly
            }

             It 'Calls Get-cdxmlStringValue cdxml function twice' {
                Assert-MockCalled Get-cdxmlStringValue -Times 2 -Exactly
            }

              It 'Calls Get-Get-cdxmlExpandedStringValue cdxml function once' {
                Assert-MockCalled Get-cdxmlExpandedStringValue -Times 1 -Exactly
            }

             It 'Calls Get-cdxmlBinaryValue cdxml function once' {
                Assert-MockCalled Get-cdxmlBinaryValue -Times 1 -Exactly
            }

             It 'Calls Get-cdxmlDWORDValue cdxml function once' {
                Assert-MockCalled Get-cdxmlDWORDValue -Times 1 -Exactly
            }

             It 'Calls Get-cdxmlMultiStringValue cdxml function once' {
                Assert-MockCalled Get-cdxmlMultiStringValue -Times 1 -Exactly
            }

             It 'Calls Get-cdxmlQWORDValue cdxml function once' {
                Assert-MockCalled Get-cdxmlQWORDValue -Times 1 -Exactly
            }

            It 'Returns objects of custom CIMRegistryKey type' {
                $NormalKeyResult[0].GetType().Fullname | Should Be 'CIMRegistryValue'
                # $NormalKeyResult[0] | Should BeOfType CIMRegistryValue
            }

            It 'Returns proper number of objects with Parameter Input' {
                $NormalKeyResult.Count | Should Be $MockValueList.sNames.Count
            }

            It 'Path is correct' {
                $NormalKeyResult  | % {
                    $_.Path | Should Be $MockKeyPath
                }
            }

            It 'Default value Name is correct' {
               $NormalKeyResult[0].ValueName | Should Be '(default)'
               $NormalKeyResult[0].Data      | Should Be 'DefaultData'
            }

            It 'Value names are correct' {
                $_tmpSubKeysNames = $MockValueList.sNames | Sort
                foreach ($i in (1..($NormalKeyResult.Count - 1))) {
                    ($NormalKeyResult.ValueName)[$i] | Should Be $_tmpSubKeysNames[$i]
                }
            } #  (1..($NormalKeyResult.Count - 1) - excludes (default) value (1..  instead 0..)

            It "Values' Data is correct" {
                ($NormalKeyResult.Where{$_.ValueName -eq '(default)'}).Data   | Should Be 'DefaultData'
                ($NormalKeyResult.Where{$_.ValueName -eq 'String'}).Data      | Should Be 'StringData'
                ($NormalKeyResult.Where{$_.ValueName -eq 'ExpString'}).Data   | Should Be 'ExpStringData'
                ($NormalKeyResult.Where{$_.ValueName -eq 'Bin'}).Data         | Should Be $MockBinData
                ($NormalKeyResult.Where{$_.ValueName -eq 'Dword'}).Data       | Should Be ([UInt32]123)
                ($NormalKeyResult.Where{$_.ValueName -eq 'MultiString'}).Data | Should Be $MockMulStrDt
                ($NormalKeyResult.Where{$_.ValueName -eq 'Qword'}).Data       | Should Be ([UInt64]456)
            } # Really it doesn't check types like [UInt64], just data.
        }

        Context 'Empty registry key' {
            It 'Returns nothing if a key has no values' {
                Get-RegistryValue -Path $MockEmptyKeyPath |  Should Be $null
            }
        }

        Context 'Fitering' {
            It 'Filtering with wildcards' {
                (Get-RegistryValue -Path $MockKeyPath -ValueName *string).Count | Should Be 3
            }

            It 'Filtering with specific single name' {
                (Get-RegistryValue -Path $MockKeyPath -ValueName Dword).Count | Should Be 1
            }

        }

        Context 'ValueName pipeline binding' {

            $CIMclassObject = Get-RegistryValue -Path $MockKeyPath -ComputerName 'SRV12' -ValueName String
            $PSCustomObject = $CIMclassObject | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv

            It 'Accepts ValueName from pipeline InputObject' {
                ($CIMclassObject | Get-RegistryValue).Count | Should -Be 1
                ($CIMclassObject | Get-RegistryValue).ValueName | Should -Be 'String'
            } # -Skip

            It 'Accepts ValueName from pipeline by Parameters Binding' {
                ($PSCustomObject | Get-RegistryValue).Count | Should -Be 1
                ($CIMclassObject | Get-RegistryValue).ValueName | Should -Be 'String'
            } # -Skip

        }

        Context 'Hidden Default value' {

            It 'Returns nothing by default' {
                $DefaultValueResult = Get-RegistryValue -Path $HiddenValueKeyPath
                $NormalKeyResult.Count | Should -Be 0
            }

            It 'Returns hidden Default value if enforced' {
                $HiddenValueResult = Get-RegistryValue -Path $HiddenValueKeyPath -Force
                $HiddenValueResult.Data | Should -Be 'Temple of the Winds'
            }
        }

        Context 'Invalid values' {
            $InvalidValue = Get-RegistryValue -Path $InvalidValueKeyPath -ValueName BinData
            It 'Marks invalid values as invalid' {
                $InvalidValue.InvalidData | Should -Be $true
            } # -Skip

            $GoodValue = Get-RegistryValue -Path $MockKeyPath -ValueName Dword
            It 'Does not mark good values as invalid' {
                $GoodValue.InvalidData | Should -Be $false
            }

        }

        Context "Call common tests" {
            & $PSScriptRoot\99_CIMRegistry_CommonTests.ps1 -FunctionName Get-RegistryValue -WrongPathReturn Error -CheckOutput
        }
    }

} # Describe 'Main functions'