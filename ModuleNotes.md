### Main idea
The module was created to make remote access to Windows registry more convenient. Especially for people who do it occasionally. So, I decided to make some simplifications:
* Registry path format looks like:  **HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft**. It's not in compliance with the native PowerShell registry path format (**HKLM:\SOFTWARE\Microsoft**) and looks longer. But you can easily copy/paste such a path from/to the Windows Registry editor. 
* The Path parameter of each function supports autocompletion. Please, be aware that the autocompletion uses only the local Windows registry, not a remote one.

### Restrictions
The module's functions use the WMI registry provider (StdRegProv) to access a Windows registry. There are some restrictions due to the nature of StdRegProv:
* StdRegProv automatically expands enironment variables.  
For instance, '**ProgramFilesPath**' registry value is located in '**HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion**' and contains '__%ProgramFiles%__'. When you read it, it will be replaced by 'C:\Program Files'. There is no way to get a real data using WMI.
* You cannot rename a registry key. You have to delete it and create a new one.
* You cannot remove a registry key if it has any subkeys. You have to delete all its subkeys at first.

Please, in such cases use native PowerShell features, like HKLM:\ PSDrive.


### Network connections
