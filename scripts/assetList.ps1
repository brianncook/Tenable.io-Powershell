####
#
# Description: Script to demonstrate using Tenable.io API's.
# 
# Use at your own risk. Script is not supported by Tenable.
#
# Version: .1 Initial Script October 12, 2018
#            
####

# Module needed
Import-Module PSExcel

# Import configuration settings
# 
[xml]$ConfigFile = Get-Content /Users/bcook/Desktop/Powershell/tenable_io.xml
#[xml]$ConfigFile = Get-Content C:\{path_to_file}\tenable_io.xml
$Tenableio = $ConfigFile.Settings.Access.Url
$access = $ConfigFile.Settings.Access.AccessKey
$secret = $ConfigFile.Settings.Access.SecretKey
$excelfile = "/Users/bcook/Desktop/Powershell/assets.XLSX"

# Header
$headers = "accessKey=$access; secretKey=$secret"
Set-Location /Users/bcook/Desktop/Powershell

$object = "assets"
$response = Invoke-RestMethod -Method Get -Uri $Tenableio/$object -Header @{ "X-ApiKeys" = $headers }
$assets = $($response.assets | select id, has_agent, last_seen, sources, ipv4, ipv6, fqdn, netbios_name, operating_system, agent_name, aws_ec2_name, mac_address)
$response.assets | select id, has_agent, last_seen,
@{Name='sources';Expression={[string]::join(";",($_.sources))}},
@{Name='ipv4';Expression={[string]::join(";",($_.ipv4))}},
@{Name='ipv6';Expression={[string]::join(";",($_.ipv6))}},
@{Name='fqdn';Expression={[string]::join(";",($_.fqdn))}},
@{Name='netbios_name';Expression={[string]::join(";",($_.netbios_name))}},
@{Name='operating_system';Expression={[string]::join(";",($_.operating_system))}},
@{Name='agent_name';Expression={[string]::join(";",($_.agent_name))}},
@{Name='aws_ec2_name';Expression={[string]::join(";",($_.aws_ec2_name))}},
@{Name='mac_address';Expression={[string]::join(";",($_.mac_address))}} | Export-Csv $excelfile -notype
