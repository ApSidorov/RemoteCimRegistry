# This is a Pester test file

# Test general behaviour, such as check of Path and network parameters, and network CIM calls.
# The test uses general Mocks from the Main test. All other Mocks defined locally.

Param
(
    # Name of a CIMRegistry module function to test
    [Parameter(Mandatory=$true)]
    $FunctionName,

    [hashtable]
    $ExtraParams = @{},

    # What function retuns if Path doesn't exists
    [ValidateSet("Null", "Error", "NA")]
    $WrongPathReturn,

    # Check network info in output object or not (Remove-* function have no output)
    [switch]
    $CheckOutput
)

# Check common properties of output object ?
# Pre-cr session goes throug pipeline (InstanceID)
Describe "Common tests for $FunctionName" {

#region Mocks

    # VALUES: We simulate only one type of values - REG_SZ. It's enough to test common logic of the functions.

    # Parent key
    $MockKeyParentName = 'SOFTWARE\Discworld\Ramtop'
    Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } { $PSBoundParameters.Key -eq $MockKeyParentName }


    # Child key
    $MockKeyName = 'SOFTWARE\Discworld\Ramtops\Lancre'
    $MockKeyPath = 'HKEY_LOCAL_MACHINE\' + $MockKeyName

    $MockSubkeyList = [PSCustomObject]@{ReturnValue = 0; sNames = @('Castle')}
    $MockValueList  = [PSCustomObject]@{ReturnValue = 0; sNames = @('King'); Types =  @(1)}
    $MockValue      = [PSCustomObject]@{ReturnValue = 0; sValue = 'Verence'}

    Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 0; bGranted = $true} } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock Get-cdxmlSubkeyName  { $MockSubkeyList } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock Get-cdxmlValueName   { $MockValueList  } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock Get-cdxmlStringValue { $MockValue      } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock Set-cdxmlStringValue { [PSCustomObject]@{ReturnValue = 0} } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock New-cdxmlRegistryKey { [PSCustomObject]@{ReturnValue = 0} } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock Remove-cdxmlRegistryKey      { [PSCustomObject]@{ReturnValue = 0} } { $PSBoundParameters.Key -eq $MockKeyName }
    Mock Remove-cdxmlRegistryValue    { [PSCustomObject]@{ReturnValue = 0} } { $PSBoundParameters.Key -eq $MockKeyName }

    # No access key
    $MockNoAccessKeyName = 'SOFTWARE\Discworld\Ramtops\Cori Celesti'
    $MockNoAccessKeyPath = 'HKEY_LOCAL_MACHINE\' + $MockNoAccessKeyName
    Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 5; bGranted = $false} } { $PSBoundParameters.Key -eq $NoSuchKeyName }

    # Non-existing key mock
    $NoSuchKeyName = 'SOFTWARE\NoSuchKey'
    $NoSuchKeyPath = 'HKEY_LOCAL_MACHINE\' + $NoSuchKeyName
    Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 2; bGranted = $false} } { $PSBoundParameters.Key -eq $NoSuchKeyName }

    # 


