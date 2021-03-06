:: create-default-topology.cmd
:: This script will create default hub-and-spoke topology with
:: one on-prem network, one hub, and two spokes.
::
@ECHO OFF
SETLOCAL EnableDelayedExpansion

IF "%~5"=="" (
    ECHO Usage: %0 resource-group-prefix subscription-id ipsec-shared-key on-prem-gateway-pip on-prem-address-prefix
    ECHO   For example: %0 mytest123 13ed86531-1602-4c51-a4d4-afcfc38ddad3 myipsecsharedkey123 11.22.33.44 192.168.0.0/24
    EXIT /B
    )

:: input variables from the command line
SET RESOURCE_PREFIX=%1
SET SUBSCRIPTION=%2
SET IPSEC_SHARED_KEY=%3
SET ONP_GATEWAY_PIP=%4
SET ONP_CIDR=%5

CALL pnp-hub-spoke-functions.cmd :LOAD_DEFAULT_DATA

CALL pnp-hub-spoke-functions.cmd :CREATE_DEFAULT_VNETS

CALL pnp-hub-spoke-functions.cmd :CREATE_DEFAULT_VPN_CONNECTIONS

GOTO :eof

