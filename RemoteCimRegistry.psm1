using module .\Classes.psm1
using module .\CDXMLFunctions.cdxml


<#
.Synopsis
   Returns a registry key from the local or a remote computer.

.DESCRIPTION
   The function returns general registry key information:
       1) number of values,
       2) number of subkeys,
       3) Default value of a key (on demand).

   The Default value of a key is a legacy of old versions of Windows. However, some registry keys still have it.
   If the Default value is the only value ever created in a key, it's 'hidden' from WMI enumeration, and cannot be easily found.
   Use a dynamic parameter Force with GetDefaultValue switch to try reading the Default value directly. It will cost you several additional WMI operations.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   Get-RegistryKey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

   Returns general information about the key: key name, numer of subkeys and values.
.EXAMPLE
   Get-RegistryKey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -GetDefaultValue -ComputerName Wks11

   Returns general information about the key plus its the Default value from the computer Wks11.
.EXAMPLE
   Get-RegistryKey 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WORDPAD.EXE' -GetDefaultValue -Force

   Trys to read the Default value directly. Useful if the Default value is the only value ever created in a key, and 'hidden' from WMI enumeration.
#>
Function Get-RegistryKey {
    [CmdletBinding()] # DefaultParameterSetName='ByParameters'
    [OutputType([CIMRegistryKey])]
    Param
    (
        # Full path to a registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 1)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        [CimSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # Get the DefaultValue of a registry key.
        [switch]
        $GetDefaultValue,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )

    DynamicParam {
        If ($GetDefaultValue) {
            $attributes = [System.Management.Automation.ParameterAttribute]@{Mandatory = $false; HelpMessage = 'Try to read hidden Default value'}
            $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $attributeCollection.Add($attributes)
            $dynSwitch = [System.Management.Automation.RuntimeDefinedParameter]::new('Force', [Switch], $attributeCollection)
            $paramDictionary = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
            $paramDictionary.Add("Force", $dynSwitch)
            $paramDictionary
        }
    }

    Process {
        Try {
            $isSessionTemporary = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path']

            # Test path and permissions.
            $CimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
            Write-Verbose -Message "[WMI]: Checking access permissions for the key: '$($CimQueryParam['Key'])'"
            $TestAccessOutput = Test-cdxmlRegistryKeyAccess @CimQueryParam -AccessRequired 9 -ErrorAction Stop # KEY_QUERY_VALUE + KEY_ENUMERATE_SUB_KEYS

            If (-not $TestAccessOutput) {
                # $PSCmdlet.ThrowTerminatingError([CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess'))
                Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess')
            }

            If ($TestAccessOutput.ReturnValue -ne 0) {
                if ($TestAccessOutput.ReturnValue -eq 2) {
                    # The path doesn't found - return nothing
                    Write-Verbose -Message "[WMI]: The key was not found."
                } Elseif ($TestAccessOutput.ReturnValue -ne 5) {
                    # If not an access deny error
                    Throw [CimError]::GetWin32ErrorDescription($TestAccessOutput.ReturnValue, $OperationTarget)
                }
            }

            If ($TestAccessOutput.ReturnValue -in (0,5)) {

                $FinalData = [CIMRegistryKey]::new()
                $FinalData.Path        = $GivenParameters['Path']

                # Main queries
                Write-Verbose -Message "[WMI]: Enumerating subkeys of the key: '$($CimQueryParam['Key'])'"
                $CimSubKeyOutput = Get-cdxmlSubkeyName @CimQueryParam -ErrorAction Stop
                If ($CimSubKeyOutput.ReturnValue -eq 0) {
                    $FinalData.SubKeyCount = ($CimSubKeyOutput.sNames).Count
                } Else {
                    $SubKeyCount = $null
                    $FinalData.ErrorCode = $CimSubKeyOutput.ReturnValue
                    Write-Verbose -Message "[WMI]: Error reading subkeys number: '$(([System.ComponentModel.Win32Exception]::new([int32]$($CimSubKeyOutput.ReturnValue))).Message)'"
                }

                Write-Verbose -Message "[WMI]: Enumerating values  of the key: '$($CimQueryParam['Key'])'"
                $CimValueOutput = Get-cdxmlValueName @CimQueryParam -ErrorAction Stop
                If ($CimValueOutput.ReturnValue -eq 0) {
                    $FinalData.ValueCount = ($CimValueOutput.sNames).Count
                } Else {
                    $ValueCount = $null
                    $FinalData.ErrorCode = $CimValueOutput.ReturnValue
                    $GetDefaultValue = $false # No point to read the Default Value.
                    Write-Verbose -Message "[WMI]: Error reading values number: '$(([System.ComponentModel.Win32Exception]::new([int32]$($CimValueOutput.ReturnValue))).Message)'"
                }

                If ($Session) {
                    $FinalData.PSComputerName = $Session.ComputerName
                    If ($Session.Protocol) {$FinalData.Protocol     = $Session.Protocol}
                    If ((-not $isSessionTemporary) -and $Session.Id) {$FinalData.CimSessionId = $Session.InstanceId}
                }

                If ($GetDefaultValue) {
                    $TempQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'RootKey', 'Key', 'GetDefaultValue' -Remove
                    $TempQueryParam['Path'] = $GivenParameters['Path']
                    Write-Verbose -Message "[WMI]: Getting the default value"
                    $DefValue = Get-RegistryValue @TempQueryParam -ValueName '(default)' # -Verbose:$false
                    If ($DefValue) {
                        $FinalData.DefaultValue = $DefValue.Data
                    } Else {
                        Write-Verbose -Message "[MAIN]: Default value was not found"
                    }
                }

                $FinalData
            }

        } Catch {
            # $PSCmdlet.ThrowTerminatingError($_)
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: '$($Session.InstanceID)'"
                Remove-CimSession -CimSession $Session -ErrorAction Stop
            }
        }
    }
}

<#
.Synopsis
   Returns a list of subkeys for a specific registry key.
.DESCRIPTION
   Function returns a list of subkeys for a specific registry key.
   You can get the full list of subkeys or filter them out by names. Wildcards are permitted.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   Get-RegistrySubkey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

   Returns all the subkeys of the 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' key.
