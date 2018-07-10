# Login to your Azure subscription
# Is there an active Azure subscription?
$sub = Get-AzureRmSubscription -ErrorAction SilentlyContinue
if(-not($sub))
{
    Add-AzureRmAccount
}

# If you have multiple subscriptions, set the one to use
$subscriptionID = "Your subscription ID here"
Select-AzureRmSubscription -SubscriptionId $subscriptionID

# Create the resource group
$resourceGroupName = Read-Host -Prompt "Enter the resource group name"
$location = Read-Host -Prompt "Enter the Azure region to create resources in, such as 'Central US'"
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

$defaultStorageAccountName = Read-Host -Prompt "Enter the default storage account name"

# Create an Azure storae account and container
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

# Create a Spark 2.3 cluster
$clusterName = Read-Host -Prompt "Enter the name of the HDInsight cluster"

# Cluster login is used to secure HTTPS services hosted on the cluster
$httpCredential = Get-Credential -Message "Enter Cluster login credentials" -UserName "fabricio"

# SSH user is used to remotely connect to the cluster using SSH clients
$sshCredentials = Get-Credential -Message "Enter SSH user credentials"

# Get information about the action script to be applied to the cluster
$scriptActionName = Read-Host -Prompt "Enter your script action name"
$scriptActionURI = Read-Host -Prompt "Enter URI where this script is hosted"

# Default cluster size (# of worker nodes), version, type, and OS
$clusterSizeInNodes = "1"
$clusterVersion = "3.6"
$clusterType = "Spark"
$clusterOS = "Linux"

# Create a blob container. This holds the default data store for the cluster.
New-AzureStorageContainer `
    -Name $clusterName -Context $defaultStorageContext

$scriptConfig = New-AzureRmHDInsightClusterConfig `
    -DefaultStorageAccountName "$defaultStorageAccountName.blob.core.windows.net"

$sparkConfig = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.String]"
$sparkConfig.Add("spark", "2.3")

# Add a script action to the cluster configuration
$scriptConfig = Add-AzureRmHDInsightScriptAction `
            -Config $scriptConfig `
            -Name $scriptActionName `
            -NodeType HeadNode `
            -Uri $scriptActionURI `
        | Add-AzureRmHDInsightScriptAction `
            -Config $scriptActionName `
            -Name $scriptActionName `
            -NodeType WorkerNode `
            -Uri $scriptActionURI `

#Creating the HDInsight cluster
New-AzureRmHDInsightCluster `
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
    -SshCredential $sshCredentials `
    -Config $scriptConfig

Get-AzureRmHDInsightCluster -ResourceGroupName $resourceGroupName -ClusterName $clusterName