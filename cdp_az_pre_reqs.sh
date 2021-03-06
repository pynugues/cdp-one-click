#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates AWS pre-requisites

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)"

}




# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 1 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 1 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

# Parsing arguments
parse_parameters ${1}


# AWS pre-requisites (per env)
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating Azure pre-requisites for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}


# 1. Resource Group
result=$($base_dir/az-pre-req/az_create_resource_group.sh $prefix "$region" 2>&1 > /dev/null)
handle_exception $? $prefix "resource group creation" "$result"

resource_group=${prefix}-cdp-rg
echo "${CHECK_MARK}  $prefix: resource $resource_group created"

# 2. Deploying Storage
result=$($base_dir/az-pre-req/az_deploy_storage.sh $prefix "$region" 2>&1 > /dev/null)
handle_exception $? $prefix "storage deployment" "$result"

storage_account_name="${prefix}cdpsa"
echo "${CHECK_MARK}  $prefix: storage account $storage_account_name created"

# 3. Create permissions
result=$($base_dir/az-pre-req/az_create_permissons.sh $prefix) # 2>&1 > /dev/null)
handle_exception $? $prefix "permission creation" "$result"

echo "${CHECK_MARK}  $prefix: permissions created"

# 4. Credentials
if [[ "$generate_credential" == "yes" ]]
then
   
    # Purging existing assets
    result=$($base_dir/az-pre-req/az_delete_cred_role.sh $prefix 2>&1 > /dev/null)
    handle_exception $? $prefix "credential role purge" "$result"
    echo "${CHECK_MARK}  $prefix: credential role purged"


    result=$($base_dir/az-pre-req/az_delete_rbac_app.sh $prefix 2>&1 > /dev/null)
    handle_exception $? $prefix "credential app purge" "$result"
    echo "${CHECK_MARK}  $prefix: credential app purged"

    cred=$(cdp environments list-credentials | jq -r .credentials[].credentialName | grep ${credential})
    if [[ ${credential} == $cred ]]
    then
        result=$(cdp environments delete-credential --credential-name ${credential} 2>&1 > /dev/null)
        handle_exception $? $prefix "credential purge" "$result"
        echo "${CHECK_MARK}  $prefix: credential purged"
    fi

    sleep $sleep_duration

    # Creating account
    result=$($base_dir/az-pre-req/az_create_rbac_app.sh $prefix  2> /dev/null)
    handle_exception $? $prefix "credential app creation" "$result"
    echo "${CHECK_MARK}  $prefix: credential app created"
    appId=$(echo $result | jq -r .appId)
    appSecret=$(echo $result | jq -r .password)
    
    result=$($base_dir/az-pre-req/az_create_cred_role.sh $prefix  2> /dev/null)
    handle_exception $? $prefix "credential role creation" "$result"
    echo "${CHECK_MARK}  $prefix: credential role created"

    result=$($base_dir/cdp_create_az_credential.sh ${credential} ${appId} ${appSecret} 2>&1 > /dev/null)
    handle_exception $? $prefix "credential creation" "$result"
    echo "${CHECK_MARK}  $prefix: new credential created"
fi




echo ""
echo "Azure pre-requisites created for $prefix!"
echo ""