.EXAMPLE
   Get-RegistrySubkey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Subkey Win*

   Returns all subkeys whose names start with letters 'Win'.
.EXAMPLE
   Get-RegistrySubkey -Path HKEY_LOCAL_MACHINE\SOFTWARE -ComputerName Wks011 | Get-RegistryKey

   Returns all HKEY_LOCAL_MACHINE\SOFTWARE subkeys from the remote computer Wks011 and then requests more detailed information on each subkey from the same computer.
#>
Function Get-RegistrySubkey {
    [CmdletBinding()]
    [OutputType([CIMRegistryKey])]
    Param
    (
        # Full path to a registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Subkey name you want to find. Accepts wildcards.
        [Parameter(ParameterSetName='ByParameters',
                   Position = 1)]
        [Parameter(ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(ParameterSetName='ByParameters_CimSession')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_CimSession')]
        [string]
        $SubkeyName = '*',

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 2)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 2)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        [CimSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )


    Process {
        Try {
            $isSessionTemporary = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            If (-not $GivenParameters['SubkeyName']) { $GivenParameters['SubkeyName'] = $SubkeyName } # if the parameter has default value
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path']

            # Test path and permissions.
            $CimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
            Write-Verbose -Message "[WMI]: Checking access permissions for the key: '$($CimQueryParam['Key'])'"
            $TestAccessOutput = Test-cdxmlRegistryKeyAccess @CimQueryParam -AccessRequired 8 -ErrorAction Stop # KEY_ENUMERATE_SUB_KEYS

            If (-not $TestAccessOutput) {
                Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess')
            }

            if ($TestAccessOutput.ReturnValue -ne 0) {
                Throw [CimError]::GetWin32ErrorDescription($TestAccessOutput.ReturnValue, $OperationTarget)
            }

            if ($TestAccessOutput.ReturnValue -eq 0) {
                # Main query
                Write-Verbose -Message "[WMI]: Enumerating subkeys of the key: $($CimQueryParam['Key'])"
                $CimOutput = Get-cdxmlSubkeyName @CimQueryParam -ErrorAction Stop

                If (($CimOutput.sNames).Count -ne 0) {
                    # Filter them.
                    Write-Verbose -Message "[MAIN]: Looking for subkey: $($GivenParameters['SubkeyName'])"
                    $SubkeyList = @($CimOutput.sNames | Where-Object -FilterScript {$_ -like $GivenParameters['SubkeyName']})

                    # Sort and put them out
                    If ($SubkeyList.Count) {
                        $null = [array]::Sort($SubkeyList)

                        foreach ($Tkey in $SubkeyList) {
                            $FinalData = [CIMRegistryKey]::new()
                            $FinalData.Path           = $GivenParameters['Path'] + '\' + $Tkey
                            If ($Session) {
                                $FinalData.PSComputerName = $Session.ComputerName
                                If ($Session.Protocol) {$FinalData.Protocol     = $Session.Protocol}
                                If ((-not $isSessionTemporary) -and $Session.Id) {$FinalData.CimSessionId = $Session.InstanceId}
                            }
                            $FinalData
                        }
                    } Else { Write-Verbose -Message "[MAIN]: Subkey was not found" }
                } Else { Write-Verbose -Message "[MAIN]: No subkeys were found" }
            }

        } Catch {
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: $($Session.InstanceID)"
                Remove-CimSession -CimSession $Session
            }
        }
    }
}

<#
.Synopsis
   Returns a list of values and their data for a specific registry key.
.DESCRIPTION
   Function returns a list of values and their data for a registry key.
   You can get the full list of values or filter them out by names. Wildcards are permitted.

   If the Default value is the only value ever created in a key, it's 'hidden' from WMI enumeration, and cannot be easily found.
   Use parameter Force to try reading the Default value directly. It will cost you several additional WMI operations.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   Get-RegistryValue -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'

   Returns all the values of the 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' key.
.EXAMPLE
   Get-RegistryValue -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ValueName Current*

   Returns all values whose names start with word 'Current'.

.EXAMPLE
   Get-RegistryValue -Path HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DirectX -ValueName '(default)'

   Returns the default value of DirectX key.

.EXAMPLE
    Get-RegistryValue -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WRITE.EXE' -Force

    If the key has no values, the command will try to read default value directly.