#endregion

    $TestedCommand = Get-Command $FunctionName
    Context 'Input' {

        It 'Parameter Path must be Mandatory ' {
            foreach ($prm in ($TestedCommand.Parameters['Path'].Attributes.Mandatory)) {
                $prm | Should Be $true
            }
        }

        It 'Throws if Path syntax is not correct' {
            { & $FunctionName -Path '*HKEY_LOCAL_MACHINE\SOFTWARE\Discworld\Ramtop' -ErrorAction Stop @ExtraParams } | Should Throw 'is not a valid registry path'
        }

        It 'Throws if RootKey is not correct' {
            { & $FunctionName -Path 'NO_SUCH_ROOTKEY\SOFTWARE' -ErrorAction Stop @ExtraParams } | Should Throw 'is not a valid registry root key'
        }

        It "Returns $WrongPathReturn if Path does not exist" {
            If ($WrongPathReturn -eq 'Error') {
                {& $FunctionName -Path $NoSuchKeyPath -ErrorAction Stop @ExtraParams } | Should Throw 'Registry key does not exist'
            }
            If ($WrongPathReturn -eq 'Null') {
                & $FunctionName -Path $NoSuchKeyPath  @ExtraParams | Should -BeNullOrEmpty
            }
        }

        It 'Throws  if Protocol argument is not Dcom or Wsman' {
            {& $FunctionName -Path $MockKeyPath -ComputerName $RemoteCompName -Protocol HTTPS @ExtraParams} | Should Throw "Cannot validate argument on parameter 'Protocol'"
        }

        It 'Throws if there are both Cimsession and ComputerName' {
            {& $FunctionName -Path $MockKeyPath -ComputerName $RemoteCompName -CimSession $ExistingCimSession @ExtraParams} | Should Throw 'Parameter set cannot be resolved'
        }

    }

    Context 'Local Execution' {

        $LocalResult = & $FunctionName -Path $MockKeyPath @ExtraParams

        It 'Does not call New-CimSession to access local registry ' {
            Assert-MockCalled New-CimSession -Times 0 -Exactly
        }

        If ($CheckOutput) {
            It 'ComputerName is localhost' {
                $LocalResult.PSComputerName | Should -Be 'localhost'
            }

            It 'CimSessionId is empty' {
                $LocalResult.CimSessionId | Should -BeNullOrEmpty
            }
        }
    } # 'Local Execution'

    Context 'Network Execution' {

        Context 'Remote Execution with Different protocols WSMAN/DCOM' {
            It 'Calls New-CimSession with WSMAN options' {
                & $FunctionName -Path $MockKeyPath -ComputerName $RemoteCompName -Protocol WSMAN  @ExtraParams
                Assert-MockCalled New-CimSession -ParameterFilter {($PSBoundParameters.SessionOption).GetType().Name -eq 'WSManSessionOptions'}
            }

            It 'Calls New-CimSession with DCOM options' {
                & $FunctionName -Path $MockKeyPath -ComputerName $RemoteCompName -Protocol Dcom  @ExtraParams
                Assert-MockCalled New-CimSession -ParameterFilter {($PSBoundParameters.SessionOption).GetType().Name -eq 'DComSessionOptions'}
            }
        }

        Context 'Remote Execution with temporary CIMsession' {
            $RemoteResult = & $FunctionName -Path $MockKeyPath -ComputerName $RemoteCompName @ExtraParams

            It 'Calls New-CimSession with the proper ComputerName parameter' {
                Assert-MockCalled New-CimSession -Times 1 -Exactly -ParameterFilter {$PSBoundParameters.ComputerName -eq $RemoteCompName}
            }

            It 'Removes a temporary CIMsession' {
                Assert-MockCalled Remove-CimSession -Times 1 -Exactly
            }

            If ($CheckOutput) {
                It 'ComputerName is correct' {
                    $RemoteResult.PSComputerName | Should -Be $RemoteCompName
                }

                It 'CimSessionId is empty' {
                    $RemoteResult.CimSessionId | Should -BeNullOrEmpty
                }
            }
        }

        Context 'Remote Execution with pre-existing CIMsession' {

            $RemoteSesResult = & $FunctionName -Path $MockKeyPath -CimSession $ExistingCimSession @ExtraParams

            It 'Does not call New-CimSession' {
                Assert-MockCalled New-CimSession -Times 0 -Exactly
            }

            It 'Leaves alone external CIMsession' {
                Assert-MockCalled Remove-CimSession -Times 0 -Exactly
            }

            If ($CheckOutput) {
                It 'ComputerName is correct' {
                    $RemoteSesResult.PSComputerName | Should -Be $ExistingCimSession.ComputerName
                }

                It 'CimSessionId is correct' {
                    $RemoteSesResult.CimSessionId | Should -Be $ExistingCimSession.InstanceId
                }
            }
        }

        Context 'Remote Execution with automatically created CIMsession' {
            # The name of a computer was passed to CimSession parameter.
            $RemoteSesResult = & $FunctionName -Path $MockKeyPath -CimSession $RemoteCompName @ExtraParams

            It 'Does not call New-CimSession' {
                Assert-MockCalled New-CimSession -Times 0 -Exactly
            }

            It 'Does not call Remove-CimSession' {
                Assert-MockCalled Remove-CimSession -Times 0 -Exactly
            }
            If ($CheckOutput) {
                It 'ComputerName is correct' {
                    $RemoteSesResult.PSComputerName | Should -Be $RemoteCompName
                }

                It 'CimSessionId is empty' {
                    $RemoteSesResult.CimSessionId | Should -BeNullOrEmpty
                }
            }
        }

    } # 'Network Execution'

    Context 'Pipeline parameter bindings' {

        Context 'Local only query' {

            Context 'Native object type' {
                 $NativeResult = Get-RegistryKey -Path $MockKeyPath | & $FunctionName @ExtraParams

                 It 'Does not call New-CimSession' {
                     Assert-MockCalled New-CimSession -Times 0 -Exactly
                 }

                 It 'Does not call Remove-CIMsession' {
                     Assert-MockCalled Remove-CimSession -Times 0 -Exactly
                 }

                 If ($CheckOutput) {
                     It 'ComputerName is localhost' {
                         $NativeResult.PSComputerName | Should -Be 'localhost'
                     }

                     It 'CimSessionId is empty' {
                         $NativeResult.CimSessionId | Should -BeNullOrEmpty
                     }
                 }            
             } # 'Native object type'

            Context 'PSCustomObject type' {
                 $PSCustomTempObject = Get-RegistryKey -Path $MockKeyPath | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv
                 $PSCustomResult     = $PSCustomTempObject | & $FunctionName @ExtraParams

                 It 'Does not call New-CimSession' {
                     Assert-MockCalled New-CimSession -Times 0 -Exactly
                 }

                 It 'Does not call Remove-CIMsession' {
                     Assert-MockCalled Remove-CimSession -Times 0 -Exactly
                 }

                 If ($CheckOutput) {
                     It 'ComputerName is localhost' {
                         $PSCustomResult.PSComputerName | Should -Be 'localhost'
                     }

                     It 'CimSessionId is empty' {
                         $PSCustomResult.CimSessionId | Should -BeNullOrEmpty
                     }
                 }            
             } # 'Native object type'

        }  #'Local query' 

        Context 'Temporary CIMSession' {

            Context 'Native object type' {
                 $NativeResult = Get-RegistryKey -Path $MockKeyPath -ComputerName $RemoteCompName -Protocol Wsman | & $FunctionName @ExtraParams

                 It 'Does not call New-CimSession' {
                     Assert-MockCalled New-CimSession -Times 2 -Exactly
                 }

                 It 'Does not call Remove-CIMsession' {
                     Assert-MockCalled Remove-CimSession -Times 2 -Exactly
                 }

                 If ($CheckOutput) {
                     It 'ComputerName is correct' {
                         $NativeResult.PSComputerName | Should -Be $RemoteCompName
                     }

                     It 'CimSessionId is empty' {
                         $NativeResult.CimSessionId | Should -BeNullOrEmpty
                     }

                     It 'Protocol is correct' {
                         $NativeResult.Protocol | Should -Be 'Wsman'
                     }

                 }            
            } # 'Native object type'

            Context 'PSCustomObject type' {
                 $PSCustomTempObject = Get-RegistryKey -Path $MockKeyPath -ComputerName $RemoteCompName -Protocol Wsman | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv
                 $PSCustomResult     = $PSCustomTempObject | & $FunctionName -Protocol Dcom @ExtraParams

                 It 'Does not call New-CimSession' {
                     Assert-MockCalled New-CimSession -Times 2 -Exactly
                 }

                 It 'Does not call Remove-CIMsession' {
                     Assert-MockCalled Remove-CimSession -Times 2 -Exactly
                 }

                 If ($CheckOutput) {
                     It 'ComputerName is correct' {
                         $PSCustomResult.PSComputerName | Should -Be $RemoteCompName
                     }

                     It 'CimSessionId is empty' {
                         $PSCustomResult.CimSessionId | Should -BeNullOrEmpty
                     }

                     It 'Protocol was changed correctly' {
                         $PSCustomResult.Protocol | Should -Be 'Dcom'
                     }
                 }            
            } # 'Native object type'

         }  # 'Temporary CIMSession'

        Context 'Pre-existing CIMsession' {

            Context 'Native object type' {
                 $NativeResult = Get-RegistryKey -Path $MockKeyPath -CimSession $ExistingCimSession | & $FunctionName @ExtraParams

                 It 'Does not call New-CimSession' {
                     Assert-MockCalled New-CimSession -Times 0 -Exactly
                 }

                 It 'Does not call Remove-CIMsession' {
                     Assert-MockCalled Remove-CimSession -Times 0 -Exactly
                 }

                 If ($CheckOutput) {
                     It 'ComputerName is correct' {
                         $NativeResult.PSComputerName | Should -Be $ExistingCimSession.ComputerName
                     }

                     It 'CimSessionId is correct' {
                         $NativeResult.CimSessionId | Should -Be $ExistingCimSession.InstanceId
                     }
                 }            
             } # 'Native object type'

            Context 'PSCustomObject type' {
                 # CimSessionId gets exported BUT not binded from PSCustomObject (there is no such parameter in the functions) as the result - temporary session down on the pipe.
                 $PSCustomTempObject = Get-RegistryKey -Path $MockKeyPath -CimSession $ExistingCimSession | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv
                 $PSCustomResult     = $PSCustomTempObject | & $FunctionName @ExtraParams


                 It 'Does not call New-CimSession' {
                     Assert-MockCalled New-CimSession -Times 1 -Exactly
                 }

                 It 'Does not call Remove-CIMsession' {
                     Assert-MockCalled Remove-CimSession -Times 1 -Exactly
                 }

                 If ($CheckOutput) {
                     It 'ComputerName is correct' {
                         $PSCustomResult.PSComputerName | Should -Be $ExistingCimSession.ComputerName
                     }

                     It 'CimSessionId is empty' {
                         $PSCustomResult.CimSessionId | Should -BeNullOrEmpty
                     }
                 }            
             } # 'Native object type'

         }  # 'Pre-existing CIMsession'

    } # 'Pipeline parameter bindings'
<#
    Context 'Pipeline errors handling' {
        $ThreeKeys = 1..3 | ForEach-Object {Get-RegistryKey -Path $MockKeyPath}
        $ThreeKeys[1].Path = $MockNoAccessKeyPath
        $PartialResult = $ThreeKeys | & $FunctionName -ErrorAction Stop @ExtraParams
 
        It 'Continues pipeline operations after a WMI error' {
            $PartialResult = $ThreeKeys | & $FunctionName @ExtraParams
            Assert-MockCalled Test-cdxmlRegistryKeyAccess -Times 3 -Exactly -Scope It
        } -Skip

        If ($CheckOutput) {
            It 'Skips an error object returns with the rest' {
                $PartialResult.Count | Should -Be 2
            } 
        }
    }
#>
}
