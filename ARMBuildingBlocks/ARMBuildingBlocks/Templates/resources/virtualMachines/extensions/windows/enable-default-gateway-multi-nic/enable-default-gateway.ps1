#
# enable_default_gateway.ps1
#

# Obtain the IP configuration for the NIC that doesn't has the default gateway enabled
# TODO - Might return an array for VMs with more than two nics
$ipConfig = Get-NetIPConfiguration | Where-Object -FilterScript {$_.IPv4DefaultGateway -eq $null}
if($ipConfig -ne $null){
    $interfaceIndex = $ipConfig.InterfaceIndex
    $ipAddress=$ipConfig.IPv4Address.IPAddress

	# TODO: Verify with Telmo - Using the default IP address format of the NIC to construct gateway string
    $gatewayAddress=$ipAddress.substring(0, $ipAddress.lastIndexOf('.') + 1) +'1'
    New-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceIndex $interfaceIndex -NextHop $gatewayAddress
}

# Tested the above implementation with a ping of external subnet address via the non primary NIC IP address
# Before running the script ping failed, however afterwards it worked. MAy require more testing but not
# sure right now!