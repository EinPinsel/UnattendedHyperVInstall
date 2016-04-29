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