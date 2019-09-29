#!/bin/bash

# script name: l200labs.sh
# Version v0.1.2 20190929
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
    if $(az account list | grep -q 'Please run "az login" to access your accounts.')
    then
        LOGIN_STATUS=0
    else
        LOGIN_STATUS=1
    fi

    if [ $LOGIN_STATUS -eq 0 ]
    then
        echo -e "\nError: You have to login first with the 'az login' command before you can run this lab tool\n"
        exit 4
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
    -o table

    echo -e "\nThe cluster $CLUSTER_NAME has been created succefully...\n"
    echo -e "Getting kubectl credentials for the cluster...\n"
    az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME"
    
    NODE_RESOURCE_GROUP="$(az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME --query nodeResourceGroup -o tsv)"
    VM_NODE_0="$(az vm list -g $NODE_RESOURCE_GROUP --query [0].name -o tsv)"
    echo -e "\n\nPlease wait while we are preparing the environment for you to troubleshoot..."
    az vm run-command invoke \
    -g $NODE_RESOURCE_GROUP \
    -n $VM_NODE_0 \
    --command-id RunShellScript --scripts "sudo systemctl stop kubelet; sudo systemctl stop docker" &> /dev/null \
    -o table
    echo -e "Please Log in to the corresponding node and check basic services like kubelet, docker etc...\n"
}

# Lab scenario 2

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
	echo "l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-h|--help]"
    echo -e "\nHere is the list of current labs available:\n
***************************************************************
*\t \t 1. Node not ready\t\t\t\t*
*\t \t 2. Cluster is in failed state\t\t\t*
*\t \t 3. Cluster Scaling issue\t\t\t*
*\t \t 4. Problem with accessing dashboard\t\t*
*\t \t 5. Cluster unable to communicate with API server
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

az_login_check

# create resource group
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

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ] then
    lab_scenario_1
fi

exit 0