#>
Function Get-RegistryValue {
    # [CmdletBinding(DefaultParameterSetName='ByParameters')]
    [OutputType([CIMRegistryValue])]
    Param
    (
        # Full path to a registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Registry Value name
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 1)]
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_CimSession')]
        [string]
        $ValueName = '*',

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 1)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        # [ValidateScript({$_ -is [Microsoft.Management.Infrastructure.CimSession]})] # To avoid auto-casting
        [CIMSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # Agressive reading of the Default value
        [switch]
        $Force,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )


    Process {
        Try {
            $isSessionTemporary = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            If (-not $GivenParameters['ValueName']) { $GivenParameters['ValueName'] = $ValueName } # if the parameter has default value
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path'] -ValueName $GivenParameters['ValueName']

            # Test path and permissions.
            $CimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
            Write-Verbose -Message "[WMI]: Checking access permissions for the key: '$($CimQueryParam['Key'])'"
            $TestAccessOutput = Test-cdxmlRegistryKeyAccess @CimQueryParam -AccessRequired 1 -ErrorAction Stop # KEY_QUERY_VALUE

            If (-not $TestAccessOutput) {
                Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess')
            }

            if ($TestAccessOutput.ReturnValue -ne 0) {
                Throw [CimError]::GetWin32ErrorDescription($TestAccessOutput.ReturnValue, $OperationTarget)
            }

            if ($TestAccessOutput.ReturnValue -eq 0) {
                Write-Verbose -Message "[WMI]: Enumerating values  of the key: $($CimQueryParam['Key'])"
                $CimOutput = Get-cdxmlValueName @CimQueryParam -ErrorAction Stop

                $ValueTmp = for ($i = 0; $i -lt ($CimOutput.sNames.Count); $i++) {
                    [PsCustomObject]@{
                        ValueName = $CimOutput.sNames[$i]
                        Type      = $CimOutput.Types[$i]
                    }
                }

                If (($CimOutput.sNames.Count -eq 0) -and ('(default)' -like $GivenParameters['ValueName']) -and $Force) {
                    # If list of values is not empty - default value is already there.
                    $ValueTmp = Get-DefaultValueType @CimQueryParam
                }

                Write-Verbose -Message "[MAIN]: Looking for value name: $($GivenParameters['ValueName'])"
                $ValueWithTypes = $ValueTmp |
                  Where-Object -FilterScript {($_.ValueName -like $GivenParameters['ValueName']) -or (($_.ValueName.Length -eq 0) -and ('(default)' -like $GivenParameters['ValueName']))} |
                    Sort-Object -Property ValueName

                If ($ValueWithTypes) {
                    foreach ($VLT in $ValueWithTypes) {
                        $CimQueryParam['ValueName'] = $VLT.ValueName

                        $Data = switch ([RegistryDataType]$VLT.Type)
                        {
                            'REG_SZ'        { $CimVal = Get-cdxmlStringValue @CimQueryParam        ; $RetVal = $CimVal.ReturnValue ; $CimVal.sValue }
                            'REG_EXPAND_SZ' { $CimVal = Get-cdxmlExpandedStringValue @CimQueryParam; $RetVal = $CimVal.ReturnValue ; $CimVal.sValue }
                            'REG_BINARY'    { $CimVal = Get-cdxmlBinaryValue @CimQueryParam        ; $RetVal = $CimVal.ReturnValue ; $CimVal.uValue }
                            'REG_DWORD'     { $CimVal = Get-cdxmlDWORDValue @CimQueryParam         ; $RetVal = $CimVal.ReturnValue ; $CimVal.uValue }
                            'REG_MULTI_SZ'  { $CimVal = Get-cdxmlMultiStringValue @CimQueryParam   ; $RetVal = $CimVal.ReturnValue ; $CimVal.sValue }
                            'REG_QWORD'     { $CimVal = Get-cdxmlQWORDValue @CimQueryParam         ; $RetVal = $CimVal.ReturnValue ; $CimVal.uValue }
                        }

                        $ResultValueName = If ($VLT.ValueName.Length -eq 0) {'(default)'} Else {$VLT.ValueName}

                        $FinalData = [CIMRegistryValue]::New()
                        $FinalData.Path           = $GivenParameters['Path']
                        $FinalData.ValueName      = $ResultValueName
                        $FinalData.ValueType      = $VLT.Type
                        $FinalData.Data           = $Data
                        $FinalData.ErrorCode      = $RetVal
                        If ($Session) {
                            $FinalData.PSComputerName = $Session.ComputerName
                            If ($Session.Protocol) {$FinalData.Protocol     = $Session.Protocol}
                            If ((-not $isSessionTemporary) -and $Session.Id) {$FinalData.CimSessionId = $Session.InstanceId}
                        }
                        $FinalData
                    } # foreach
                } Else {Write-Verbose -Message "[MAIN]: No value was found"}
            }


        } Catch {
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: $($Session.InstanceID)"
                Remove-CimSession -CimSession $Session
            }
        }
    }
}

<#
.Synopsis
   Creates a registry key.
.DESCRIPTION
   Function creates a registry key and returns the object for the key.
   If a key already exists, the function WILL NOT overwrite the key or any its values.

   By default, function returns an error if the parent key doesn't exists. Use parameter Force to create all missing parent keys.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   New-RegistryKey -Path HKEY_CURRENT_USER\Software\MyTest

   Creates 'MyTest' subkey under the existing 'HKEY_CURRENT_USER\Software' key.
.EXAMPLE
   New-RegistryKey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\JupiterInc\Callisto\OrbitalParameters' -Force

   Creates a tree of subkeys:
      'JupiterInc'
           |
           - 'Callisto'
                 |
                 - 'OrbitalParameters'
   under the existing key 'HKEY_LOCAL_MACHINE\SOFTWARE'.


#>
Function New-RegistryKey {
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='Medium' )]
    [OutputType([CIMRegistryKey])]
    Param
    (
        # Full path to a new registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 1)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        [CimSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # Create all missing parent keys.
        [switch]
        $Force,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )


    Process {
        Try {
            $isSessionTemporary = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path']

            If ($PSCmdlet.ShouldProcess($OperationTarget,'Create registry key')) {
                $CimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'

                # Test if key already exists (WMI in any case will not recreate a key)
                If (Test-RegistryPath @CimQueryParam) {
                    ## Key exists
                    Write-Verbose -Message "[WMI]: Key '$($CimQueryParam['Key'])' already exists."
                    $SubKeyCount = (Get-cdxmlSubkeyName @CimQueryParam -ErrorAction SilentlyContinue).sNames
                    $ValueCount  = (Get-cdxmlValueName  @CimQueryParam -ErrorAction SilentlyContinue).sNames
                } Else {
                    ## Creating a new key

                    # Test existence of the parent key
                    $KeyFull = $GivenParameters['Key']
                    $ParentPart = If ($KeyFull.LastIndexOf('\') -ne -1) {$KeyFull.Substring(0, $KeyFull.LastIndexOf('\'))} Else {''}
                    $CimQueryParamParent = Copy-IDictionary -IDictionary $CimQueryParam
                    $CimQueryParamParent['Key'] = $ParentPart

                    if ($Force -or (Test-RegistryPath @CimQueryParamParent)) {
                        # Creation itself
                        Write-Verbose -Message "[WMI]: Creating the key: '$($CimQueryParam['Key'])'"
                        $CimOutput = New-cdxmlRegistryKey @CimQueryParam -ErrorAction Stop # CreateKey method returns just one value - Win32 error code
                    } Else {
                        Write-Verbose -Message "[WMI]: Parent key does not exist."
                        $Excpt = [System.Management.Automation.ItemNotFoundException]::new("Parent registry key does not exist. Use parameter Force to create all missing parent keys.")
                        Throw [System.Management.Automation.ErrorRecord]::new($Excpt, "KeyNotFound", [System.Management.Automation.ErrorCategory]::ObjectNotFound, $ComputerName)
                    }

                    If (-not $CimOutput) {
                        Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CreateKey')
                    }

                    if ($CimOutput.ReturnValue -ne 0) {
                        Throw [CimError]::GetWin32ErrorDescription($CimOutput.ReturnValue, $OperationTarget)
                    }

                } # If Test-RegistryPath

                # Output for both existing and new keys

                $FinalData = [CIMRegistryKey]::new()
                $FinalData.Path = $GivenParameters['Path']
                $FinalData.SubKeyCount = if ($SubKeyCount) { $SubKeyCount.Count }
                $FinalData.ValueCount  = if ($ValueCount)  { $ValueCount.Count }
                If ($Session) {
                    $FinalData.PSComputerName = $Session.ComputerName
                    If ($Session.Protocol) {$FinalData.Protocol     = $Session.Protocol}
                    If ((-not $isSessionTemporary) -and $Session.Id) {$FinalData.CimSessionId = $Session.InstanceId}
                }
                $FinalData

            } # If ($PSCmdlet.ShouldProcess)

        } Catch {
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: $($Session.InstanceID)"
                Remove-CimSession -CimSession $Session
            }
        } # Try
    } # Process
}

