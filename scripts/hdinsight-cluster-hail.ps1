# Login to your Azure subscription
# Is there an active Azure subscription?
$sub = Get-AzureRmSubscription -ErrorAction SilentlyContinue
if(-not($sub))
{
    Add-AzureRmAccount
}

# If you have multiple subscriptions, set the one to use
$subscriptionID = "9b3db624-2934-44c6-830f-9a17cb92cb4a"
Select-AzureRmSubscription -SubscriptionId $subscriptionID

# Get user input/default values
$resourceGroupName = Read-Host -Prompt "Enter the resource group name"
$location = Read-Host -Prompt "Enter the Azure region to create resources in"

# Create the resource group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

$defaultStorageAccountName = Read-Host -Prompt "Enter the name of the storage account"

# Create an Azure storage account and container
New-AzureRmStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $defaultStorageAccountName `
    -Type Standard_LRS `
    -Location $location
$defaultStorageAccountKey = (Get-AzureRmStorageAccountKey `
                                -ResourceGroupName $resourceGroupName `
                                -Name $defaultStorageAccountName)[0].Value
$defaultStorageContext = New-AzureStorageContext `
                                -StorageAccountName $defaultStorageAccountName `
                                -StorageAccountKey $defaultStorageAccountKey

# Get information for the HDInsight cluster
$clusterName = Read-Host -Prompt "Enter the name of the HDInsight cluster"

# Cluster login is used to secure HTTPS services hosted on the cluster
$httpCredential = Get-Credential -Message "Enter Cluster login credentials" -UserName "fabricio"

# SSH user is used to remotely connect to the cluster using SSH clients
$sshCredentials = Get-Credential -Message "Enter SSH user credentials"

# Get information about the action script to be applied to the cluster
$scriptActionName = Read-Host -Prompt "Enter your scription action name"
$scriptActionURI = Read-Host -Prompt "Enter URI where this script is hosted"
$scriptActionParameters = ""


# Default cluster size (# of worker nodes), version, type, and OS
$clusterSizeInNodes = "1"
$clusterVersion = "3.6"
$clusterType = "Spark"
$clusterOS = "Linux"

$sparkConfig = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.String]"
$sparkConfig.Add("spark", "2.3")

# Create a blob container. This holds the default data store for the cluster.
New-AzureStorageContainer `
    -Name $clusterName -Context $defaultStorageContext 

# Create the HDInsight cluster
New-AzureRmHDInsightClusterConfig `
            | Add-AzureRmHDInsightScriptAction `
                -Name $scriptActionName `
                -Uri $scriptActionURI `
                -Parameters $scriptActionParameters `
                -NodeType Worker `
            | Add-AzureRmHDInsightScriptAction `
                -Name $scriptActionName `
                -Uri $scriptActionURI `
                -Parameters $scriptActionParameters `
                -NodeType Head `
            | New-AzureRmHDInsightCluster `
                -ResourceGroupName $resourceGroupName `
                -ClusterName $clusterName `
                -Location $location `
                -ClusterSizeInNodes $clusterSizeInNodes `
                -ClusterType $clusterType `
                -OSType $clusterOS `
                -Version $clusterVersion `
                -ComponentVersion $sparkConfig `
                -HttpCredential $httpCredential `
                -DefaultStorageAccountName "$defaultStorageAccountName.blob.core.windows.net" `
                -DefaultStorageAccountKey $defaultStorageAccountKey `
                -DefaultStorageContainer $clusterName `
                -SshCredential $sshCredentials

Get-AzureRmHDInsightCluster -ResourceGroupName $resourceGroupName -ClusterName $clusterName