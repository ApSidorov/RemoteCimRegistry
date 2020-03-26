# This is a Pester test file

##### Helping Functions ####

Describe 'Helping Functions' {

    Context 'Split-RegistryPath' {

        $ResultingSplict = Split-RegistryPath -RegistryPath 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\'

        It 'Returns a hashtable' {
            $ResultingSplict.GetType().Name | Should -Be 'Hashtable'
        }

        It 'Returns proper Root Key' {
            $ResultingSplict['RootKey'] | Should -Be 'HKEY_LOCAL_MACHINE'
        }

        It 'Returns proper Key' {
            $ResultingSplict['Key'] | Should -Be 'SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        }

        It 'Throws on invalid RootKey' {
            {Split-RegistryPath -RegistryPath 'NO_SUCH_ROOTKEY\SOFTWARE'} | Should -Throw
        }

        $ValidRootKeys ="HKEY_LOCAL_MACHINE", "HKEY_CURRENT_USER", "HKEY_USERS", "HKEY_CURRENT_CONFIG", "HKEY_CLASSES_ROOT", "HKEY_PERFORMANCE_DATA"

        It "Doesn't throws valid RootKeys" {
            {
                foreach ($RKey in $ValidRootKeys) { Split-RegistryPath -RegistryPath "$RKey\SYSTEM" }
            } | Should -Not -Throw
        }

        $ResultingSplict = Split-RegistryPath -RegistryPath 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ '

        It 'Does not trim closing space character' {
            $ResultingSplict['Key'] | Should -Be 'SOFTWARE\Microsoft\ '
        }

    } # Context Split-RegistryPath

    Context 'Copy-IDictionary' {
        $TestHTable = @{a=1;b=2;c=3;d=4;e=5}

        $Allvalues = Copy-IDictionary -IDictionary $TestHTable

        It 'Returns a hashtable' {
            $Allvalues.GetType().Name | Should -Be 'Hashtable'
        }

        It 'Can copy whole hashtable' {
            $Allvalues.Count | Should -Be 5
        }

        $CopyPart = Copy-IDictionary -IDictionary $TestHTable -Key c,a
        It 'Can COPY a part  hashtable' {
            $CopyPart.Count | Should -Be 2
        }
        It 'Copy proper elements' {
            $CopyPart['a'] | Should -Be 1
            $CopyPart['c'] | Should -Be 3
        }

        $RemovePart = Copy-IDictionary -IDictionary $TestHTable -Key c,a -Remove
        It 'Can REMOVE a part  hashtable' {
            $RemovePart.Count | Should -Be 3
        }

        It 'Remove proper elements' {
            $RemovePart['b'] | Should -Be 2
            $RemovePart['d'] | Should -Be 4
            $RemovePart['e'] | Should -Be 5
        }

        $EmptyHT = Copy-IDictionary -IDictionary $TestHTable -Key 'z'
        It 'Returns empty hashtable if there is nothing to copy' {
            $EmptyHT.GetType().Name | Should -Be 'Hashtable'
            $EmptyHT.Count | Should -Be 0
        }


    } # Context Copy-IDictionary

<#
    Context 'New-ParameterTable' {

        $isSessionTemporary = $false

        Context 'Parameteters have priority #1' {
            $PipeLineObject = [CimRegistryKey]@{
                Path              = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                # ParentKey         = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft'
                # Key               = 'TestInc'
                DefaultValue      = $null
                SubKeyCount      = $null
                ValueCount       = $null
                PSComputerName    = 'CompFromPipe'
                Protocol          = 'Wsman'
                CimSessionId = 'dee0dad7-f24e-4a01-b6ea-49829c924525'
            }

            $Fake_PSBoundParameters = @{
                CimSession  = 'CompFomParams'
                Protocol    = 'DCOM'
                InputObject = $PipeLineObject
            }

            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

            It 'Returns Path from PipeLine' {
                $ResultingParams['Path'] | Should -Be $PipeLineObject.Path
            }

            It 'Returns No Subkey' {
                $ResultingParams['Subkey'] | Should -BeNullOrEmpty
            }

            It 'Returns No Details' {
                $ResultingParams['Details'] | Should -BeNullOrEmpty
            }

            It 'Returns ComputerName from parameters' {
                $ResultingParams['CimSession'].ComputerName | Should -Be 'CompFomParams'
            }

            It 'Returns Protocol from parameters' {
                $ResultingParams['CimSession'].Protocol | Should -Be 'Dcom'
            }


            $Fake_PSBoundParameters.Remove('Protocol')
            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)
            It 'Returns No Protocol if there was no Protocol in parameters' {
                $ResultingParams['Protocol'] | Should -BeNullOrEmpty
            }
        } # Context #1

        Context 'Pre-created [CimSession] has priority #2' {
            $AliveSession = [Microsoft.Management.Infrastructure.CimSession]::Create('CompFomCimSess') | Add-Member -NotePropertyName Protocol -NotePropertyValue 'Wsman' -PassThru
            $GoodSessionGUID = $AliveSession.InstanceId.Guid

            $PipeLineObject = [CimRegistryKey]@{
                Path              = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                # ParentKey         = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft'
                # Key               = 'TestInc'
                DefaultValue      = $null
                SubKeyCount      = $null
                ValueCount       = $null
                PSComputerName    = 'CompFromPipe'
                Protocol          = 'Wsman'
                CimSessionId = $GoodSessionGUID
            }

            # PSBoundParameters can contains only Protocol parameter. But it must be ignored in this case.
            $Fake_PSBoundParameters = @{
                # Path       = 'HKEY_CURRENT_USER\Control Panel' # Just in case
                # Subkey     = 'Desktop'
                # CimSession = 'CompFomParams' # Must not be, or it is case #1
                InputObject = $PipeLineObject
                Protocol    = 'DCOM'
            }


            Mock Get-CimSession { $AliveSession } { ($PSBoundParameters.InstanceId -eq $GoodSessionGUID) }


            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

            It 'Returns Path from PipeLine' {
                $ResultingParams['Path'] | Should -Be $PipeLineObject.Path
            }

            It 'Returns No Subkey' {
                $ResultingParams['Subkey'] | Should -BeNullOrEmpty
            }
            It 'Returns No Details' {
                $ResultingParams['Details'] | Should -BeNullOrEmpty
            }

            It 'Returns No Protocol' {
                $ResultingParams['Protocol'] | Should -BeNullOrEmpty
            }

            It 'Returns pre-created CimSession object' {
                $ResultingParams['CimSession'] | Should -Be $AliveSession
            }


        } # Context '#2

        Context "InputObject's PSComputerName and Protocol have priority #3" {
            $DeadSessinGUID = [Guid]::Empty
            # No Mock for Get-CimSession since the session is not supposed to exist in this case.
            # It's already gone (in case of exported objects).

            $PipeLineObject = [CimRegistryKey]@{
                Path              = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                # ParentKey         = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft'
                # Key               = 'TestInc'
                DefaultValue      = $null
                SubKeyCount      = $null
                ValueCount       = $null
                PSComputerName    = 'CompFromPipe'
                Protocol          = 'Wsman'
                CimSessionId = $DeadSessinGUID
            }

            $Fake_PSBoundParameters = @{
                InputObject = $PipeLineObject
            }

            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

            It 'Returns Path from PipeLine' {
                $ResultingParams['Path'] | Should -Be $PipeLineObject.Path
            }

            It 'Returns No Subkey' {
                $ResultingParams['Subkey'] | Should -BeNullOrEmpty
            }

            It 'Returns No Details' {
                $ResultingParams['Details'] | Should -BeNullOrEmpty
            }

            It 'Returns ComputerName from Pipeline' {
                $ResultingParams['CimSession'].ComputerName | Should -Be $PipeLineObject.PSComputerName
            }

            It 'Returns Protocol from Pipeline' {
                $ResultingParams['CimSession'].Protocol | Should -Be $PipeLineObject.Protocol
            }

         } # Context #3

    } # Context New-ParameterTable
#>

    Context 'New-ParameterTable' {

        Context 'Parameteters have priority #1' {

            $isSessionTemporary = $false

            $PipeLineObject = [CimRegistryKey]@{
                Path              = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                DefaultValue      = $null
                SubKeyCount      = $null
                ValueCount       = $null
                PSComputerName    = 'CompFromPipe'
                Protocol          = 'Wsman'
                CimSessionId = 'dee0dad7-f24e-4a01-b6ea-49829c924525'
            }

            $Fake_PSBoundParameters = @{
                ComputerName  = 'CompFomParams'
                Protocol      = 'DCOM'
                InputObject   = $PipeLineObject
            }

            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

            It 'Returns Path from PipeLine' {
                $ResultingParams['Path'] | Should -Be $PipeLineObject.Path
            }

            It 'Returns ComputerName from parameters' {
                $ResultingParams['CimSession'].ComputerName | Should -Be $Fake_PSBoundParameters['ComputerName']
            }

            It 'Returns Protocol from parameters' {
                $ResultingParams['CimSession'].Protocol | Should -Be $Fake_PSBoundParameters['Protocol']
            }


            It 'Calls New-Cimsession' {
                Assert-MockCalled New-CimSession -Times 1 # -Exactly
            }

            It 'Sets Temporary Session flag to true' {
                $isSessionTemporary | Should -Be $true
            }

            $Fake_PSBoundParameters.Remove('Protocol')
            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)
            It 'Returns Protocol from InputObject if there was no Protocol in parameters' {
                $ResultingParams['CimSession'].Protocol | Should -Be $PipeLineObject.Protocol
            }
        } # Context #1

        Context 'Pre-created [CimSession] has priority #2' {
            $isSessionTemporary = $false
            $AliveSession = [Microsoft.Management.Infrastructure.CimSession]::Create('CompFomCimSess') | Add-Member -NotePropertyName Protocol -NotePropertyValue 'DCOM' -PassThru
            $GoodSessionGUID = $AliveSession.InstanceId.Guid

            $PipeLineObject = [CimRegistryKey]@{
                Path              = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                DefaultValue      = $null
                SubKeyCount      = $null
                ValueCount       = $null
                PSComputerName    = 'CompFromPipe'
                Protocol          = 'Wsman'
                CimSessionId = $GoodSessionGUID
            }

            $Fake_PSBoundParameters = @{
                # CimSession = 'CompFomParams' # Must not be, or it is case #1
                InputObject = $PipeLineObject
            }


            Mock Get-CimSession { $AliveSession } { ($PSBoundParameters.InstanceId -eq $GoodSessionGUID) }


            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

            It 'Returns Path from PipeLine' {
                $ResultingParams['Path'] | Should -Be $PipeLineObject.Path
            }

            It 'Returns pre-created CimSession object' {
                $ResultingParams['CimSession'] | Should -Be $AliveSession
            }

            # Just in case
            It 'Returns ComputerName from parameters' {
                $ResultingParams['CimSession'].ComputerName | Should -Be $AliveSession.ComputerName
            }

            It 'Returns Protocol from parameters' {
                $ResultingParams['CimSession'].Protocol | Should -Be $AliveSession.Protocol
            }

            It 'Does nott call New-Cimsession' {
                Assert-MockCalled New-CimSession -Times 0  -Exactly
            }

            It 'Leave Temporary Session flag to be false' {
                $isSessionTemporary | Should -Be $false
            }


        } # Context '#2

        Context "InputObject's PSComputerName and Protocol have priority #3" {
            $isSessionTemporary = $false
            $DeadSessinGUID = [Guid]::Empty
            # No Mock for Get-CimSession since the session is not supposed to exist in this case.
            # It's already gone (in case of exported objects).

            $PipeLineObject = [CimRegistryKey]@{
                Path              = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                # ParentKey         = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft'
                # Key               = 'TestInc'
                DefaultValue      = $null
                SubKeyCount      = $null
                ValueCount       = $null
                PSComputerName    = 'CompFromPipe'
                Protocol          = 'Wsman'
                CimSessionId = $DeadSessinGUID
            }

            $Fake_PSBoundParameters = @{
                InputObject = $PipeLineObject
            }

            $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

            It 'Returns Path from PipeLine' {
                $ResultingParams['Path'] | Should -Be $PipeLineObject.Path
            }

            It 'Returns ComputerName from Pipeline' {
                $ResultingParams['CimSession'].ComputerName | Should -Be $PipeLineObject.PSComputerName
            }

            It 'Returns Protocol from Pipeline' {
                $ResultingParams['CimSession'].Protocol | Should -Be $PipeLineObject.Protocol
            }

            It 'Calls New-Cimsession' {
                Assert-MockCalled New-CimSession -Times 1 # -Exactly
            }

            It 'Sets Temporary Session flag to true' {
                $isSessionTemporary | Should -Be $true
            }

         } # Context #3

        Context "Localhost handling" {
            $isSessionTemporary = $false

            It 'Returns no Cimsession if ComputerName and CimSession are omitted' {
                $Fake_PSBoundParameters = @{
                    Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                }
                $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByParameters' -TempFlag ([ref]$isSessionTemporary)

                $ResultingParams['CimSession'] | Should -BeNullOrEmpty
                Assert-MockCalled New-CimSession -Times 0  -Exactly -Scope It
            }

            It 'Returns no Cimsession if ComputerName = "localhost"' {
                $Fake_PSBoundParameters = @{
                    Path         = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                    ComputerName = 'localhost'
                }
                $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByParameters' -TempFlag ([ref]$isSessionTemporary)

                $ResultingParams['CimSession'] | Should -BeNullOrEmpty
                Assert-MockCalled New-CimSession -Times 0  -Exactly -Scope It
            }

            It 'Returns no Cimsession if ComputerName = "."' {
                $Fake_PSBoundParameters = @{
                    Path         = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                    ComputerName = '.'
                }
                $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByParameters' -TempFlag ([ref]$isSessionTemporary)

                $ResultingParams['CimSession'] | Should -BeNullOrEmpty
                Assert-MockCalled New-CimSession -Times 0  -Exactly -Scope It
            }

            It 'Returns no Cimsession if InputObject.PSComputerName = "localhost"' {
                $PipeLineObject = [CimRegistryKey]@{
                    Path           = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                    DefaultValue   = $null
                    SubKeyCount    = $null
                    ValueCount     = $null
                    PSComputerName = 'localhost'
                    Protocol       = 'Default'
                    CimSessionId   = ''
                }

                $Fake_PSBoundParameters = @{
                    InputObject   = $PipeLineObject
                }
                $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

                $ResultingParams['CimSession'] | Should -BeNullOrEmpty
                Assert-MockCalled New-CimSession -Times 0  -Exactly -Scope It
            }

            It 'Returns no Cimsession if InputObject.PSComputerName overriden by "localhost" in parameters' {
                $PipeLineObject = [CimRegistryKey]@{
                    Path           = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TestInc'
                    DefaultValue   = $null
                    SubKeyCount    = $null
                    ValueCount     = $null
                    PSComputerName = 'CompFromPipe'
                    Protocol       = 'Default'
                    CimSessionId   = ''
                }

                $Fake_PSBoundParameters = @{
                    ComputerName = 'localhost'
                    InputObject   = $PipeLineObject
                }
                $ResultingParams = New-ParameterTable -BoundParams $Fake_PSBoundParameters -ParameterSetName 'ByInputObject' -TempFlag ([ref]$isSessionTemporary)

                $ResultingParams['CimSession'] | Should -BeNullOrEmpty
                Assert-MockCalled New-CimSession -Times 0  -Exactly -Scope It
            }
        }

    } # Context New-ParameterTable

    Context 'New-CimConnection' {
        # $TestedCommand = Get-Command -Name New-CimConnection
        # ($TestedCommand.Parameters['Protocol'].Attributes).Where{$_ -is [System.Management.Automation.ValidateSetAttribute]}

        Context 'Remote computer using existing CimSession object' {

            $TFlag = $false

            Mock New-CimSession {}
            $NC_Ses_CompName = 'TestComp02'
            $ExCimSess = [Microsoft.Management.Infrastructure.CimSession]::Create($NC_Ses_CompName)
            $ExCimSess | Add-Member -NotePropertyName Protocol -NotePropertyValue 'WSMAN'

            $NC_Ses_CompRes =  New-CimConnection -ComputerName $ExCimSess -NewSessionFlag ([ref]$TFlag)

            It 'Does not call New-CimSession' {
                Assert-MockCalled New-CimSession -Times 0 -Exactly
            }

            It 'Function returns CimSession object' {
                $NC_Ses_CompRes | Should -BeOfType 'Microsoft.Management.Infrastructure.CimSession'
            }

            It 'Function returns the same CimSession object' {
                $NC_Ses_CompRes.InstanceId | Should -Be $ExCimSess.InstanceId
            }

            It 'ComputerName is correct' {
                $NC_Ses_CompRes.ComputerName | Should -Be $NC_Ses_CompName
            }

            It 'CimSession has the correct WSMAN Protocol' {
                $NC_Ses_CompRes.Protocol | Should -Be 'WSMAN'
            }

            It 'Temporary connection Flag is False' {
                $TFlag | Should -Be $false
            }

        }

        Context 'Remote computer using its Name' {

            $NC_Rem_CompName = 'TestComp01'
            $NC_Protocol = 'Wsman'
            $TFlag = $false

            # Using New-CimConnection Mock from the Main test.
            $NC_Rem_CompRes =  New-CimConnection -ComputerName $NC_Rem_CompName -Protocol $NC_Protocol -NewSessionFlag ([ref]$TFlag)

            It 'Calls New-CimSession' {
                Assert-MockCalled New-CimSession
            }

            It 'Function returns CimSession object' {
                $NC_Rem_CompRes | Should -BeOfType 'Microsoft.Management.Infrastructure.CimSession'
            }

            It 'ComputerName is correct' {
                $NC_Rem_CompRes.ComputerName | Should -Be $NC_Rem_CompName
            }

            It 'CimSession has the correct WSMAN Protocol' {
                $NC_Rem_CompRes.Protocol | Should -Be $NC_Protocol
            }

            $TFlag = $false
            $NC_Rem_CompRes =  New-CimConnection -ComputerName $NC_Rem_CompName -Protocol 'Dcom' -NewSessionFlag ([ref]$TFlag)

            It 'CimSession has the correct DCOM Protocol' {
                $NC_Rem_CompRes.Protocol | Should -Be 'Dcom'
            }

            It 'Temporary connection Flag is True' {
                $TFlag | Should -Be $true
            }
        }

    } # Context 'New-CimConnection'

    Context 'Get-DefaultValueType' {
        <#
         HKLM
          └───SOFTWARE\CustomWare
                            ├───DefaultStringKey1
                            ├───DefaultExpandedStringKey2
                            ├───DefaultBinaryKey3
                            ├───DefaultDWORDKey4
                            ├───DefaultMultiStringKey7
                            └───DefaultQWORDKey11

        The Default value is the only value in the keys. Type of value in accordance with the key name.

        #>

        # $HiddenValueKeyName = 'SOFTWARE\Microsoft\HiddenDefaultValueKey'
        # $HiddenValueKeyPath = 'HKEY_LOCAL_MACHINE\' + $HiddenValueKeyName
        # Mock Get-cdxmlSubkeyName {[PSCustomObject]@{ReturnValue = 0; sNames = $null}}                # No subkeys
        # Mock Get-cdxmlValueName  {[PSCustomObject]@{ReturnValue = 0; sNames = $null; Types = $null}} # No values (only the default that are not enumerated by WMI)
        #
        # Mock Get-cdxmlStringValue         {[PSCustomObject]@{ReturnValue = 0; sValue = 'Temple of the Winds'}}  {$PSBoundParameters.Key -eq 'SOFTWARE\CustomWare\DefaultStringKey1'}
        # Mock Get-cdxmlExpandedStringValue {[PSCustomObject]@{ReturnValue = 2147749893; sValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
        # Mock Get-cdxmlBinaryValue         {[PSCustomObject]@{ReturnValue = 2147749893; uValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
        # Mock Get-cdxmlDWORDValue          {[PSCustomObject]@{ReturnValue = 2147749893; uValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
        # Mock Get-cdxmlMultiStringValue    {[PSCustomObject]@{ReturnValue = 2147749893; sValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}
        # Mock Get-cdxmlQWORDValue          {[PSCustomObject]@{ReturnValue = 2147749893; uValue = $null}} {$PSBoundParameters.Key -eq $HiddenValueKeyName}

    } # Context 'Get-DefaultValueType'

} # Describe 'Helping Function'