<#
.Synopsis
   Creates a new or changes an existing registry value.
.DESCRIPTION
   Function changes an existing value of a registry key. You also can create a new value as well.
   If an existing value has the same type, it will be changed. If an existing value has a different type, the function will throw an error. You can use the Force switch to overwrite values of different types.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   Set-RegistryValue -Path HKEY_CURRENT_USER\Software\MyTest -ValueName StatusCode -ValueType REG_DWORD -Data 500

   Creates 'StatusCode' value that has REG_DWORD type and some data.
.EXAMPLE
   Set-RegistryValue -Path HKEY_CURRENT_USER\Software\MyTest -ValueName StatusCode -ValueType REG_QWORD -Data 5000000000 -Force

   Replaces a value from the previous example with a new one that has another type of data.

.EXAMPLE
   Get-RegistryValue -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\JupiterInc' -ValueName RedDwarf -ComputerName SRV053 | Set-RegistryValue -ComputerName Win1803

   Gets registry value RedDwarf from computer SRV053 and creates the same value on computer Win1803.
   If key HKEY_CURRENT_USER\Software\MyTest doesn't exist, use switch -Force to create it.

.EXAMPLE
   Get-RegistryValue -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\SccmInventory' -ValueName Enable | Set-RegistryValue -Data 0

   Reads the current registry value from computer SRV053 and writes new data to it.
#>
Function Set-RegistryValue {
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='High')]
    [OutputType([CIMRegistryValue])]
    Param
    (
        # Full path to a registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Registry Value name
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName)]
        [string]
        $ValueName,

        # Registry Value type
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName)]
        [RegistryDataType]
        $ValueType,

        # Registry Value data
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName)]
        [object]
        $Data,

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 1)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        [CimSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # Create the key if it doesn't exist, or overwtire the existing value if data type is different.
        [switch]
        $Force,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )


    Process {
        Try {
            $isSessionTemporary = $false
            $createKey = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            # $PSCmdlet.ParameterSetName
            # Return $PSBoundParameters
            # Add any other parameters with default value
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path']

            If ($PSCmdlet.ShouldProcess($OperationTarget,'Set registry value')) {
                # Test path and permissions.
                $TestAccessParam  = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
                Write-Verbose -Message "[WMI]: Checking access permissions for the key: '$($TestAccessParam['Key'])'"
                $TestAccessOutput = Test-cdxmlRegistryKeyAccess @TestAccessParam -AccessRequired 2  -ErrorAction Stop

                If (-not $TestAccessOutput) {
                    Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess')
                }

                if ($TestAccessOutput.ReturnValue -ne 0) {
                    If (($TestAccessOutput.ReturnValue -eq 2) -and $Force) {
                        $createKey = $true
                        Write-Verbose -Message "[WMI]: Key wasn't found: '$($TestAccessParam['Key'])'"
                    } Else {
                        Write-Verbose -Message "[WMI]: Key wasn't found: '$($TestAccessParam['Key'])'. Use -Force parameter to create it."
                        Throw [CimError]::GetWin32ErrorDescription($TestAccessOutput.ReturnValue, $OperationTarget)
                    }
                }

                if (($TestAccessOutput.ReturnValue -eq 0) -or $createKey) {
                        If ($createKey) {
                            $CreateKeyParam  = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
                            $NewKeyCimOutput = New-cdxmlRegistryKey @CreateKeyParam -ErrorAction Stop # CreateKey method returns just one value - Win32 error code
                            If ($NewKeyCimOutput.ReturnValue -ne 0) {
                                Throw [CimError]::GetWin32ErrorDescription($NewKeyCimOutput.ReturnValue, $OperationTarget)
                            }
                            Write-Verbose -Message "[WMI]: New registry key has been created: '$($CreateKeyParam['Key'])'"
                        } Else {
                            # Try to read and detect type
                            $GetCimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key', 'ValueName'
                            $GetFunctionName = switch ($GivenParameters['ValueType'])
                            {
                                'REG_SZ'        { 'Get-cdxmlStringValue'}
                                'REG_EXPAND_SZ' { 'Get-cdxmlExpandedStringValue'}
                                'REG_BINARY'    { 'Get-cdxmlBinaryValue'}
                                'REG_DWORD'     { 'Get-cdxmlDWORDValue'}
                                'REG_MULTI_SZ'  { 'Get-cdxmlMultiStringValue'}
                                'REG_QWORD'     { 'Get-cdxmlQWORDValue'}
                            }
                            # All cdxml functions return ReturnValue = 1 if no value was found.
                            # BUT! Get-cdxmlMultiStringValue returns 2 (the same as 'no key was found')

                            Write-Verbose -Message "[WMI]: Checking if the value '$($GetCimQueryParam['ValueName'])' exists"
                            $GetCimOutput = & $GetFunctionName @GetCimQueryParam -ErrorAction Stop


                            # Throw if 'Type mismatch' and no Force parameter.
                            If ($GetCimOutput.ReturnValue -eq 2147749893 -and (-not $Force)) {
                                Write-Verbose -Message "[WMI]: Value '$($GetCimQueryParam['ValueName'])' already exists and has different data type. Check for mistakes. Use -Force parameter to overwrite it."
                                Throw [CimError]::GetWin32ErrorDescription($GetCimOutput.ReturnValue, $OperationTarget)
                            }

                            If ($VerbosePreference -eq 'Continue') {
                                If ($GetCimOutput.ReturnValue -eq 0) {
                                    Write-Verbose -Message "[WMI]: Value was found. Altering its data."
                                }
                                If ($GetCimOutput.ReturnValue -in (1,2)) {
                                    Write-Verbose -Message "[WMI]: Value wasn't found. Creating a new one."
                                }
                                If ($GetCimOutput.ReturnValue -eq 2147749893 -and $Force) {
                                    Write-Verbose -Message "[WMI]: Value has different data type. Overwriting with new type."
                                }
                            }

                        } # If ($createKey)

                        # Set value.
                        $SetCimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key', 'ValueName', 'Data'
                        $SetFunctionName  = switch ($GivenParameters['ValueType'])
                        {
                            'REG_SZ'        { 'Set-cdxmlStringValue'}
                            'REG_EXPAND_SZ' { 'Set-cdxmlExpandedStringValue'}
                            'REG_BINARY'    { 'Set-cdxmlBinaryValue'}
                            'REG_DWORD'     { 'Set-cdxmlDWORDValue'}
                            'REG_MULTI_SZ'  { 'Set-cdxmlMultiStringValue'}
                            'REG_QWORD'     { 'Set-cdxmlQWORDValue'}
                        }

                        $SetCimOutput = & $SetFunctionName @SetCimQueryParam -ErrorAction Stop

                        if ($SetCimOutput.ReturnValue -ne 0) {
                            Throw [CimError]::GetWin32ErrorDescription($SetCimOutput.ReturnValue, $OperationTarget)
                        }

                        $FinalData = [CIMRegistryValue]::New()
                        $FinalData.Path           = $GivenParameters['Path']
                        $FinalData.ValueName      = $GivenParameters['ValueName']
                        $FinalData.ValueType      = $GivenParameters['ValueType']
                        $FinalData.Data           = $GivenParameters['Data']
                        If ($Session) {
                            $FinalData.PSComputerName = $Session.ComputerName
                            If ($Session.Protocol) {$FinalData.Protocol     = $Session.Protocol}
                            If ((-not $isSessionTemporary) -and $Session.Id) {$FinalData.CimSessionId = $Session.InstanceId}
                        }
                        $FinalData

                }
            } # If ($PSCmdlet.ShouldProcess)
        } Catch {
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: $($Session.InstanceID)"
                Remove-CimSession -CimSession $Session
            }
        } # Try
    } # Process
}

