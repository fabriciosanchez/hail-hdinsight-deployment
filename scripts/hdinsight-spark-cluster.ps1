# Login to your Azure subscription
$sub = Get-AzureRmSubscription -ErrorAction SilentlyContinue
if(-not($sub))
{
    Add-AzureRmAccount
}

# If you have multiple subscriptions, set the one to use
$subscriptionID = "Your default subscription ID here"
Select-AzureRmSubscription -SubscriptionId $subscriptionID

# Create the resource group
$resourceGroupName = Read-Host -Prompt "Enter the resource group name"
$location = Read-Host -Prompt "Enter the Azure region to create resources in, such as 'Central US'"
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# Getting cluster's storage account name
$defaultStorageAccountName = Read-Host -Prompt "Enter the default storage account name"

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

# Getting the HDInsight cluster
$clusterName = Read-Host -Prompt "Enter the name of the HDInsight cluster"

# Cluster login is used to secure HTTPS services hosted on the cluster
$httpCredential = Get-Credential -Message "Enter Cluster login credentials" -UserName "admin"

# SSH user is used to remotely connect to the cluster using SSH clients
$sshCredentials = Get-Credential -Message "Enter SSH user credentials"

# Default cluster size (# of worker nodes), version, type, and OS
$clusterSizeInNodes = "2"
$clusterVersion = "3.6"
$clusterType = "Spark"
$clusterOS = "Linux"

# Create a blob container. This holds the default data store for the cluster.
New-AzureStorageContainer -Name $clusterName -Context $defaultStorageContext

# Creating the Spark object which will define the cluster behavior
$sparkConfig = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.String]"
$sparkConfig.Add("spark", "2.3")

# Creating Action Script configuration object
$scriptActionConfig = New-AzureRmHDInsightClusterConfig

# Referencing the script to be executed
$scriptActionURI = "Your bash action script uri here"

# Adding script to be executing on top of head nodes
$scriptActionConfig = Add-AzureRmHDInsightScriptAction `
    -Config $scriptActionConfig `
    -Name "installing hail" `
    -NodeType HeadNode `
    -Uri $scriptActionURI

# Adding script to be executing on top the worker nodes
$scriptActionConfig = Add-AzureRmHDInsightScriptAction `
    -Config $scriptActionConfig `
    -Name "installing hail" `
    -NodeType WorkerNode `
    -Uri $scriptActionURI

#Creating the HDInsight cluster
New-AzureRmHDInsightCluster `
    -Config $scriptActionConfig `
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