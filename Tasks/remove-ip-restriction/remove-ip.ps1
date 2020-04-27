[CmdletBinding()]
param(
    [String] [Parameter(Mandatory = $false)]
    $ConnectedServiceName,

    [String] [Parameter(Mandatory = $true)]
    $WebAppName,
    
    [String] [Parameter(Mandatory = $true)]
    $ResourceGroupName,

    [String] [Parameter(Mandatory = $false)]
    $Slot = "",

    [String] [Parameter(Mandatory = $false)]
    $AddBuildAgentIP = "",

    [String] [Parameter(Mandatory = $false)]
    $IpAddresses = ""
)

$ShouldAddBuildAgentIP = $false
if (![string]::IsNullOrEmpty($AddBuildAgentIP)) {
    $ShouldAddBuildAgentIP = [System.Convert]::ToBoolean($AddBuildAgentIP)
}

# Function for getting the resource type and name.
# This is needed for using a Slot
Function GetResourceTypeAndName($SiteName, $Slot) {
    $ResourceType = "Microsoft.Web/sites"
    $ResourceName = $SiteName
    if (![string]::IsNullOrEmpty($Slot)) {
        $ResourceType = "$($ResourceType)/slots"
        $ResourceName = "$($ResourceName)/$($Slot)"
    }
    $ResourceType, $ResourceName
}

function RemoveIpFromProperties($properties, $address, $subnetmask) {
    $restrictions = $properties.ipSecurityRestrictions

    $newRestrictions = @($restrictions | Where-Object { ($_.ipAddress.split("/")[0]) -ne $address })

    foreach ($restiction in $newRestrictions) {
        Write-Host $restiction
    }

    $properties.ipSecurityRestrictions = $newRestrictions
}

# Get resource type and resource name
$ResourceType, $ResourceName = GetResourceTypeAndName $WebAppName $Slot

# Get the resource from Azure
$r = Get-AzureRmResource -ResourceGroupName "$($ResourceGroupName)" -ResourceType $ResourceType/config -Name $ResourceName/web -ApiVersion 2018-11-01

# Get resource properties for IP restrictions
$properties = $r.Properties
if ($null -eq $properties.ipSecurityRestrictions) {
    $properties.ipSecurityRestrictions = @()
}

# Whipe out the current list of restrictions.
if ($ShouldOverWriteExisting -eq $True) {
    $properties.ipSecurityRestrictions = @()
}

# Add build agent IP address
if ($ShouldAddBuildAgentIP -eq $True) {
    # Get the current IP address
    # using the api from ipify.org.
    $buildAgentIP = Invoke-RestMethod https://api.ipify.org/?format=json | Select-Object -exp ip
    
    Write-Host("Adding Build Agent IP Address $($buildAgentIP)")
    
    RemoveIpFromProperties $properties $buildAgentIP ""
}

# Add custom Ip addresses, split on newline or comma
if (![string]::IsNullOrEmpty($IpAddresses)) {
    $seperator = [Environment]::NewLine, ","
    $splitOption = [System.StringSplitOptions]::RemoveEmptyEntries

    $lines = $IpAddresses.Split($seperator, $splitOption)

    foreach ($line in $lines) {
        if ($line -match "/") {
            $subnetmask = $line.split("/")[1].split(" ")[0]
            $ipAddress = $line.split("/")[0]
        }
        else {
            $ipAddress = $line.split()[0]
            $subnetmask = ""
        }
        Write-Host "Adding custom IP Address $($ipAddress)"
        RemoveIpFromProperties $properties $ipAddress $subnetmask
    }
}

# Update azure resource
Set-AzureRmResource -Force -ResourceGroupName  "$($ResourceGroupName)" -ResourceType $ResourceType/config -Name $ResourceName/web -ApiVersion 2018-11-01 -PropertyObject $properties

# add a short timer because there could be some delay after adding the IP address to the resource.
Start-Sleep -s 10