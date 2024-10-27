<#
.SYNOPSIS
    PowerShell script to remotely manage files and services on computers within Active Directory.

.DESCRIPTION
    Author: HASAN ALTIN
    Website: hasanaltin.com
    This script performs three main functions:
    1. Clears .tok files inside the "C:\Program Files\NVIDIA Corporation\vGPU Licensing\ClientConfigToken" folder
       on each computer with names starting with "VDI" and copies .tok files from a local "C:\IT" folder to this location.
       Additionally, if there are .ps1 files in "C:\IT" on the source computer, they are copied to "C:\IT" on the destination
       computers, creating the folder if it does not exist.
    2. Uses PsExec to restart the "NVDisplay.ContainerLocalSystem" service on each target computer. If the service 
       is already stopped, it proceeds to start it.
    3. Executes the `DisableDisplayAdapters.ps1` script remotely on each computer using PsExec.
    All actions are logged for tracking and troubleshooting purposes.

#>

 # Define the device names to check and disable
$DeviceNames = @("VMware SVGA 3D", "Microsoft Basic Display Adapter")

# Import the necessary module
Import-Module PnpDevice

# Get the list of display adapters
$displayAdapters = Get-PnpDevice -Class Display

# Check each adapter to see if it matches the target device names
foreach ($adapter in $displayAdapters) {
    if ($DeviceNames -contains $adapter.FriendlyName) {
        Write-Output "Disabling device: $($adapter.FriendlyName)"
        Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false
    }
}

Write-Output "Device check and disable operation completed on computer: $env:COMPUTERNAME."
