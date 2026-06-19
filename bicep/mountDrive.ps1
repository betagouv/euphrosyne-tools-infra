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

function Get-LocalGroupByWellKnownSid {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Sid
    )

    $securityIdentifier = New-Object System.Security.Principal.SecurityIdentifier($Sid)
    return Get-LocalGroup -SID $securityIdentifier
}

function Test-LocalGroupMemberSid {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Group,

        [Parameter(Mandatory=$true)]
        [System.Security.Principal.SecurityIdentifier]$MemberSid
    )

    $members = @(Get-LocalGroupMember -Group $Group.Name -ErrorAction Stop)
    foreach ($member in $members) {
        if ($member.SID -and $member.SID.Value -eq $MemberSid.Value) {
            return $true
        }
    }

    return $false
}

function Add-LocalGroupMemberIfMissing {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Group,

        [Parameter(Mandatory=$true)]
        [System.Security.Principal.SecurityIdentifier]$MemberSid,

        [Parameter(Mandatory=$true)]
        [string]$FallbackMemberName
    )

    if (Test-LocalGroupMemberSid -Group $Group -MemberSid $MemberSid) {
        return
    }

    try {
        Add-LocalGroupMember -Group $Group.Name -Member $MemberSid.Value -ErrorAction Stop
    } catch {
        Add-LocalGroupMember -Group $Group.Name -Member $FallbackMemberName -ErrorAction Stop
    }
}

function Remove-LocalGroupMemberIfPresent {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Group,

        [Parameter(Mandatory=$true)]
        [System.Security.Principal.SecurityIdentifier]$MemberSid,

        [Parameter(Mandatory=$true)]
        [string]$FallbackMemberName
    )

    if (-not (Test-LocalGroupMemberSid -Group $Group -MemberSid $MemberSid)) {
        return
    }

    try {
        Remove-LocalGroupMember -Group $Group.Name -Member $MemberSid.Value -ErrorAction Stop
    } catch {
        Remove-LocalGroupMember -Group $Group.Name -Member $FallbackMemberName -ErrorAction Stop
    }
}

function Grant-PathAcl {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string[]]$Grants
    )

    $icaclsOutput = & icacls.exe $Path /inheritance:r /grant:r $Grants 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "icacls failed for $Path with exit code $LASTEXITCODE. $($icaclsOutput -join ' ')"
    }
}

$normalizedDriveLetter = Normalize-DriveLetter -Value $DriveLetter
$driveName = $normalizedDriveLetter.TrimEnd(":")
$installDirectory = Join-Path $env:ProgramData "Euphrosyne"
$logDirectory = Join-Path $installDirectory "Logs"
$logPath = Join-Path $logDirectory "MountDriveAtLogon.log"
$mountScriptPath = Join-Path $installDirectory "MountDriveAtLogon.ps1"
$taskName = "EuphrosyneMountDrive"
$administratorsGroupSid = "S-1-5-32-544"
$usersGroupSid = "S-1-5-32-545"
$remoteDesktopUsersGroupSid = "S-1-5-32-555"
$localSystemSid = "S-1-5-18"
$storageEndpoint = "${StorageAccount}.file.core.windows.net"
$sharePath = "\\${storageEndpoint}\${FileShare}\projects\${FileShareProjectFolder}"
$taskUser = "$env:COMPUTERNAME\$AccountName"

$securePassword = ConvertTo-SecureString -String $AccountPassword -AsPlainText -Force
$existingUser = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
if ($existingUser) {
    Set-LocalUser -Name $AccountName -Password $securePassword -AccountNeverExpires
    Enable-LocalUser -Name $AccountName
    Write-Host "Updated and enabled local interactive account $AccountName."
} else {
    New-LocalUser `
        -Name $AccountName `
        -Password $securePassword `
        -AccountNeverExpires `
        -Description "Euphrosyne interactive desktop account." |
        Out-Null
    Write-Host "Created local interactive account $AccountName."
}

$interactiveUser = Get-LocalUser -Name $AccountName
$interactiveUserSid = $interactiveUser.SID