<#
.Synopsis
   Removes a registry key.
.DESCRIPTION
   Function removes a registry key.
   If a key was successfully removed, the functions returns nothing. If a key you want to delete doesn't exist, the function will throw an error.

   The function also will throw an error if a key has subkeys. You have to delete all the subkeys before removing their parent key.
   There is no way to delete the whole registry tree in one operation using WMI.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   Remove-RegistryKey -Path HKEY_CURRENT_USER\Software\MyTest

   Removes 'MyTest' on the LOCAL computer.

.EXAMPLE
   Get-RegistryKey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\JupiterInc' -ComputerName SERVER011  | Remove-RegistryKey -Confirm:$false

   Removes JupiterInc key on SERVER011 computer if such a key exists.

#>
Function Remove-RegistryKey {
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='High' )]
#     [OutputType([CIMRegistryKey])]
    Param
    (
        # Full path to a registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 1)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        [CimSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )


    Process {
        Try {
            $isSessionTemporary = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            # Add any other parameters with default value
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path']

            If ($PSCmdlet.ShouldProcess($OperationTarget,"Remove registry key")) {
                # Test path and permissions.
                $CimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
                Write-Verbose -Message "[WMI]: Checking access permissions for the key: '$($CimQueryParam['Key'])'"
                $TestAccessOutput = Test-cdxmlRegistryKeyAccess @CimQueryParam -AccessRequired 65536 -ErrorAction Stop # DELETE

                If (-not $TestAccessOutput) {
                    Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess')
                }

                if ($TestAccessOutput.ReturnValue -ne 0) {
                    Throw [CimError]::GetWin32ErrorDescription($TestAccessOutput.ReturnValue, $OperationTarget)
                }

                if ($TestAccessOutput.ReturnValue -eq 0) {
                        # Trying to delete the key
                        Write-Verbose -Message "[WMI]: Removing the key: '$($CimQueryParam['Key'])'"
                        $CimOutput = Remove-cdxmlRegistryKey @CimQueryParam -ErrorAction Stop

                        if ($CimOutput.ReturnValue -eq 0) {

                            ###################
                            #
                            # If removal was successful - return nothing.
                            #
                            ###################
                        }

                        if ($CimOutput.ReturnValue -ne 0) {
                            If ($CimOutput.ReturnValue -eq 5) {
                                Write-Verbose -Message "[WMI]: Operation returned 'Access is denied' message. Checking subkeys existance."
                                $SubkeyList = Get-cdxmlSubkeyName @CimQueryParam -ErrorAction Stop # Check if there are subkeys
                                If ($SubkeyList.sNames.Count) {
                                     Throw [CimError]::SubkeysExist($SubkeyList.sNames.Count, $OperationTarget)
                                }
                            }
                            Throw [CimError]::GetWin32ErrorDescription($CimOutput.ReturnValue, $OperationTarget)
                        }
                }
            } # If ($PSCmdlet.ShouldProcess)
        } Catch {
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: $($Session.InstanceID)"
                Remove-CimSession -CimSession $Session
            }
        } # Try
    } # Process
}

<#
.Synopsis
   Removes a registry value.
.DESCRIPTION
   Function removes a value of a registry key.
   If a value was successfully removed, the functions returns nothing. If a value doesn't exist, the function will throw an error.

   The function uses a CIMSession (WSMAN/DCOM protocols) to connect to a remote computer. You can use the name of a computer as well as a pre-created CIMSession object.
   In the first case the function will create a temporary CIMSession, and close it afterward.

