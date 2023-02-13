param(
    [Parameter(Mandatory=$true)]
    [string]$AccountName,

    [Parameter(Mandatory=$true)]
    [string]$AccountPassword,
    
    [Parameter(Mandatory=$true)]
    [string]$FileShare,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountAccessKey,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccount,

    [Parameter(Mandatory=$true)]
    [string]$FileShareProjectFolder
)

# Mount fileshare for user
Enable-PSRemoting -Force
.\psexec -u $AccountName -p $AccountPassword -accepteula -h -i "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "$(pwd)\mountDrive.ps1" -FileShare $FileShare -StorageAccountAccessKey $StorageAccountAccessKey -StorageAccount $StorageAccount -FileShareProjectFolder $FileShareProjectFolder

# Prevent drive mapping for all users
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableCMD" -Value "1" -Type DWORD
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDrives" -Value "1" -Type DWORD
