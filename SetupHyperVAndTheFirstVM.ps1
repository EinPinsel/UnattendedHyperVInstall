Start-Process powershell.exe -Verb runas


# Host-Configuration
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V –All

$SwitchName = "Intranet"
New-VMSwitch -Name $SwitchName -SwitchType Internal

$InterfaceName = "vEthernet (" + $SwitchName + ")"


$IP = "192.168.1.254"
$MaskBits = 24 # This means subnet mask = 255.255.255.0
# $Gateway = "10.10.10.1"
# $Dns = "10.10.10.100"
$IPType = "IPv4"

# Retrieve the network vAdapter that you want to configure
$vAdapter = Get-NetvAdapter -InterfaceAlias $InterfaceName

# Remove any existing IP, gateway from our ipv4 vAdapter
If (($vAdapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
    $vAdapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
}

If (($vAdapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
    $vAdapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
}

 # Configure the IP address and default gateway
$vAdapter | New-NetIPAddress `
    -AddressFamily $IPType `
    -IPAddress $IP `
    -PrefixLength $MaskBits 

## Configure the DNS client server IP addresses
# $vAdapter | Set-DnsClientServerAddress -ServerAddresses $DNS

# We need an UnattendedInstall.xml-File
# Download the ADK (https://download.microsoft.com/download/6/A/E/6AEA92B0-A412-4622-983E-5B305D2EBE56/adk/adksetup.exe) and 
# install only the Windows SIM, afterwards follow the instructions from 
# http://www.derekseaman.com/2012/07/windows-server-2012-unattended.html or use the provided xml-File
# After the creation of the xml-File, you need to get the iso extracted. Use 7Zip for this
# Download http://download.imgburn.com/SetupImgBurn_2.5.8.0.exe


# Creation of VM with the hostname

$m = "Machine"
New-VM $m -MemoryStartupBytes 1024MB -SwitchName Intranet -NewVHDPath ($m +".vhdx") -NewVHDSizeBytes 30GB -Generation 1

# Mounting the specified Windows ISO 

$iso = "C:\Users\stefa\Downloads\unattended.iso"
Add-VMDvdDrive -VMName $m –Path $iso

Start-VM -VMName $m


# http://windowsitpro.com/hyper-v/modify-ip-configuration-vm-hyper-v-host


$Msvm_VirtualSystemManagementService = Get-WmiObject -Namespace root\virtualization\v2 `
    -Class Msvm_VirtualSystemManagementService 

$Msvm_ComputerSystem = Get-WmiObject -Namespace root\virtualization\v2 `
    -Class Msvm_ComputerSystem -Filter "ElementName='$m'" 

$Msvm_VirtualSystemSettingData = ($Msvm_ComputerSystem.GetRelated('Msvm_VirtualSystemSettingData', `
    'Msvm_SettingsDefineState', $null, $null, 'SettingData', 'ManagedElement', $false, $null) | % {$_})

$Msvm_SyntheticEthernetPortSettingData = $Msvm_VirtualSystemSettingData.GetRelated('Msvm_SyntheticEthernetPortSettingData')

$Msvm_GuestNetworkAdapterConfiguration = ($Msvm_SyntheticEthernetPortSettingData.GetRelated( `
    'Msvm_GuestNetworkAdapterConfiguration', 'Msvm_SettingDataComponent', `
    $null, $null, 'PartComponent', 'GroupComponent', $false, $null) | % {$_})

$Msvm_GuestNetworkAdapterConfiguration.DHCPEnabled = $false
$Msvm_GuestNetworkAdapterConfiguration.IPAddresses = @('192.168.1.1')
$Msvm_GuestNetworkAdapterConfiguration.Subnets = @('255.255.255.0')
$Msvm_GuestNetworkAdapterConfiguration.DefaultGateways = @('192.168.1.1')
$Msvm_GuestNetworkAdapterConfiguration.DNSServers = @('192.168.1.1')

$Msvm_VirtualSystemManagementService.SetGuestNetworkAdapterConfiguration( `
$Msvm_ComputerSystem.Path, $Msvm_GuestNetworkAdapterConfiguration.GetText(1))



# Enable PSRemoting on the host:
Enable-PSRemoting -SkipNetworkProfileCheck

# 