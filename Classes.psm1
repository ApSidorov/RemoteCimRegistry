using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# CIMRegistryKey is extended in the Types.ps1xml

class CIMRegistryObject {
#    [string]$Path
    [string]$PSComputerName  = 'localhost'
    [ValidateSet('Dcom','Wsman','Default')]
    [string]$Protocol = 'Default'
    [string]$CimSessionId # System.Guid
    [UInt32]$ErrorCode
}

class CIMRegistryKey:CIMRegistryObject {
    [string]$Path
    [string]$ParentKey
    [string]$Key
    $DefaultValue
    $SubKeyCount
    $ValueCount

    CIMRegistryKey () {}

    CIMRegistryKey ([string]$Path, [string]$PSComputerName, [string]$Protocol, [string]$CimSessionId) {
        $this.Path = $Path
        $this.PSComputerName = $PSComputerName
        $this.Protocol       = $Protocol
        $this.CimSessionId     = $CimSessionId
    }

    CIMRegistryKey ([string]$Path, $DefaultValue, $SubKeyCount, $ValueCount, [string]$PSComputerName, [string]$Protocol, [string]$CimSessionId) {
        $this.Path = $Path
        $this.DefaultValue   = $DefaultValue
        $this.SubKeyCount   = $SubKeyCount
        $this.ValueCount    = $ValueCount
        $this.PSComputerName = $PSComputerName
        $this.Protocol       = $Protocol
        $this.CimSessionId     = $CimSessionId
    }
}


class CIMRegistryValue:CIMRegistryObject {
    [string]$Path
    [string]$ValueName
    [RegistryDataType]$ValueType
    [object]$Data

    CIMRegistryValue () {}
    CIMRegistryValue ([string]$Path) {
        $this.Path       = $Path
    }
    CIMRegistryValue ([string]$Path,[string]$ValueName,[RegistryDataType]$ValueType, [object]$Data, [string]$PSComputerName) {
        $this.Path       = $Path
        $this.ValueName = $ValueName
        $this.Type      = $ValueType
        $this.Data      = $Data
        $this.PSComputerName = $PSComputerName
    }
    CIMRegistryValue ([string]$Path,[string]$ValueName,[RegistryDataType]$ValueType, [object]$Data, [string]$PSComputerName, [string]$Protocol, [string]$CimSessionId) {
        $this.Path       = $Path
        $this.ValueName = $ValueName
        $this.Type      = $ValueType
        $this.Data      = $Data
        $this.PSComputerName = $PSComputerName
        $this.Protocol       = $Protocol
        $this.CimSessionId     = $CimSessionId
    }
}


