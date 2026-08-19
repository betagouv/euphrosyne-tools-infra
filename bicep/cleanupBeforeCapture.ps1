param(
    [string]$DriveLetter = "Z:",
    [string]$TaskName = "EuphrosyneMountDrive"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-DriveLetter {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    $normalized = $Value.Trim().TrimEnd("\")
    if (-not $normalized.EndsWith(":")) {
        $normalized = "${normalized}:"
    }

    if ($normalized -notmatch "^[A-Za-z]:$") {
        throw "DriveLetter must be a single drive letter, for example Z:."
    }

    return $normalized.ToUpperInvariant()
}

function Get-CmdKeyTargetName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetLine
    )

    $target = $TargetLine.Trim()
    if ($target -match "^Target:\s*(.+)$") {
        $target = $Matches[1].Trim()
    }

    if ($target -match "(?i)target=(.+)$") {
        $target = $Matches[1].Trim()
    }

    return $target.Trim('"')
}

$normalizedDriveLetter = Normalize-DriveLetter -Value $DriveLetter
$driveName = $normalizedDriveLetter.TrimEnd(":")
$installDirectory = Join-Path $env:ProgramData "Euphrosyne"
$mountScriptPath = Join-Path $installDirectory "MountDriveAtLogon.ps1"

Write-Host "Starting Euphrosyne pre-capture cleanup."
Write-Host "Configured drive letter: $normalizedDriveLetter"
Write-Host "Configured scheduled task: $TaskName"

Write-Host "Removing mapped drive $normalizedDriveLetter if present."
& net.exe use $normalizedDriveLetter /delete /y | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Removed mapped drive $normalizedDriveLetter."
} else {
    Write-Host "No removable net use mapping found for $normalizedDriveLetter, or it was already absent."
}

Write-Host "Removing PSDrive $driveName if present."
$existingDrive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
if ($existingDrive) {
    Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
    Write-Host "Removed PSDrive $driveName."
} else {
    Write-Host "PSDrive $driveName was not present."
}

Write-Host "Unregistering scheduled task $TaskName if present."
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Unregistered scheduled task $TaskName."
} else {
    Write-Host "Scheduled task $TaskName was not present."
}

Write-Host "Deleting generated mount script $mountScriptPath if present."
if (Test-Path -LiteralPath $mountScriptPath) {
    Remove-Item -LiteralPath $mountScriptPath -Force
    Write-Host "Deleted generated mount script."
} else {
    Write-Host "Generated mount script was not present."
}

Write-Host "Removing Azure Files credentials from Credential Manager."
$cmdkeyOutput = & cmdkey.exe /list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "cmdkey /list failed with exit code $LASTEXITCODE. Credential cleanup could not be verified."
} else {
    $azureFilesCredentialTargets = @()
    foreach ($line in $cmdkeyOutput) {
        if ($line -match "^\s*Target:\s*") {
            $targetName = Get-CmdKeyTargetName -TargetLine $line
            if ($targetName -match "(?i)\.file\.core\.windows\.net$") {
                $azureFilesCredentialTargets += $targetName
            }
        }
    }

    $azureFilesCredentialTargets = @($azureFilesCredentialTargets | Sort-Object -Unique)
    if ($azureFilesCredentialTargets.Count -eq 0) {
        Write-Host "No Azure Files credentials ending in .file.core.windows.net were found."
    } else {
        foreach ($targetName in $azureFilesCredentialTargets) {
            Write-Host "Deleting Azure Files credential target $targetName."
            & cmdkey.exe "/delete:$targetName" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to delete credential target $targetName. cmdkey exited with $LASTEXITCODE."
            }
        }
    }
}

Write-Host "Removing $installDirectory if empty."
if (Test-Path -LiteralPath $installDirectory) {
    $remainingItems = @(Get-ChildItem -LiteralPath $installDirectory -Force -ErrorAction SilentlyContinue)
    if ($remainingItems.Count -eq 0) {
        Remove-Item -LiteralPath $installDirectory -Force
        Write-Host "Removed empty directory $installDirectory."
    } else {
        Write-Host "Directory $installDirectory is not empty; leaving it in place."
    }
} else {
    Write-Host "Directory $installDirectory was not present."
}

if (Test-Path -LiteralPath $mountScriptPath) {
    throw "Generated mount script still exists after cleanup: $mountScriptPath"
}

Write-Host "Euphrosyne pre-capture cleanup completed."
