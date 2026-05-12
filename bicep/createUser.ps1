param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectUsername,

    [Parameter(Mandatory=$true)]
    [string]$ProjectUserPassword
)

# Create project user 
$Password = ConvertTo-SecureString $ProjectUserPassword -AsPlainText -Force
$ProjectUser = New-LocalUser $ProjectUsername -Password $Password
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $ProjectUser
Add-LocalGroupMember -Group "Users" -Member $ProjectUser
