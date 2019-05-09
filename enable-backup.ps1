<#
.DESCRIPTION
A Runbook example which takes On-demand backup for all Azure VMs 
by Azure Backup in a specific Recovery Services Vaults / Azure subscription
using the Run As Account (Service Principal in Azure AD)

.NOTES
Filename  : Enable-AzureBackup

.LINK

#>

Param (
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $AzureSubscriptionId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $vaultName,
    [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
    [Int] $RetentionDays = 21
)

$connectionName = "AzureRunAsConnection"

Try {
    #! Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    Write-Output "Logging in to Azure..."
    Add-AzureRmAccount -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
Catch {
    If (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found..."
        throw $ErrorMessage
    }
    Else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Select-AzureRmSubscription -SubscriptionId $AzureSubscriptionId

$currentDate = Get-Date
$RetailTill = $currentDate.AddDays($RetentionDays)
Write-Output ("Recoverypoints will be retained till " + $RetailTill)

#! Set ARM vault resource
Write-Output ("Working on Vault: " + $vault)
$vault = Get-AzureRmRecoveryServicesVault -Name $vaultName
Set-AzureRmRecoveryServicesVaultContext -Vault $vault

$containers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM -Status Registered 
Write-Output ("Got # of Backup VM Containers: " + $containers.count)

ForEach ($container in $containers) {
    Write-Output ("Working on VM backup: " + $container.FriendlyName)
    $Item = Get-AzureRmRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM 
    Backup-AzureRmRecoveryServicesBackupItem -Item $Item -ExpiryDateTimeUTC $RetailTill
}
Write-Output ("")