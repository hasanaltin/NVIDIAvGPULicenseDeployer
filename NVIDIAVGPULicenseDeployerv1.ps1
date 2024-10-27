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

# Path to PsExec executable
$PsExecPath = "C:\Windows\System32\PsExec.exe"
# Define fixed paths for successful and failed log files
$SuccessLogFile = "C:\ITLogs\SuccessLog.log"
$FailureLogFile = "C:\ITLogs\FailureLog.log"

# Function to log actions to different files based on success or failure
function Write-Log {
    param (
        [string]$Message,
        [string]$Type # "Success" or "Failure"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    if ($Type -eq "Success") {
        Add-Content -Path $SuccessLogFile -Value $LogEntry
    } elseif ($Type -eq "Failure") {
        Add-Content -Path $FailureLogFile -Value $LogEntry
    }
}

# Function to delete .tok files in the ClientConfigToken folder and then copy new files
function ClearAndCopy-Files {
    $SourceFolder = "C:\IT"
    $Computers = Get-ADComputer -Filter 'Name -like "VDI*"' | Select-Object -ExpandProperty Name
    
    foreach ($Computer in $Computers) {
        $DestinationTokenFolder = "\\$Computer\C$\Program Files\NVIDIA Corporation\vGPU Licensing\ClientConfigToken"
        $DestinationITFolder = "\\$Computer\C$\IT"

        # Check if the destination computer is reachable
        if (!(Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
            Write-Log "Computer $Computer is not reachable. Skipping." "Failure"
            Write-Host "Computer $Computer is not reachable. Skipping."
            continue
        }

        # Remove all .tok files inside the ClientConfigToken folder on the destination computer but keep the folder itself
        if (Test-Path $DestinationTokenFolder) {
            Get-ChildItem -Path $DestinationTokenFolder -Filter "*.tok" -Recurse | Remove-Item -Force
            Write-Log "Cleared existing .tok files in ClientConfigToken folder on $Computer" "Success"
        } else {
            try {
                # If the ClientConfigToken folder doesn't exist, create it
                New-Item -Path $DestinationTokenFolder -ItemType Directory -Force
                Write-Log "Created ClientConfigToken folder on $Computer" "Success"
            } catch {
                Write-Log "Failed to create ClientConfigToken folder on $Computer. Error: $_.Exception.Message" "Failure"
                Write-Host "Failed to create ClientConfigToken folder on $Computer. Skipping."
                continue
            }
        }

        # Copy only .tok files from source to ClientConfigToken folder on the destination
        Copy-Item -Path "$SourceFolder\*.tok" -Destination $DestinationTokenFolder -Recurse -Force
        Write-Log ".tok files copied to ClientConfigToken folder on $Computer" "Success"

        # Ensure the IT folder exists and copy .ps1 files
        if (-not (Test-Path $DestinationITFolder)) {
            try {
                New-Item -Path $DestinationITFolder -ItemType Directory -Force
                Write-Log "Created IT folder on $Computer" "Success"
            } catch {
                Write-Log "Failed to create IT folder on $Computer. Error: $_.Exception.Message" "Failure"
                Write-Host "Failed to create IT folder on $Computer. Skipping."
                continue
            }
        }

        # Copy only .ps1 files from source to IT folder on the destination
        Copy-Item -Path "$SourceFolder\*.ps1" -Destination $DestinationITFolder -Recurse -Force
        Write-Log ".ps1 files copied to IT folder on $Computer" "Success"
    }
}

# Function to restart a service using PsExec, with error handling for stopping and starting
function Restart-ServiceOnComputers {
    $ServiceName = "NVDisplay.ContainerLocalSystem"
    $Computers = Get-ADComputer -Filter 'Name -like "VDI*"' | Select-Object -ExpandProperty Name
    
    foreach ($Computer in $Computers) {
        try {
            # Attempt to stop the service
            $stopProcess = Start-Process -FilePath $PsExecPath -ArgumentList "\\$Computer -s -d sc stop $ServiceName" -NoNewWindow -PassThru -Wait
            Start-Sleep -Seconds 5  # Short delay to allow process to complete
            if ($stopProcess.ExitCode -eq 0) {
                Write-Host "Service '$ServiceName' stopped on $Computer"
                Write-Log "Service '$ServiceName' stopped on $Computer" "Success"
            } else {
                Write-Host "Service '$ServiceName' may already be stopped on $Computer. Proceeding to start it."
                Write-Log "Service '$ServiceName' may already be stopped on $Computer. Proceeding to start it." "Success"
            }
        }
        catch {
            Write-Host "Service '$ServiceName' may already be stopped on $Computer. Proceeding to start it."
            Write-Log "Service '$ServiceName' may already be stopped on $Computer. Proceeding to start it." "Failure"
        }

        # Now, attempt to start the service
        try {
            $startProcess = Start-Process -FilePath $PsExecPath -ArgumentList "\\$Computer -s -d sc start $ServiceName" -NoNewWindow -PassThru -Wait
            Start-Sleep -Seconds 5  # Short delay to allow process to complete
            if ($startProcess.ExitCode -eq 0) {
                Write-Host "Service '$ServiceName' started on $Computer"
                Write-Log "Service '$ServiceName' started on $Computer" "Success"
            } else {
                Write-Host "Failed to start service on $Computer (Exit Code: $($startProcess.ExitCode))"
                Write-Log "Failed to start service on $Computer (Exit Code: $($startProcess.ExitCode))" "Failure"
            }
        }
        catch {
            Write-Host "Failed to start service on $Computer - Error: $_.Exception.Message"
            Write-Log "Failed to start service on $Computer - Error: $_.Exception.Message" "Failure"
        }
    }
}

# Function to run DisableDisplayAdapters.ps1 on remote computers
function Run-DisableDisplayAdapters {
    $Computers = Get-ADComputer -Filter 'Name -like "VDI*"' | Select-Object -ExpandProperty Name
    
    foreach ($Computer in $Computers) {
        try {
            $psexecCommand = Start-Process -FilePath $PsExecPath -ArgumentList "\\$Computer -s powershell.exe -ExecutionPolicy Bypass -File C:\IT\DisableDisplayAdapters.ps1" -NoNewWindow -PassThru -Wait
            if ($psexecCommand.ExitCode -eq 0) {
                Write-Host "DisableDisplayAdapters.ps1 ran successfully on $Computer"
                Write-Log "DisableDisplayAdapters.ps1 ran successfully on $Computer" "Success"
            } else {
                Write-Host "Failed to run DisableDisplayAdapters.ps1 on $Computer (Exit Code: $($psexecCommand.ExitCode))"
                Write-Log "Failed to run DisableDisplayAdapters.ps1 on $Computer (Exit Code: $($psexecCommand.ExitCode))" "Failure"
            }
        } catch {
            Write-Host "Error running DisableDisplayAdapters.ps1 on $Computer - $_.Exception.Message"
            Write-Log "Error running DisableDisplayAdapters.ps1 on $Computer - $_.Exception.Message" "Failure"
        }
    }
}

# Function to ensure the log directory exists
function Ensure-LogDirectory {
    $LogDirectory = "C:\ITLogs"
    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory
    }
}

# Main menu function
function Show-Menu {
    Write-Host "1: Copy ClientConfigToken to Computers"
    Write-Host "2: Restart NVDisplay Service on Computers"
    Write-Host "3: Disable Display Adapters on Computers"
    Write-Host "0: Exit"
}

# Script execution
Ensure-LogDirectory  # Ensure the log directory exists
do {
    Show-Menu
    $Choice = Read-Host "Enter your choice (1, 2, 3, or 0 to exit)"
    
    switch ($Choice) {
        1 { ClearAndCopy-Files }
        2 { Restart-ServiceOnComputers }
        3 { Run-DisableDisplayAdapters }
        0 { Write-Host "Exiting..."; break }
        default { Write-Host "Invalid selection, please choose again." }
    }
} while ($Choice -ne 0)