$administratorsGroup = Get-LocalGroupByWellKnownSid -Sid $administratorsGroupSid
$usersGroup = Get-LocalGroupByWellKnownSid -Sid $usersGroupSid
$remoteDesktopUsersGroup = Get-LocalGroupByWellKnownSid -Sid $remoteDesktopUsersGroupSid

Add-LocalGroupMemberIfMissing `
    -Group $usersGroup `
    -MemberSid $interactiveUserSid `
    -FallbackMemberName $taskUser
Add-LocalGroupMemberIfMissing `
    -Group $remoteDesktopUsersGroup `
    -MemberSid $interactiveUserSid `
    -FallbackMemberName $taskUser
Remove-LocalGroupMemberIfPresent `
    -Group $administratorsGroup `
    -MemberSid $interactiveUserSid `
    -FallbackMemberName $taskUser

Write-Host "Ensured $AccountName is a standard Remote Desktop user."

New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

$driveLetterLiteral = ConvertTo-PowerShellSingleQuotedString $normalizedDriveLetter
$storageEndpointLiteral = ConvertTo-PowerShellSingleQuotedString $storageEndpoint
$storageAccountLiteral = ConvertTo-PowerShellSingleQuotedString $StorageAccount
$storageAccountAccessKeyLiteral = ConvertTo-PowerShellSingleQuotedString $StorageAccountAccessKey
$sharePathLiteral = ConvertTo-PowerShellSingleQuotedString $sharePath
$logPathLiteral = ConvertTo-PowerShellSingleQuotedString $logPath

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
`$logPath = ${logPathLiteral}

