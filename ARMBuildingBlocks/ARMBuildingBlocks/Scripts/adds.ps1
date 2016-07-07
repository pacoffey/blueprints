﻿[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$AdminUser,

  [Parameter(Mandatory=$True)]
  [string]$AdminPassword,

  [Parameter(Mandatory=$True)]
  [string]$SafeModePassword,

  [Parameter(Mandatory=$True)]
  [string]$Domain
)

Install-windowsfeature -name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools

$secSafeModePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force

$secAdminPassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

$credential = New-Object System.Management.Automation.PSCredential ("$Domain\$AdminUser", $secAdminPassword)

Import-Module ADDSDeployment

Install-ADDSDomainController -DomainName $Domain -Credential $credential –InstallDns -SafeModeAdministratorPassword $secSafeModePassword -Force
