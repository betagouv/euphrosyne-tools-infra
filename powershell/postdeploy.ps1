Param (
[string]$ProjectUserPassword,
[string]$ProjectUsername,
[string]$StorageAccountName,
[string]$StorageAccessKey,
[string]$FileshareName,
[string]$ProjectName
)

# Create project user 
$Password = ConvertTo-SecureString $ProjectUserPassword -AsPlainText -Force
$ProjectUser = New-LocalUser $ProjectUsername -Password $Password
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $ProjectUser
Add-LocalGroupMember -Group "Users" -Member $ProjectUser

$connectTestResult = Test-NetConnection -ComputerName "${StorageAccountName}.file.core.windows.net" -Port 445
if ($connectTestResult.TcpTestSucceeded) {
    $User = "localhost\${StorageAccountName}"
	$Pwd = ConvertTo-SecureString $StorageAccessKey -AsPlainText -Force
	$Cred = New-Object System.Management.Automation.PSCredential($User,$Pwd)
	New-SmbGlobalMapping -LocalPath W: -RemotePath  "\\${StorageAccountName}.file.core.windows.net\${FileshareName}\projects\${ProjectName}" -Persistent $true -Credential $Cred
} else {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
}

# Allow write access to specific processed data folder in project folder
$acl = Get-Acl "W:/raw-data"
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "Write", "ContainerInherit,ObjectInherit", "None", "Deny")
$acl.SetAccessRule($AccessRule)
$acl | Set-Acl "W:/raw-data"
