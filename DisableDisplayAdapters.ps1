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
