## Main idea
The module was created to make remote access to Windows registry more convenient. Especially for people who do it occasionally. So, I decided to make some simplifications:
* Registry path format looks like:  **HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft**. It's not in compliance with the native PowerShell registry path format (**HKLM:\SOFTWARE\Microsoft**) and looks longer. But you can easily copy/paste such a path from/to the Windows Registry editor. 
* The Path parameter of each function supports autocompletion. Please, be aware that the autocompletion uses only the local Windows registry, not a remote one.

## Restrictions
The module's functions use the WMI registry provider (StdRegProv) to access a Windows registry. There are some restrictions due to the nature of StdRegProv:
* StdRegProv automatically expands enironment variables.  
For instance,  registry value '**ProgramFilesPath**' (type REG_EXPAND_SZ) is located in  '**HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion**' key and contains '__%ProgramFiles%__' string. When you read it, it will be replaced by '**C:\Program Files**'. There is no way to get a real data from such values using WMI. 
* You cannot rename a registry key. You have to delete it and create a new one.
* You cannot remove a registry key if it has any subkeys. You have to delete all its subkeys at first.

Please, in such cases use native PowerShell features, like HKLM:\ PSDrive.


## Network connections
The module functions create two types of objects: RegistryKey and RegistryValue. Each object has full network information about its origin. For instance: 
- PSComputerName : DC01
- Protocol       : WSMAN
- CimSessionId   : 1529d220-170f-4023-9449-a983feae433c

PSComputerName and Protocol work together to create a temporary CimSession.

CimSessionId keeps information about pre-created CimSession.

Several examples:
### Temporary CimSessions

**PS C:\> Get-RegistrySubkey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE' -ComputerName DC01 | Get-RegistryKey**
1. Get-RegistryKey will: 
   - create a temporary CimSession and read subkeys,
   - send a RegistryKey objects to the pipeline, 
   - close the temporary CimSession
2. Get-RegistryKey will: 
   - read with PSComputerName and Protocol information form  each input object,
   - open a temporary CimSession for each subkey and read additional info about subkeys,
   - close each temporary CimSession

### Pre-created CimSession

**PS C:\> $CimSess = New-CimSession -ComputerName DC01**

**PS C:\> Get-RegistrySubkey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE' -CimSession $CimSess | Get-RegistryKey**

You create a CimSession object and then run the second command.
1. Get-RegistrySubkey command will:
   - read subkeys using existing CimSession,
   - create RegistryKey objects. Each has the CimSession ID on it.
   - send RegistryKey objects to the pipeline.
2. Get-RegistryKey command will:
   - read CimSession ID from each input object,
   - get information on each subkey using existing CimSession

It works much faster and consume much less resources.

**Note**: If a pre-created session doesn’t exist anymore, the functions will open a temporary CimSession using PSComputerName and Protocol properties of an input object. 

### Overwriting the network information from an object.
You can always overwrite a network information:

**PS C:\> Get-RegistrySubkey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE' -ComputerName DC01 | Get-RegistryKey -CimSession $CimSess**

or

**PS C:\> Get-RegistrySubkey -Path 'HKEY_LOCAL_MACHINE\SOFTWARE' -CimSession $CimSess | Get-RegistryKey -ComputerName WKS003 -Protocol Dcom**

In both cases the second command on the pipeline will ignore the network information from an input object and use whatever you pass to the parameters.
