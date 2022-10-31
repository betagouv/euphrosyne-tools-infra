param(
    [Parameter(Mandatory=$true)]
    [string]$FileShare,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountAccessKey,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccount,

    [Parameter(Mandatory=$true)]
    [string]$ProjectName
)

# Save the password so the drive will persist on reboot
cmd.exe /C "cmdkey /add:`"${StorageAccount}.file.core.windows.net`" /user:`"localhost\${StorageAccount}`" /pass:`"${StorageAccountAccessKey}`""
# Mount the drive
net use "Z:" "\\${StorageAccount}.file.core.windows.net\${FileShare}\projects\${ProjectName}" /persistent:yes