function Write-Log {
    param(
        [Parameter(Mandatory=`$true)]
        [string]`$Message,

        [string]`$Level = "INFO"
    )

    `$timestamp = Get-Date -Format "o"
    Add-Content -LiteralPath `$logPath -Value "`$timestamp [`$Level] `$Message"
}

function Test-IsElevated {
    `$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    `$principal = New-Object System.Security.Principal.WindowsPrincipal(`$identity)
    return `$principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory=`$true)]
        [scriptblock]`$Command
    )

    `$previousErrorActionPreference = `$ErrorActionPreference
    `$ErrorActionPreference = "Continue"
    try {
        `$output = & `$Command 2>&1
        `$exitCode = `$LASTEXITCODE
    } finally {
        `$ErrorActionPreference = `$previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = `$exitCode
        Output = @(`$output)
    }
}

try {
    Write-Log "Starting Euphrosyne mount task."
    Write-Log "Identity: `$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Log "Elevated: `$(Test-IsElevated)"
    Write-Log "Drive letter: `$driveLetter"
    Write-Log "Storage endpoint: `$storageEndpoint"
    Write-Log "Share path: `$sharePath"

    Start-Sleep -Seconds 5

    Write-Log "Removing existing net use mapping on `$driveLetter if present."
    `$deleteResult = Invoke-NativeCommand -Command { & net.exe use `$driveLetter /delete /y }
    Write-Log "net use delete exit code: `$(`$deleteResult.ExitCode)"
    if (`$deleteResult.ExitCode -ne 0) {
        Write-Log "No existing net use mapping was removed, or the mapping was already absent."
    }

    Write-Log "Removing existing SMB mapping on `$driveLetter if present."
    Get-SmbMapping -LocalPath `$driveLetter -ErrorAction SilentlyContinue |
        Remove-SmbMapping -Force -UpdateProfile -ErrorAction SilentlyContinue

    Write-Log "Removing remembered HKCU mapping for `$driveName if present."
    Remove-Item -LiteralPath "HKCU:\Network\`$driveName" -Recurse -Force -ErrorAction SilentlyContinue

    `$portReady = `$false
    for (`$attempt = 1; `$attempt -le 12; `$attempt++) {
        Write-Log "Connectivity attempt `$attempt of 12 to `$storageEndpoint on TCP 445."
        if (Test-NetConnection -ComputerName `$storageEndpoint -Port 445 -InformationLevel Quiet) {
            `$portReady = `$true
            Write-Log "TCP 445 is reachable on `$storageEndpoint."
            break
        }

        Start-Sleep -Seconds 5
    }

    if (-not `$portReady) {
        throw "Timed out waiting for TCP 445 on `$storageEndpoint."
    }

    Write-Log "Saving Azure Files credentials for `$storageEndpoint."
    `$cmdkeyResult = Invoke-NativeCommand -Command { & cmdkey.exe "/add:`$storageEndpoint" "/user:localhost\`$storageAccount" "/pass:`$storageAccountAccessKey" }
    Write-Log "cmdkey exit code: `$(`$cmdkeyResult.ExitCode)"
    if (`$cmdkeyResult.ExitCode -ne 0) {
        throw "cmdkey failed with exit code `$(`$cmdkeyResult.ExitCode). `$(`$cmdkeyResult.Output -join ' ')"
    }

    Write-Log "Mapping `$driveLetter to `$sharePath with a non-persistent mapping."
    `$netUseResult = Invoke-NativeCommand -Command { & net.exe use `$driveLetter `$sharePath /persistent:no }
    Write-Log "net use map exit code: `$(`$netUseResult.ExitCode)"
    if (`$netUseResult.ExitCode -ne 0) {
        throw "net use failed with exit code `$(`$netUseResult.ExitCode). `$(`$netUseResult.Output -join ' ')"
    }

    `$validated = `$false
    `$lastMappingStatus = "missing"
    `$lastPathAvailable = `$false
    for (`$attempt = 1; `$attempt -le 10; `$attempt++) {
        `$mapping = Get-SmbMapping -LocalPath `$driveLetter -ErrorAction SilentlyContinue
        `$lastMappingStatus = if (`$mapping) { [string](`$mapping.Status) } else { "missing" }
        `$lastPathAvailable = Test-Path -LiteralPath `$driveRoot -ErrorAction SilentlyContinue
        Write-Log "Validation attempt `$attempt of 10: SMB status=`$lastMappingStatus; path available=`$lastPathAvailable."

        if (`$mapping -and `$lastMappingStatus -eq "OK" -and `$lastPathAvailable) {
            `$validated = `$true
            break
        }

        Start-Sleep -Seconds 2
    }

    `$finalMapping = Get-SmbMapping -LocalPath `$driveLetter -ErrorAction SilentlyContinue
    if (`$finalMapping) {
        Write-Log "Final SMB mapping state: LocalPath=`$(`$finalMapping.LocalPath); RemotePath=`$(`$finalMapping.RemotePath); Status=`$(`$finalMapping.Status)."
    } else {
        Write-Log "Final SMB mapping state: missing."
    }

    if (-not `$validated) {
        throw "Mapped drive `$driveRoot was not healthy after validation. Last SMB status=`$lastMappingStatus; path available=`$lastPathAvailable."
    }

    Write-Log "Euphrosyne mount task completed successfully."
} catch {
    Write-Log "Euphrosyne mount task failed: `$(`$_.Exception.Message)" "ERROR"
    throw
}
"@

$interactiveUserSidValue = $interactiveUserSid.Value
Grant-PathAcl `
    -Path $installDirectory `
    -Grants @(
        "*${localSystemSid}:(OI)(CI)(F)",
        "*${administratorsGroupSid}:(OI)(CI)(F)",
        "*${interactiveUserSidValue}:(OI)(CI)(RX)"
    )
Grant-PathAcl `
    -Path $logDirectory `
    -Grants @(
        "*${localSystemSid}:(OI)(CI)(F)",
        "*${administratorsGroupSid}:(OI)(CI)(F)",
        "*${interactiveUserSidValue}:(OI)(CI)(M)"
    )

Set-Content -Path $mountScriptPath -Value $mountScript -Encoding UTF8 -Force

Grant-PathAcl `
    -Path $mountScriptPath `
    -Grants @(
        "*${localSystemSid}:F",
        "*${administratorsGroupSid}:F",
        "*${interactiveUserSidValue}:RX"
    )

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$mountScriptPath`""
$trigger = New-ScheduledTaskTrigger `
    -AtLogOn `
    -User $taskUser
$principal = New-ScheduledTaskPrincipal `
    -UserId $taskUser `
    -LogonType Interactive `
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

Write-Host "Registered scheduled task $taskName for $taskUser."
Write-Host "The Azure Files drive will mount when $taskUser logs on."
