param(
    [Parameter(Mandatory=$true)]
    [string]$FileShare,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountAccessKey,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccount,

    [Parameter(Mandatory=$true)]
    [string]$FileShareProjectFolder
)

$Password = ConvertTo-SecureString "${StorageAccountAccessKey}" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "localhost\${StorageAccount}", $Password
New-PSDrive -Persist -Name "Z" -PSProvider "FileSystem" -Root "\\${StorageAccount}.file.core.windows.net\${FileShare}\projects\${FileShareProjectFolder}" -Scope Global -Credential $Credential