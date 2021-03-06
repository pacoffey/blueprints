@ECHO OFF
SETLOCAL

IF "%~1"=="" (
    ECHO Usage: %0 subscription-id
    ECHO   For example: %0 xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    EXIT /B
    )

REM Explicitly set the subscription to avoid confusion as to which subscription
REM is active/default

SET SUBSCRIPTION=%1

REM Set up variables to build out the naming conventions for deployment

SET APP_NAME=hybrid
SET LOCATION=centralus
SET ENVIRONMENT=dev
SET VPN_GATEWAY_TYPE=RouteBased

SET VNET_IP_RANGE=10.20.0.0/16
SET ON_PREMISES_ADDRESS_SPACE=10.10.0.0/16
SET ON_PREMISES_PUBLIC_IP=40.50.60.70
REM This gives the gateway an IP range 10.20.255.224 - 10.20.255.254
SET GATEWAY_SUBNET_IP_RANGE=10.20.255.224/27
REM This give the internal subnet an IP range of 10.20.1.1 - 10.20.1.254
SET INTERNAL_SUBNET_IP_RANGE=10.20.1.0/24
REM We will put this at the end of the subnet
SET INTERNAL_LOAD_BALANCER_FRONTEND_IP_ADDRESS=10.20.1.254

REM Set up the names of things using recommended conventions
SET RESOURCE_GROUP=%APP_NAME%-%ENVIRONMENT%-rg
SET VNET_NAME=%APP_NAME%-vnet
SET PUBLIC_IP_NAME=%APP_NAME%-pip

SET INTERNAL_SUBNET_NAME=%APP_NAME%-internal-subnet
SET VPN_GATEWAY_NAME=%APP_NAME%-vgw
SET LOCAL_GATEWAY_NAME=%APP_NAME%-lgw
SET VPN_CONNECTION_NAME=%APP_NAME%-vpn

SET INTERNAL_LOAD_BALANCER_NAME=%APP_NAME%-ilb
SET INTERNAL_LOAD_BALANCER_FRONTEND_IP_NAME=%APP_NAME%-ilb-fip
SET INTERNAL_LOAD_BALANCER_POOL_NAME=%APP_NAME%-ilb-pool

SET INTERNAL_LOAD_BALANCER_PROBE_PROTOCOL=tcp
SET INTERNAL_LOAD_BALANCER_PROBE_INTERVAL=300
SET INTERNAL_LOAD_BALANCER_PROBE_COUNT=4
SET INTERNAL_LOAD_BALANCER_PROBE_NAME=%INTERNAL_LOAD_BALANCER_NAME%-probe

REM Set up the postfix variables attached to most CLI commands
SET POSTFIX=--resource-group %RESOURCE_GROUP% --subscription %SUBSCRIPTION%

CALL azure config mode arm

REM Create resources

REM Create the enclosing resource group
CALL :CallCLI azure group create --name %RESOURCE_GROUP% --location %LOCATION% ^
  --subscription %SUBSCRIPTION%

REM Create the VNet
CALL :CallCLI azure network vnet create --address-prefixes %VNET_IP_RANGE% ^
  --name %VNET_NAME% --location %LOCATION% %POSTFIX%

REM Create the GatewaySubnet
CALL :CallCLI azure network vnet subnet create --vnet-name %VNET_NAME% ^
  --address-prefix %GATEWAY_SUBNET_IP_RANGE% --name GatewaySubnet %POSTFIX%

REM Create public IP address for VPN Gateway
REM Note that the Azure VPN Gateway only supports dynamic IP addresses
CALL :CallCLI azure network public-ip create --allocation-method Dynamic ^
  --name %PUBLIC_IP_NAME% --location %LOCATION% %POSTFIX%

REM Create virtual network gateway
CALL :CallCLI azure network vpn-gateway create --name %VPN_GATEWAY_NAME% ^
  --vpn-type %VPN_GATEWAY_TYPE% --public-ip-name %PUBLIC_IP_NAME% --vnet-name %VNET_NAME% ^
  --location %LOCATION% %POSTFIX%

REM Create local gateway
CALL :CallCLI azure network local-gateway create --name %LOCAL_GATEWAY_NAME% ^
  --address-space %ON_PREMISES_ADDRESS_SPACE% --ip-address %ON_PREMISES_PUBLIC_IP% ^
  --location %LOCATION% %POSTFIX%

REM Create a site-to-site connection
CALL :CallCLI azure network vpn-connection create --name %VPN_CONNECTION_NAME% ^
  --vnet-gateway1 %VPN_GATEWAY_NAME% --vnet-gateway1-group %RESOURCE_GROUP% ^
  --lnet-gateway2 %LOCAL_GATEWAY_NAME% --lnet-gateway2-group %RESOURCE_GROUP% ^
  --type IPsec --location %LOCATION% %POSTFIX%

REM Create the internal subnet
CALL :CallCLI azure network vnet subnet create --vnet-name %VNET_NAME% ^
  --address-prefix %INTERNAL_SUBNET_IP_RANGE% --name %INTERNAL_SUBNET_NAME% %POSTFIX%

REM Create an internal load balancer for routing requests
CALL :CallCLI azure network lb create --name %INTERNAL_LOAD_BALANCER_NAME% ^
  --location %LOCATION% %POSTFIX%

REM Create a frontend IP address for the internal load balancer
CALL :CallCLI azure network lb frontend-ip create --subnet-vnet-name %VNET_NAME% ^
  --subnet-name %INTERNAL_SUBNET_NAME% ^
  --private-ip-address %INTERNAL_LOAD_BALANCER_FRONTEND_IP_ADDRESS% ^
  --lb-name %INTERNAL_LOAD_BALANCER_NAME% ^
  --name %INTERNAL_LOAD_BALANCER_FRONTEND_IP_NAME% ^
  %POSTFIX%

REM Create the backend address pool for the internal load balancer
CALL :CallCLI azure network lb address-pool create --lb-name %INTERNAL_LOAD_BALANCER_NAME% ^
  --name %INTERNAL_LOAD_BALANCER_POOL_NAME% %POSTFIX%

REM Create a health probe for the internal load balancer
CALL :CallCLI azure network lb probe create --protocol %INTERNAL_LOAD_BALANCER_PROBE_PROTOCOL% ^
  --interval %INTERNAL_LOAD_BALANCER_PROBE_INTERVAL% --count %INTERNAL_LOAD_BALANCER_PROBE_COUNT% ^
  --lb-name %INTERNAL_LOAD_BALANCER_NAME% --name %INTERNAL_LOAD_BALANCER_PROBE_NAME% %POSTFIX%

REM This will show the shared key for the VPN connection.  We do not need the error checking.
CALL azure network vpn-connection shared-key show --name %VPN_CONNECTION_NAME% %POSTFIX%

GOTO :eof

:CallCLI
SETLOCAL
CALL %*
IF ERRORLEVEL 1 (
    CALL :ShowError "Error executing CLI Command: " %*
    REM This command executes in the main script context so we can exit the whole script on an error
    (GOTO) 2>NULL & GOTO :eof
)
GOTO :eof

:ShowError
SETLOCAL EnableDelayedExpansion
REM Print the message
ECHO %~1
SHIFT
REM Get the first part of the azure CLI command so we do not have an extra space at the beginning
SET CLICommand=%~1
SHIFT
REM Loop through the rest of the parameters and recreate the CLI command
:Loop
    IF "%~1"=="" GOTO Continue
    SET "CLICommand=!CLICommand! %~1"
    SHIFT
GOTO Loop
:Continue
ECHO %CLICommand%
GOTO :eof
