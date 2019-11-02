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

### Please, do not forget Microsoft Registry caution:
Do not edit the registry directly unless you have no alternative. The registry editor bypasses standard safeguards, allowing settings that can degrade performance, damage your system, or even require you to reinstall Windows. You can safely alter most registry settings by using the programs in Control Panel or Microsoft Management Console (MMC). If you must edit the registry directly, back it up first.

### Acknowlegementes
**Richard Siddaway** - for the main idea of a Windows registry CDXML module (Dr Scripto devblog).

**Staffan Gustafsson** - for priceless lessons on developing PowerShell modules (PSCONF.EU 2017).

**Adam Bertram** - for *The Pester Book* and his video cource *Testing PowerShell with Pester* on MVA. No big project can be done without proper testing. 