class CIMRegPathCompleter : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $Command,
        [string] $Parameter,
        [string] $WordToComplete,
        [CommandAst] $Ast,
        [IDictionary] $FakeBoundParameter
    ) {
        $Result = [List[CompletionResult]]::new(10)

        $RegPath = ($wordToComplete.Trim(' ',"'",'"') -replace '/','\')
        if (-not $RegPath) {$RegPath = '\'}

        $Parent = [io.path]::GetDirectoryName($RegPath)
        $Leaf   = [io.path]::GetFileName($RegPath)

        $NameList = (Get-ChildItem -Path ("Registry::"+ $Parent)).PSChildName

        foreach ($Name in $NameList) {
            if ($Name.StartsWith($Leaf, [System.StringComparison]::OrdinalIgnoreCase)) {
                $CompletionPath = if ($Parent) {"$Parent\$Name"} else {$Name}
                [CIMRegPathCompleter]::AddCompletionValue($Result,$CompletionPath, $Name, $Name)
            }
        }

        return $Result
    }

    static [void] AddCompletionValue([List[CompletionResult]] $Result, [string] $path, [string] $ListItem, [string] $ToolTip) {
        $CompletionText = If ($Path.Contains(' ')) {
            "'$Path'"
        } else {
            $Path
        }
        $result.Add([CompletionResult]::new($CompletionText, $ListItem, [CompletionResultType]::ParameterValue, $ToolTip))
    }
}


Class CimError {
# https://stackoverflow.com/questions/49204918/difference-between-throw-and-pscmdlet-throwterminatingerror
# [ErrorRecord], ErrorId: https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.errorcategory?view=pscore-6.2.0
# Exception .NET:         https://docs.microsoft.com/en-us/dotnet/api/system?view=netframework-4.8
    static [ErrorRecord] UnsupportedCimSessionValue ($ComputerName) {
        $Exception = [System.ArgumentException]::new("CimSession parameter value is not valid. '$ComputerName' is not a string or CimSession object.'")
        return [ErrorRecord]::new($Exception, "InvalidComputerName", [ErrorCategory]::InvalidArgument, $ComputerName)
    }

    static [ErrorRecord] EmptyCIMOutput ($ComputerName,$ProviderName) {
        $Exception = [System.InvalidOperationException]::new("$ProviderName method of StdRegProv WMI provider returned no data.")
        If (-not $ComputerName) {$ComputerName = '.'}
        return [ErrorRecord]::new($Exception, "InvalidOutputData", [ErrorCategory]::InvalidResult, "\\$ComputerName\ROOT\DEFAULT:StdRegProv")
    }

    static [ErrorRecord] SubkeysExist ($SubKeyCount, $targetObject) {
        $Exception = [System.InvalidOperationException]::new("Registry key cannot be deleted because it has $SubKeyCount subkey(s).")
        return [ErrorRecord]::new($Exception, "InvalidOutputData", [ErrorCategory]::NotEnabled, $targetObject)
    }

    static [ErrorRecord] GetWin32ErrorDescription ($Win32Error, $targetObject) {

        $ErrorMessage = If ($Win32Error -eq 1) {
            "Registry value does not exist."
        } ElseIf ($Win32Error -eq 2) {
            "Registry key does not exist."
        } ElseIf ($Win32Error -eq 2147749893) {
            "Type mismatch occurred."
        } Else {
            ([System.ComponentModel.Win32Exception]::new([int32]$Win32Error)).Message
        }

        $Exception = [System.ArgumentException]::new($ErrorMessage)
        return [ErrorRecord]::new($Exception, "StdRegProvError", [ErrorCategory]::OperationStopped, $targetObject)
    }

    static [ErrorRecord] AccessDeniedVerbose ($AccessPermission, $targetObject) {

        $ErrorMessage = "Access is denied. You have no '$([RegistryAccess]$AccessPermission)' permission."

        $Exception = [System.ArgumentException]::new($ErrorMessage)
        return [ErrorRecord]::new($Exception, "StdRegProvError", [ErrorCategory]::OperationStopped, $targetObject)
    }

}


Enum RegistryDataType {
    REG_SZ        = 1
    REG_EXPAND_SZ = 2
    REG_BINARY    = 3
    REG_DWORD     = 4
    REG_MULTI_SZ  = 7
    REG_QWORD     = 11
}

[Flags()]
enum RegistryAccess {
    KEY_QUERY_VALUE        = 1
    KEY_SET_VALUE          = 2
    KEY_CREATE_SUB_KEY     = 4
    KEY_ENUMERATE_SUB_KEYS = 8
    KEY_NOTIFY             = 16
    KEY_CREATE             = 32
    DELETE                 = 65536
    READ_CONTROL           = 131072
    WRITE_DAC              = 262144
    WRITE_OWNER            = 524288
}


### Drafts
<#
Class HexToDec {
    [System.UInt32]$Decimal

    HexToDec ([string]$Hex) {
        $this.Decimal = [System.Convert]::ToUInt32($Hex,16)
    }
}

Enum CIMRootKey {
    HKEY_CLASSES_ROOT     = '80000000'
    HKEY_CURRENT_USER     = '80000001'
    HKEY_LOCAL_MACHINE    = '80000002'
    HKEY_USERS            = '80000003'
    HKEY_PERFORMANCE_DATA = '80000004'
    HKEY_CURRENT_CONFIG   = '80000005'
    HKEY_DYN_DATA         = '80000006'
}
#>