.EXAMPLE
   Remove-RegistryValue -Path HKEY_CURRENT_USER\Software\MyTest -ValueName InstallationDate

   Deletes 'MyTest' key on the SERVER011 computer.
.EXAMPLE
   Get-RegistryKey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\JupiterInc' -ComputerName SRV053 | Get-RegistryValue -ValueName RedDwarf | Remove-RegistryValue

   Removes value RedDwarf from JupiterInc registry key on SRV053 computer if such a key and value exist.

#>
Function Remove-RegistryValue {
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='High')]
    # [OutputType([CIMRegistryKey])]
    Param
    (
        # Full path to a registry key.
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_CimSession',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters',
                   Position = 0)]
        [ArgumentCompleter([CIMRegPathCompleter])]
        [string]
        $Path,

        # Registry Value name
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName)]
        [string]
        $ValueName,

        # Computer name. Local computer by default (as well as 'localhost' or '.')
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName',
                   Position = 1)]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 1)]
        [Alias('PSComputerName')]
        [string]
        $ComputerName,

        # Pre-created CimSession object.
        [Parameter(Mandatory,
                   ParameterSetName='ByParameters_CimSession')]
        [Parameter(Mandatory,
                   ParameterSetName='ByInputObject_CimSession')]
        [Alias('Session')]
        [CimSession]
        $CimSession,

        # Protocol to use for a temporary CIM session.
        [Parameter(ValueFromPipelineByPropertyName,
                   ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByInputObject')]
        [ValidateSet('Dcom','Wsman','Default')]
        [string]
        $Protocol = 'Default',

        # Specifies a user account that has permission to perform this action. If Credential is not specified, the current user account is used.
        [Parameter(ParameterSetName='ByParameters')]
        [Parameter(ParameterSetName='ByParameters_ComputerName')]
        [Parameter(ParameterSetName='ByInputObject')]
        [Parameter(ParameterSetName='ByInputObject_ComputerName')]
        [PSCredential]
        $Credential,

        # The parameter takes an input objects coming from the pipeline.
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_ComputerName',
                   Position = 0)]
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ParameterSetName='ByInputObject_CimSession',
                   Position = 0)]
        [CIMRegistryObject]
        $InputObject
    )


    Process {
        Try {
            $isSessionTemporary = $false
            $GivenParameters = New-ParameterTable -BoundParams $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName -TempFlag ([ref]$isSessionTemporary)
            # Add any other parameters with default value
            $Session = $GivenParameters['CimSession']
            $OperationTarget = New-TargetString -ComputerName $Session.ComputerName -Path $GivenParameters['Path'] -ValueName $GivenParameters['ValueName']

            If ($PSCmdlet.ShouldProcess($OperationTarget,'Remove registry value')) {
                # Test path and permissions.
                $TestCimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key'
                Write-Verbose -Message "[WMI]: Checking access permissions for the key: '$($TestCimQueryParam['Key'])'"
                $TestAccessOutput = Test-cdxmlRegistryKeyAccess @TestCimQueryParam -AccessRequired 2 -ErrorAction Stop # KEY_SET_VALUE


                If (-not $TestAccessOutput) {
                    Throw [CimError]::EmptyCIMOutput($Session.ComputerName, 'CheckAccess')
                }

                if ($TestAccessOutput.ReturnValue -ne 0) {
                    Throw [CimError]::GetWin32ErrorDescription($TestAccessOutput.ReturnValue, $OperationTarget)
                }

                if ($TestAccessOutput.ReturnValue -eq 0) {
                    # Prepare query parameters
                    $CimQueryParam = Copy-IDictionary -IDictionary $GivenParameters -Key 'CimSession', 'RootKey', 'Key', 'ValueName'

                    # Trying to delete the Value
                    Write-Verbose -Message "[WMI]: Removing the value: '$($GivenParameters['ValueName'])'"
                    $CimOutput = Remove-cdxmlRegistryValue @CimQueryParam -ErrorAction Stop

                    if ($CimOutput.ReturnValue -eq 0) {

                        ###################
                        #
                        # If removal was successful - return nothing.
                        #
                        ###################
                    }

                    if ($CimOutput.ReturnValue -ne 0) {
                        If ($CimOutput.ReturnValue -eq 2) {
                            # registry key path was checked on the fists steps, hence no such Value exists.
                            Write-Verbose -Message "[WMI]: Value was not found."
                            Throw [CimError]::GetWin32ErrorDescription(1, $OperationTarget)
                        }
                        Throw [CimError]::GetWin32ErrorDescription($CimOutput.ReturnValue, $OperationTarget)
                    }
                }
            } # If ($PSCmdlet.ShouldProcess)

        } Catch {
            Write-Error -ErrorRecord $_
        } Finally {
            # Close connection
            if ($Session -and $isSessionTemporary) {
                Write-Verbose -Message "[CONNECTION]: Closing temporary CimSession: $($Session.InstanceID)"
                Remove-CimSession -CimSession $Session
            }
        } # Try
    } # Process
}



### Helping functions ###

<#
    Function New-ParameterTableOld returns a hashtable with parameters that bound directly or by a pipeline object.
    Registry path gets splited.
    All bounded parameters (except network) will be in the result hashtable.
