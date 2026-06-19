param(
    [Parameter(Mandatory=$true)]
    [string]$FileShare,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountAccessKey,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccount,

    [Parameter(Mandatory=$true)]
    [string]$FileShareProjectFolder,

    [Parameter(Mandatory=$true)]
    [string]$AccountName,

    [Parameter(Mandatory=$true)]
    [string]$AccountPassword,

    [string]$DriveLetter = "Z:"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-PowerShellSingleQuotedString {
    param(
        [AllowNull()]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "''") + "'"
}

$normalizedDriveLetter = $DriveLetter.Trim()
if (-not $normalizedDriveLetter.EndsWith(":")) {
    $normalizedDriveLetter = "${normalizedDriveLetter}:"
}

$driveName = $normalizedDriveLetter.TrimEnd(":")
if ($driveName.Length -ne 1) {
    throw "DriveLetter must be a single drive letter, for example Z:."
}

$installDirectory = Join-Path $env:ProgramData "Euphrosyne"
$mountScriptPath = Join-Path $installDirectory "MountDriveAtLogon.ps1"
$taskName = "EuphrosyneMountDrive"
$interactiveUsersGroupSid = "S-1-5-32-545"
$storageEndpoint = "${StorageAccount}.file.core.windows.net"
$sharePath = "\\${storageEndpoint}\${FileShare}\projects\${FileShareProjectFolder}"

New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null

$driveLetterLiteral = ConvertTo-PowerShellSingleQuotedString $normalizedDriveLetter
$storageEndpointLiteral = ConvertTo-PowerShellSingleQuotedString $storageEndpoint
$storageAccountLiteral = ConvertTo-PowerShellSingleQuotedString $StorageAccount
$storageAccountAccessKeyLiteral = ConvertTo-PowerShellSingleQuotedString $StorageAccountAccessKey
$sharePathLiteral = ConvertTo-PowerShellSingleQuotedString $sharePath

$mountScript = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

`$driveLetter = ${driveLetterLiteral}
`$driveName = `$driveLetter.TrimEnd(":")
`$storageEndpoint = ${storageEndpointLiteral}
`$storageAccount = ${storageAccountLiteral}
`$storageAccountAccessKey = ${storageAccountAccessKeyLiteral}
`$sharePath = ${sharePathLiteral}
`$driveRoot = `$driveLetter + "\"

Write-Host "Removing existing mapping on `$driveLetter if present."
& net.exe use `$driveLetter /delete /y | Out-Null

`$existingDrive = Get-PSDrive -Name `$driveName -ErrorAction SilentlyContinue
if (`$existingDrive) {
    Remove-PSDrive -Name `$driveName -Force -ErrorAction SilentlyContinue
}

Write-Host "Saving Azure Files credentials for `$storageEndpoint."
& cmdkey.exe "/add:`$storageEndpoint" "/user:localhost\`$storageAccount" "/pass:`$storageAccountAccessKey"
if (`$LASTEXITCODE -ne 0) {
    throw "cmdkey failed with exit code `${LASTEXITCODE}."
}

Write-Host "Mapping `$driveLetter to `$sharePath."
& net.exe use `$driveLetter `$sharePath /persistent:yes
if (`$LASTEXITCODE -ne 0) {
    throw "net use failed with exit code `${LASTEXITCODE}."
}

Write-Host "Warming up `$driveRoot so Explorer does not show a stale disconnected state."
`$warmupSucceeded = `$false
for (`$attempt = 1; `$attempt -le 5; `$attempt++) {
    if (Test-Path -LiteralPath `$driveRoot -ErrorAction SilentlyContinue) {
        Get-ChildItem -LiteralPath `$driveRoot -Force -ErrorAction SilentlyContinue |
            Select-Object -First 1 |
            Out-Null
        `$warmupSucceeded = `$true
        break
    }

    Start-Sleep -Seconds 2
}

if (-not `$warmupSucceeded) {
    Write-Warning "Mapped drive `$driveRoot was not reachable during warm-up. It should still reconnect on first access."
}
"@

Set-Content -Path $mountScriptPath -Value $mountScript -Encoding UTF8 -Force

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$mountScriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal `
    -GroupId $interactiveUsersGroupSid `
    -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Mount the Euphrosyne Azure Files project share at user logon." `
    -Force | Out-Null

Write-Host "Registered scheduled task $taskName for interactive users."

try {
    & $mountScriptPath
} catch {
    Write-Warning "Best-effort provisioning mount failed. The logon task will retry in the user session. $($_.Exception.Message)"
}
