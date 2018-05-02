[CmdletBinding()]
param(
    [String] [Parameter(Mandatory = $true)]
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
    $IpAddresses = "",

    [String] [Parameter(Mandatory = $false)]
    $OverWriteExisting = ""
)

$ShouldAddBuildAgentIP = $false
if (![string]::IsNullOrEmpty($AddBuildAgentIP)) {
    $ShouldAddBuildAgentIP = [System.Convert]::ToBoolean($AddBuildAgentIP)
}

$ShouldOverWriteExisting = $false
if (![string]::IsNullOrEmpty($OverWriteExisting)) {
    $ShouldOverWriteExisting = [System.Convert]::ToBoolean($OverWriteExisting)
}

# Function for getting the resource type and name.
# This is needed for using a Slot
Function GetResourceTypeAndName($SiteName, $Slot)
{
    $ResourceType = "Microsoft.Web/sites"
    $ResourceName = $SiteName
    if (![string]::IsNullOrEmpty($Slot)) {
        $ResourceType = "$($ResourceType)/slots"
        $ResourceName = "$($ResourceName)/$($Slot)"
    }
    $ResourceType,$ResourceName
}

# Function for adding the IP Address to to the WebApp Properties.
Function AddIpToProperties($properties, $address) {
    $restrictions = $properties.ipSecurityRestrictions
    
    foreach ($restiction in $restrictions) {
        if($address -eq $restiction.ipAddress)
        {
            Write-Host "Ip was already added"
            return;
        }
    }

    $restriction = @{}
    $restriction.Add("ipAddress",$address)
    $restriction.Add("subnetMask","") 
    $properties.ipSecurityRestrictions+= $restriction
}

# Get resource type and resource name
$ResourceType,$ResourceName = GetResourceTypeAndName $WebAppName $Slot

# Get the resource from Azure
$r = Get-AzureRmResource -ResourceGroupName "$($ResourceGroupName)" -ResourceType $ResourceType/config -Name $ResourceName/web -ApiVersion 2016-08-01

# Get resource properties for IP restrictions
$properties = $r.Properties
if($properties.ipSecurityRestrictions -eq $null){
    $properties.ipSecurityRestrictions = @()
}

# Whipe out the current list of restrictions.
if($ShouldOverWriteExisting -eq $True) {
    $properties.ipSecurityRestrictions = @()
}

# Add build agent IP address
if ($ShouldAddBuildAgentIP -eq $True) {
    # Get the current IP address
    # using the api from ipify.org.
    $buildAgentIP = Invoke-RestMethod https://api.ipify.org/?format=json | Select -exp ip
    
    Write-Host("Adding Build Agent IP Address $($buildAgentIP)")
    
    AddIpToProperties $properties $buildAgentIP
}

# Add custom Ip addresses, split on newline
if (![string]::IsNullOrEmpty($IpAddresses)) {
    $seperator = [Environment]::NewLine
    $splitOption = [System.StringSplitOptions]::RemoveEmptyEntries

    $lines = $IpAddresses.Split($seperator, $splitOption)

    foreach ($ipAddress in $lines) {
        Write-Host "Adding custom IP Address $($ipAddress)"
        AddIpToProperties $properties $ipAddress
    }
}

# Update azure resource
Set-AzureRmResource -Force -ResourceGroupName  "$($ResourceGroupName)" -ResourceType $ResourceType/config -Name $ResourceName/web -ApiVersion 2016-08-01 -PropertyObject $properties

# add a short timer because there could be some delay after adding the IP address to the resource.
Start-Sleep -s 10