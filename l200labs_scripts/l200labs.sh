#!/bin/bash

# script name: l200labs.sh
# Version v0.1.5 20190930
# Set of tools to deploy L200 Azure containers labs

# "-g|--resource-group" resource group name
# "-n|--name" AKS cluster name
# "-l|--lab" Lab scenario to deploy (5 possible options)
# "-v|--validate" Validate a particular scenario
# "-h|--help" help info

# read the options
TEMP=`getopt -o g:n:l:hv --long resource-group:,name:,lab:,help,validate -n 'l200labs.sh' -- "$@"`
eval set -- "$TEMP"

# set an initial value for the flags
RESOURCE_GROUP=""
CLUSTER_NAME=""
LAB_SCENARIO=""
VALIDATE=0
HELP=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) RESOURCE_GROUP="$2"; shift 2;;
            esac;;
        -n|--name) case "$2" in
            "") shift 2;;
            *) CLUSTER_NAME="$2"; shift 2;;
            esac;;
        -l|--lab) case "$2" in
            "") shift 2;;
            *) LAB_SCENARIO="$2"; shift 2;;
            esac;;
        -v|--validate) VALIDATE=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

# Variable definition
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"

# Funtion definition

# az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\nError: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

# check resource group and cluster
function check_resourcegroup_cluster () {
    RG_EXIST=$(az group show -g $RESOURCE_GROUP &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\nCreating resource group ${RESOURCE_GROUP}...\n"
        az group create --name $RESOURCE_GROUP --location eastus &>/dev/null
    else
        echo -e "\nResource group $RESOURCE_GROUP already exists...\n"
    fi

    CLUSTER_EXIST=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null; echo $?)
    if [ $CLUSTER_EXIST -eq 0 ]
    then
        echo -e "\nCluster $CLUSTER_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 8
    fi
}

# validate cluster exists
function validate_cluster_exists () {
    CLUSTER_EXIST=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null; echo $?)
    if [ $CLUSTER_EXIST -ne 0 ]
    then
        echo -e "\nERROR: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP does not exists...\n"
        exit 8
    fi
}

# Lab scenario 1
function lab_scenario_1 () {
    echo -e "Deploying cluster for lab1...\n"
    az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --node-count 3 \
    --enable-addons monitoring \
    --generate-ssh-keys \
    --tag l200lab=1 \
    -o table

    validate_cluster_exists

    echo -e "Getting kubectl credentials for the cluster...\n"
    az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME"
    
    NODE_RESOURCE_GROUP="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query nodeResourceGroup -o tsv)"
    VM_NODE_0="$(az vm list -g $NODE_RESOURCE_GROUP --query [0].name -o tsv)"
    echo -e "\n\nPlease wait while we are preparing the environment for you to troubleshoot..."
    az vm run-command invoke \
    -g $NODE_RESOURCE_GROUP \
    -n $VM_NODE_0 \
    --command-id RunShellScript --scripts "sudo systemctl stop kubelet; sudo systemctl stop docker" &> /dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "Please Log in to the corresponding node and check basic services like kubelet, docker etc...\n"
    echo -e "Cluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_1_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 5
    elif [ $LAB_TAG -eq 1 ]
    then
        az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
        if $(kubectl get nodes | grep -q "NotReady")
        then
            echo -e "\nScenario 1 is still FAILED\n"
        else
            echo -e "\nCluster looks good now, the keyword for the assesment is:\n\nhometradebroke\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 5
    fi
}

# Lab scenario 2
function lab_scenario_2 () {
    az network vnet create --name customvnetlab2  --resource-group  $RESOURCE_GROUP --address-prefixes 20.0.0.0/26  --subnet-name customsubnetlab2 --subnet-prefixes 20.0.0.0/26 &>/dev/null
    VNET_ID=$(az network vnet show -g $RESOURCE_GROUP -n customvnetlab2 | grep subnet | grep subscriptions | cut -d: -f2 | cut -d"," -f 1 | cut -d" " -f2 | cut -d"\"" -f2)
    az aks create --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --generate-ssh-keys \
    -c 1 -s Standard_B2ms \
    --network-plugin azure \
    --vnet-subnet-id  $VNET_ID \
    --tag l200lab=2 \
    -o table

    validate_cluster_exists
    az aks scale -g $RESOURCE_GROUP -n $CLUSTER_NAME -c 4 &> /dev/null
    az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME &>/dev/null
    CLUSTER_URI="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query id -o tsv)"
    echo -e "\n\n********************************************************"
    echo -e "\nIt seems cluster is in failed state, please check the issue and resolve it appropriately\n"
    echo -e "Cluster uri == ${CLUSTER_URI}\n"
}

function lab_scenario_2_validation () {
    validate_cluster_exists
    LAB_TAG="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query tags.l200lab -o tsv)"
    if [ -z $LAB_TAG ]
    then
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 5
    elif [ $LAB_TAG -eq $LAB_SCENARIO ]
    then
        if $(az aks show -g labtest2 -n akslab2 --query provisioningState -o tsv | grep -q "Succeeded")
        then
            echo -e "\nCluster looks good now, the keyword for the assesment is:\n\nstopeffortsweet\n"
        else
            echo -e "\nScenario $LAB_SCENARIO is still FAILED\n"
        fi
    else
        echo -e "\nError: Cluster $CLUSTER_NAME in resource group $RESOURCE_GROUP was not created with this tool for lab $LAB_SCENARIO and cannot be validated...\n"
        exit 5
    fi
}

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	echo "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-h|--help]"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t 1. Node not ready
*\t 2. Cluster is in failed state
*\t 3. Cluster Scaling issue
*\t 4. Problem with accessing dashboard
*\t 5. Cluster unable to communicate with API server
***************************************************************\n"
    echo -e '"-g|--resource-group" resource group name
"-n|--name" AKS cluster name
"-l|--lab" Lab scenario to deploy (5 possible options)
"-v|--validate" Validate a particular scenario
"-h|--help" help info\n'
	exit 0
fi

if [ -z $RESOURCE_GROUP ]; then
	echo -e "Error: Resource group value must be provided. \n"
	echo -e "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-h|--help]\n"
	exit 5
fi

if [ -z $CLUSTER_NAME ]; then
	echo -e "Error: Cluster name value must be provided. \n"
	echo -e "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-h|--help]\n"
	exit 6
fi

if [ -z $LAB_SCENARIO ]; then
	echo -e "Error: Lab scenario value must be provided. \n"
	echo -e "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-h|--help]\n"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t 1. Node not ready
*\t 2. Cluster is in failed state
*\t 3. Cluster Scaling issue
*\t 4. Problem with accessing dashboard
*\t 5. Cluster unable to communicate with API server
***************************************************************\n"
	exit 7
fi

# main
echo -e "\nWelcome to the L200 Troubleshooting sessions
********************************************

This tool will use your internal azure account to deploy the lab environment.
Verifing if your authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_1

elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_2

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_2_validation

else
    echo -e "\nError: no valid option provided\n"
fi

exit 0