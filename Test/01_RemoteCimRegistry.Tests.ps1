# This is a Pester test file
### CIMRegistry module Main test
using module "..\RemoteCimRegistry.psd1"

$ModuleManifestName = 'RemoteCimRegistry.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
        $? | Should Be $true
    }
}

InModuleScope 'RemoteCimRegistry' {
    Describe CIMRegistry {

        #region General Mocks (used in all other tests)

        ## Do not mock New-CimSessionOption, let it return a real object (since it's a native part of Windows PowerShell)

        $RemoteCompName = 'SRV011'
        # 1) Mock New-CimSession
         Mock New-CimSession {
             # Parameters $ComputerName and $SessionOption inherited from the mocked Cmdlet
             $MProtocol = Switch (($SessionOption).GetType().Name) {
                 'DComSessionOptions' {'DCOM'}
                 'WSManSessionOptions' {'WSMAN'}
             }
             $MockCimSess = [Microsoft.Management.Infrastructure.CimSession]::Create($ComputerName)
             $MockCimSess | Add-Member -NotePropertyName Id -NotePropertyValue 1
             # $MockCimSess | Add-Member -NotePropertyName Name -NotePropertyValue $Name
             $MockCimSess | Add-Member -NotePropertyName Protocol -NotePropertyValue $MProtocol -PassThru
         }

        # 2) Mock Get-CimSession (for simulation of pre-existing session)
            # Create pre-existing CimSession object to return.
            $ExistingCimSession = New-CimSession -ComputerName 'RComputer' -SessionOption (New-CimSessionOption -Protocol Wsman) # Using a Mock above. New-CimSessionOption - using real
            Mock Get-CimSession { $ExistingCimSession } { ($PSBoundParameters.InstanceId -eq ($ExistingCimSession.InstanceId)) }

        # 3) Mock Remove-CimSession
            Mock Remove-CimSession {}
            # Mock Remove-CimSession {if ($CimSession) {$CimSession = $null} Else {Throw}}

        # 4) Stub all CDXML function calls to allow only explicitly mocked access.
            Mock Get-cdxmlSubkeyName { [PSCustomObject]@{ReturnValue = 2; sNames = $null} }
            Mock Get-cdxmlValueName  { [PSCustomObject]@{ReturnValue = 2; sNames = $null; Types =  $null} }

            # Mock Get-cdxmlStringValue         { [PSCustomObject]@{ReturnValue = 1; sValue = $null} }
            Mock Get-cdxmlExpandedStringValue { [PSCustomObject]@{ReturnValue = 1; sValue = $null} }
            Mock Get-cdxmlBinaryValue         { [PSCustomObject]@{ReturnValue = 1; uValue = $null} }
            Mock Get-cdxmlDWORDValue          { [PSCustomObject]@{ReturnValue = 1; uValue = $null} }
            Mock Get-cdxmlMultiStringValue    { [PSCustomObject]@{ReturnValue = 1; sValue = $null} }
            Mock Get-cdxmlQWORDValue          { [PSCustomObject]@{ReturnValue = 1; uValue = $null} }

            Mock Test-cdxmlRegistryKeyAccess  { [PSCustomObject]@{ReturnValue = 15034; bGranted = $false} }

            Mock New-cdxmlRegistryKey { [PSCustomObject]@{ReturnValue = 15034} } # Especially to prevent creating a real registry keys.

            Mock Remove-cdxmlRegistryKey   { [PSCustomObject]@{ReturnValue = 15034} }
            Mock Remove-cdxmlRegistryValue { [PSCustomObject]@{ReturnValue = 15034} }

            Mock Set-cdxmlStringValue         { [PSCustomObject]@{ReturnValue = 15034} }
            Mock Set-cdxmlExpandedStringValue { [PSCustomObject]@{ReturnValue = 15034} }
            Mock Set-cdxmlBinaryValue         { [PSCustomObject]@{ReturnValue = 15034} }
            Mock Set-cdxmlDWORDValue          { [PSCustomObject]@{ReturnValue = 15034} }
            Mock Set-cdxmlMultiStringValue    { [PSCustomObject]@{ReturnValue = 15034} }
            Mock Set-cdxmlQWORDValue          { [PSCustomObject]@{ReturnValue = 15034} }


        # 5) Common errors messages
            $ValueNotFoundError = [CimError]::GetWin32ErrorDescription(1,'Test').Exception.Message
            $PathNotFoundError = [CimError]::GetWin32ErrorDescription(2,'Test').Exception.Message
            $AccessDeniedError = [CimError]::GetWin32ErrorDescription(5,'Test').Exception.Message

        #endregion

        ## Test Helping functions (uses only its own Mocks)
        & $PSScriptRoot\02_CIMRegistry_Helping_Functions.ps1

        ## Test Get-* functions
        & $PSScriptRoot\03_CIMRegistry_Get_Functions.ps1

        ## Test New/Set-* functions
        & $PSScriptRoot\04_CIMRegistry_New_Set_Functions.ps1

        ## Test Remove-* functions
        & $PSScriptRoot\05_CIMRegistry_Remove_Functions.ps1
    }
}
