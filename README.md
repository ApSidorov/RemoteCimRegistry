# RemoteCimRegistry

The module contains functions to manage Windows Registry locally and remotely. You can read, write and delete registry keys/values.

To access a registry the functions use:
* WMI registry provider (StdRegProv)
* WSMAN and DCOM protocols

Pipeline support lets you 'copy' registry settings from one computer to another. 


### Prerequisites

* PowerShell version : 5.0 and later.
* Operating system   : Microsoft Windows.


### Installing

Copy the module folder to your module path. PowerShell will take care of the rest.

### Do not forget
# Registry Caution 
Do not use a registry editor to edit the registry directly unless you have no alternative. The registry editors bypass the standard safeguards provided by administrative tools. These safeguards prevent you from entering conflicting settings or settings that are likely to degrade performance or damage your system. Editing the registry directly can have serious, unexpected consequences that can prevent the system from starting and require that you reinstall Windows 2000[/XP/Vista]. To configure or customize Windows 2000[/XP/Vista], use the programs in Microsoft Management Console or Control Panel whenever possible. 

Windows 2000 Resource Kit Registry Disclaimer Page