#>
Function New-ParameterTable ($BoundParams, $ParameterSetName, [ref]$TempFlag) {
    # $BoundParams is a reference to $PSBoundParameters from a calling function.
    $ParameterList = Copy-IDictionary -IDictionary $BoundParams -Remove 'CimSession', 'ComputerName', 'Protocol', 'Credential', 'InputObject'
    $TargetComputer = If ($BoundParams['ComputerName']) { # -and ($BoundParams['ComputerName'] -ne 'localhost')
        $BoundParams['ComputerName']
    } ElseIf ($BoundParams['CimSession']) {
        $BoundParams['CimSession']
    } Else {$null}

    If ($ParameterSetName -like 'ByParameters*') {

        $ParameterList['Path'] = $ParameterList['Path'].Trim('\')
        $ParameterList         = $ParameterList + (Split-RegistryPath -RegistryPath $BoundParams['Path'])

        If ($TargetComputer) {
            $CIMSessParam  = Copy-IDictionary -IDictionary $BoundParams -Key 'Protocol','Credential'
            $CIMSessParam['ComputerName'] = $TargetComputer
        } Else { $CIMSessParam  = @{} } # Empty hashtable, just for the final If statement.

    } # 'ByParameters*'

    If ($ParameterSetName -like 'ByInputObject*') {

        $InputObject   = $BoundParams['InputObject']

        # Registry parameters from input object.
        $ParameterList['Path'] = $InputObject.Path
        $ParameterList         = $ParameterList + (Split-RegistryPath -RegistryPath $InputObject.Path)
        If ((-not $ParameterList['ValueName']) -and $InputObject.ValueName) {
            $ParameterList['ValueName'] = $InputObject.ValueName
        }

        # Network connection parameters by priorities.
        Switch ($true) {
            {$TargetComputer} {
                ### ComputerName/CimSession parameters - Precedence #1
                # (effectively - ignor any network data from InputObject)
                # Notice - CimSession param can also contain a pre-created [CimSession] from parameters.
                $CIMSessParam  = Copy-IDictionary -IDictionary $BoundParams -Key 'Protocol','Credential'
                $CIMSessParam['ComputerName'] = $TargetComputer
                Break
            }

            {$InputObject.CimSessionId -as [guid]} {
                ### Pre-created [CimSession] from InputObject by GUID - Precedence #2
                # (if $InputObject.CimSessionId contains reference to an alive [CimSession])
                $ExistingSession = Get-CimSession -InstanceId $InputObject.CimSessionId -ErrorAction SilentlyContinue
                if ($ExistingSession) {
                    $CIMSessParam  = @{'ComputerName' = $ExistingSession}
                    # $CIMSessParam['ComputerName'] = $ExistingSession
                    # Insert Should question if [CimSession] computername is not equal $InputObject.PSComputerName ?
                    Break
                }
            }

            {$InputObject.PSComputerName} {
                ### PSComputerName from InputObject - Precedence #3
                $CIMSessParam  = Copy-IDictionary -IDictionary $BoundParams -Key 'Protocol','Credential'
                $CIMSessParam['ComputerName'] = $InputObject.PSComputerName
                If (-not $CIMSessParam['Protocol']) {
                    $CIMSessParam['Protocol']   = $InputObject.Protocol
                }
            }
        }
    } # 'ByInputObject*'


    If ($CIMSessParam['ComputerName'] -and ($CIMSessParam['ComputerName'] -ne 'localhost') -and ($CIMSessParam['ComputerName'] -ne '.')) {
        $ParameterList['CimSession'] = New-CimConnection @CIMSessParam -NewSessionFlag $TempFlag
    } Else {
        Write-Verbose -Message "[CONNECTION]: Connecting to the local computer. No CimSession was created."
    }

    $ParameterList

}

<#
The function returns a hastable. With some elements or emty.
 #>
function Copy-IDictionary
{
    # [CmdletBinding()]
    # [OutputType([System.Collections.IDictionary])]
    Param
    (
        # Hashtable-like object to copy
        #[Parameter(Mandatory=$true)]
        [System.Collections.IDictionary]
        $IDictionary,

        # Names of keys. By default, to copy them.
        [String[]]
        $Key,

        # Copy all records except
        [switch]
        $Remove

    )
    $Hashtable = @{}

    If ($Remove) {
        foreach ($i in ($IDictionary.GetEnumerator())) {
            If ($i.Key -notin $Key) {$Hashtable.Add($i.Key,$i.Value)}
        }
    } Else {
        If ($key) {
            foreach ($i in ($IDictionary.GetEnumerator())) {
                If ($i.Key -in $Key) {$Hashtable.Add($i.Key,$i.Value)}
            }
        } Else {
            foreach ($i in ($IDictionary.GetEnumerator())) {
               $Hashtable.Add($i.Key,$i.Value)
            }
        }
    }

    $Hashtable
}

<#
The function returns a hashtable.
 #>
Function Split-RegistryPath ($RegistryPath) {
    if ($RegistryPath.Trim('\') -notmatch '(?<RootKey>^\w+)(?:\\(?<Key>.+))*$') {
        throw "'$RegistryPath' is not a valid registry path."
    }

    $Matches['RootKey'] = $Matches['RootKey'] -replace 'HKLM', 'HKEY_LOCAL_MACHINE'
    $Matches['RootKey'] = $Matches['RootKey'] -replace 'HKCU', 'HKEY_CURRENT_USER'
    $Matches['RootKey'] = $Matches['RootKey'] -replace 'HKU',  'HKEY_USERS'
    $Matches['RootKey'] = $Matches['RootKey'] -replace 'HKCC', 'HKEY_CURRENT_CONFIG'
    $Matches['RootKey'] = $Matches['RootKey'] -replace 'HKCR', 'HKEY_CLASSES_ROOT'

    If ($Matches['RootKey'] -notin ("HKEY_LOCAL_MACHINE",
                                    "HKEY_CURRENT_USER",
                                    "HKEY_USERS",
                                    "HKEY_CURRENT_CONFIG",
                                    "HKEY_CLASSES_ROOT",
                                    "HKEY_PERFORMANCE_DATA")) {
          throw "'$( $Matches['RootKey'] )' is not a valid registry root key."
    }
    @{
        RootKey  = $Matches['RootKey']
        Key      = $Matches['Key']
    }
}

<#
The function accepts ComputerName parameter. If ComputerName is:
 1) [string]  - new (temporary) CimSessioon will be created.
 2) [CimSession] - will return an existing session.
