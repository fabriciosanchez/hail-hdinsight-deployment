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
