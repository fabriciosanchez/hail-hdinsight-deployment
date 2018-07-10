# 1. Deploying Hail to Azure HDInsight

The first thing we need to do  in order to get Hail on Azure is deploy out a new HDInsight cluster. We can do this both throught the portal and either using Powershell or Azure CLI (version 1.0, once Azure CLI 2.0 have not received rollout yet).

The code below (Powershell-based) does deploy a new HDInsight cluster with 2 head nodes and 2 worker nodes and automatically executes out the bash script whereas Hail is deployed into the cluster.

```powershell
# Login to your Azure subscription
$sub = Get-AzureRmSubscription -ErrorAction SilentlyContinue
if(-not($sub))
{
    Add-AzureRmAccount
}

# If you have multiple subscriptions, set the one to use
$subscriptionID = "Add your default subscriptionID here"
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
$scriptActionURI = "Your bash script uri here"

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
```

Important considerations:

* This script is based on Powershell 6.4.0+ so make sure you have it installed and configured. For more information about it, follow this [link](https://docs.microsoft.com/en-us/powershell/azure/overview?view=azurermps-6.4.0).

* As this script is currently focusing [Hail.is](http://hail.is) deployment, we're creating a Azure HDInsigh based on Spark 2.3, which is the latest version supported by Azure HDInsights.

# 2. Deploying Hail

The above script has been automaticaly deploying Hail onto Azure HDInsight cluster by calling `hail-install.sh`. The portion of code below presents the action script in charge for do this.

```bash
#!/bin/bash

# Global variables
BASE_DIRECTORY="/usr/hdp/current"
HAIL_DIRECTORY_NAME="hail"
HAIL_DIRECTORY_PATH="/usr/hdp/current/"$HAIL_DIRECTORY_NAME

# Advising user about Hail's installation starting
echo ""
echo "Installing Hail. Hold on, it can take a while."
echo ""
echo "Step 1 - Cleaning up the environment..."
echo ""

# STEP 1 - CLEANING UP THE ENVIRONMENT FOR A NEW INSTALLATION

# If "hail" directory exists, remove it.
if [ -d "$HAIL_DIRECTORY_PATH" ]; then
    cd $BASE_DIRECTORY
    sudo rm -rf $HAIL_DIRECTORY_NAME
    echo "Done. Directory removed successfuly."
    echo ""
else
    echo "Hail's directory doesn't exists. Moving to the next step."
    echo ""
fi

# Cleaning up environment variables (if exists)
echo "Cleaning environment variables (if exists)..."
echo ""
sudo sed -i '/HAIL_HOME/d' /etc/environment
sudo sed -i '/PYTHONPATH/d' /etc/environment
sudo sed -i '/SPARK_HOME/d' /etc/environment
sudo sed -i '/PYSPARK_SUBMIT_ARGS/d' /etc/environment
echo "Done. Moving to the next step."
echo ""

# STEP 2 - GETTING HAIL SOURCE FROM GITHUB AND BUNDLING IT

# Getting Hail's source code
echo "Getting Hail's source code..."
sudo git clone https://github.com/hail-is/hail.git
echo ""
echo "Done. Hail's is already here."
echo ""

# Navigating into the new directory
cd $HAIL_DIRECTORY_NAME

# Compiling and bundling Hail using Gradle
echo "Compiling and bundling Hail..."
sudo ./gradlew -Dspark.version=2.2.0 shadowJar archiveZip
echo ""
echo "Done. Hail is already built."
echo ""

# STEP 3 - CONFIGURING ENVIRONMENT VARIABLES

# Adding Hail to Python variable
echo "Configuring environment variables..."

echo "SPARK_HOME=/usr/hdp/current/spark2-client/" | sudo tee -a /etc/environment
echo "HAIL_HOME=$HAIL_DIRECTORY_PATH" | sudo tee -a /etc/environment
echo "PYTHONPATH=${PYTHONPATH:+$PYTHONPATH:}$HAIL_DIRECTORY_PATH/build/distributions/hail-python.zip" | sudo tee -a /etc/environment
```

# 3. Raw files

* [HDInsight deploy's script](https://github.com/fabriciosanchez/hail-hdinsight-deployment/blob/master/scripts/hdinsight-spark-cluster.ps1)
* [Hail deployment's script](https://github.com/fabriciosanchez/hail-hdinsight-deployment/blob/master/scripts/hail-install.sh)