#>
Function New-CimConnection
{
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='Low' )]
    [OutputType([CimSession])]
    Param
    (
        # Computer to connect to
        # [string]
        [Parameter(Mandatory)]
        [Alias('CimSession')]
        $ComputerName,

        # Protocol to use
        [string]
        [ValidateSet('Dcom','Wsman','Default')]
        $Protocol = 'Default',

        [PSCredential]
        $Credential,

        [Parameter(Mandatory)]
        [ref]
        $NewSessionFlag

    )

    If ($PSCmdlet.ShouldProcess($ComputerName,"Open CimSession")) { # Will block creating a new session in case of -WhatIf
        Switch ($ComputerName) {
            {$_ -is [CimSession]} {
                # If it is pre-created Cimsession, return as it is.
                If ($_.Id) {
                    Write-Verbose -Message "[CONNECTION]: Using pre-existing CimSession: $($_.InstanceID). Computer: '$($_.ComputerName)'. Protocol: '$($_.Protocol)'."
                } Else {
                    Write-Verbose -Message "[CONNECTION]: Using a computer name with the CimSession parameter, huh?"
                    Write-Verbose -Message "[CONNECTION]: Well, automatic temporary session will be created by PowerShell. Protocol: 'Default'."
                }
                $_
            }
            {$_ -is [System.String]} {
                # If it is a computername - make new session.
                $SesOpt = New-CimSessionOption -Protocol $Protocol

                Write-Verbose -Message "[CONNECTION]: Creating temporary CimSession. Computer: '$ComputerName'. Protocol: '$Protocol'."
                If ($Credential) {
                    Write-Verbose -Message "[CONNECTION]: Using credential: '$($Credential.UserName)'"
                    $Session = New-CimSession -ComputerName $_ -SessionOption $SesOpt -Credential $Credential -ErrorAction Stop -Verbose:$false
                } Else {
                    Write-Verbose -Message "[CONNECTION]: Using current user credential"
                    $Session = New-CimSession -ComputerName $_ -SessionOption $SesOpt -ErrorAction Stop -Verbose:$false
                }

                $NewSessionFlag.Value = $true
                $Session

            }
           Default { Throw [CimError]::UnsupportedCimSessionValue($_) }
        }
    } # ShouldProcess
}

<#
Function checks if a hidden Default value exists and returns its type,
as if it was enumerated by Get-cdxmlValueName (method EnumValues of ROOT/DEFAULT/StdRegProv WMI provider)
#>
Function Get-DefaultValueType ($RootKey, $Key) {
    # Most Default values are REG_SZ.
    Write-Verbose -Message "[DEFAULT_VALUE]: Testing existence of Default Value."
    $CimOutput = Get-cdxmlStringValue -RootKey $RootKey -Key $Key -ValueName ''

    If ($CimOutput.ReturnValue -eq 2) {Return}      # Key not found (just in case)
    If ($CimOutput.ReturnValue -eq 1) {
        Write-Verbose -Message "[DEFAULT_VALUE]: Default Value is not present."
        Return
    }      # Default Value not found. The most often.

    If ($CimOutput.ReturnValue -eq 0) { $VType = 1 }  # Less often. It's a normal string value.

    If ($CimOutput.ReturnValue -eq 2147749893) {    # Hope very rare. Type mismatch.
        $VType = Switch (0) {
            ((Get-cdxmlExpandedStringValue -RootKey $RootKey -Key $Key -ValueName '').ReturnValue) {2}
            ((Get-cdxmlBinaryValue -RootKey $RootKey -Key $Key -ValueName '').ReturnValue)         {3}
            ((Get-cdxmlDWORDValue -RootKey $RootKey -Key $Key -ValueName '').ReturnValue)          {4}
            ((Get-cdxmlMultiStringValue -RootKey $RootKey -Key $Key -ValueName '').ReturnValue)    {7}
            ((Get-cdxmlQWORDValue -RootKey $RootKey -Key $Key -ValueName '').ReturnValue)         {11}
            Default {99}
        }

    }
    Write-Verbose -Message "[DEFAULT_VALUE]: Default Value is a $([RegistryDataType]$VType)."
    [PsCustomObject]([ordered]@{
        ValueName = ''
        Type      = $VType
    })
}

Function Test-RegistryPath ($RootKey, $Key, $CimSession) {
    $Verdict = If ($CimSession) {
        Test-cdxmlRegistryKeyAccess -RootKey $RootKey -Key $Key -CimSession $CimSession -ErrorAction Stop # -AccessRequired 8
    } Else {
        Test-cdxmlRegistryKeyAccess -RootKey $RootKey -Key $Key -ErrorAction Stop
    }
    If (($Verdict.ReturnValue -eq 0) -or ($Verdict.ReturnValue -eq 5)) {$true} Else {$false}
}

Function New-TargetString ($ComputerName, $Path, $ValueName) {
    $ComputerName = If ($ComputerName) {$ComputerName} Else {$env:COMPUTERNAME}
    If ($ValueName) {
        "$ComputerName\$Path : $ValueName"
    } Else {
        "$ComputerName\$Path"
    }
}

Function Get-REG_EXPAND_SZ ($ComputerName, $RootKey, $Key, $ValueName) {
    $RootUInt = @{
        'HKEY_CLASSES_ROOT'     = [UInt32]2147483648
        'HKEY_CURRENT_USER'     = [UInt32]2147483649
        'HKEY_LOCAL_MACHINE'    = [UInt32]2147483650
        'HKEY_USERS'            = [UInt32]2147483651
        'HKEY_PERFORMANCE_DATA' = [UInt32]2147483652
        'HKEY_CURRENT_CONFIG'   = [UInt32]2147483653
    }
    If ($ComputerName) {
        $RegRootKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RootUInt[$RootKey], $ComputerName)
    } Else {
        $RegRootKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RootUInt[$RootKey], [Microsoft.Win32.RegistryView]::Registry64)
    }

    $RegKey = $RegRootKey.OpenSubKey($Key,$false) # not writtable
    $RegExpandValue = $RegKey.GetValue($ValueName,$null,[Microsoft.Win32.RegistryValueOptions]'DoNotExpandEnvironmentNames')

    $RegKey.Close()        # Close and write to disk (Flush())
    $RegKey.Dispose()      # Releases all resources (very good practice)
    $RegRootKey.Close() # No effect to system keys, because system keys are never closed.
    $RegRootKey.Dispose()

    $RegExpandValue
}


# Get-REG_EXPAND_SZ -ComputerName CM01 -RootKey 'HKEY_LOCAL_MACHINE' -Key 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ValueName ComputerName
# Get-REG_EXPAND_SZ -RootKey 'HKEY_LOCAL_MACHINE' -Key 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ValueName ComputerName


