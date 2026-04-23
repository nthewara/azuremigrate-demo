$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$labPath = "C:\AzureMigrateLab"
$configPath = "$labPath\lab-config.json"
if (-not (Test-Path $configPath)) {
    throw "Lab config not found: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
. "$labPath\scripts\New-NestedVm.ps1"

Start-Transcript -Path "$labPath\Logs\Continue-HyperVHostSetup.log" -Append

Write-Host "=== Azure Migrate Demo — Continue Hyper-V Host Setup ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

function Get-PrefixLength {
    param([string]$Cidr)
    return [int]($Cidr.Split('/')[-1])
}

function Download-File {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$Destination,
        [switch]$PreferAzCopy
    )

    if (Test-Path $Destination) {
        Write-Host "  Exists: $Destination"
        return
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Write-Host "  Downloading $(Split-Path $Destination -Leaf)..."

    if ($PreferAzCopy -and (Get-Command azcopy -ErrorAction SilentlyContinue)) {
        & azcopy cp $Url $Destination --check-length=false --log-level=ERROR
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Destination)) {
            return
        }
        Write-Warning "azcopy failed for $Url — falling back to Invoke-WebRequest"
    }

    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

Write-Host "[1/5] Configuring nested networking (switch, gateway, NAT, DHCP)..."
$prefixLength = Get-PrefixLength -Cidr $config.NestedSubnetCidr
$switch = Get-VMSwitch -Name $config.SwitchName -ErrorAction SilentlyContinue
if (-not $switch) {
    New-VMSwitch -Name $config.SwitchName -SwitchType Internal | Out-Null
    Write-Host "  Created switch $($config.SwitchName)"
}

$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*$($config.SwitchName)*" } | Select-Object -First 1
if (-not $adapter) {
    throw "Unable to find host adapter for switch $($config.SwitchName)"
}

$existingIp = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $config.NestedGatewayIp }
if (-not $existingIp) {
    New-NetIPAddress -IPAddress $config.NestedGatewayIp -PrefixLength $prefixLength -InterfaceIndex $adapter.ifIndex | Out-Null
    Write-Host "  Assigned gateway $($config.NestedGatewayIp)/$prefixLength"
}

$nat = Get-NetNat -Name $config.NATName -ErrorAction SilentlyContinue
if (-not $nat) {
    New-NetNat -Name $config.NATName -InternalIPInterfaceAddressPrefix $config.NestedSubnetCidr | Out-Null
    Write-Host "  Created NAT $($config.NATName)"
}

$scopeName = 'AzureMigrateLab'
$scope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object Name -eq $scopeName
if (-not $scope) {
    Add-DhcpServerv4Scope -Name $scopeName -StartRange $config.DhcpStart -EndRange $config.DhcpEnd -SubnetMask '255.255.255.0' -LeaseDuration 1.00:00:00 -State Active | Out-Null
    Set-DhcpServerv4OptionValue -ComputerName localhost -DnsServer 168.63.129.16 -Router $config.NestedGatewayIp -Force | Out-Null
    Write-Host "  DHCP scope configured"
}

$baseImageDir = Join-Path $config.VMDir 'BaseImages'
$childDiskDir = Join-Path $config.VMDir 'ChildDisks'
New-Item -ItemType Directory -Path $baseImageDir, $childDiskDir -Force | Out-Null

Write-Host "[2/5] Downloading reusable base images..."
$baseImages = @{
    Windows2022    = Join-Path $baseImageDir 'ArcBox-Win2K22.vhdx'
    Sql2022        = Join-Path $baseImageDir 'ArcBox-SQL-DEV.vhdx'
    Ubuntu2204     = Join-Path $baseImageDir 'ArcBox-Ubuntu-01.vhdx'
    MigratePackage = Join-Path $baseImageDir 'AzureMigrateAppliance.zip'
}
Download-File -Url $config.WindowsTemplateVhdUrl -Destination $baseImages.Windows2022 -PreferAzCopy
Download-File -Url $config.SqlTemplateVhdUrl -Destination $baseImages.Sql2022 -PreferAzCopy
Download-File -Url $config.LinuxTemplateVhdUrl -Destination $baseImages.Ubuntu2204 -PreferAzCopy
Download-File -Url $config.MigrateApplianceVhdUrl -Destination $baseImages.MigratePackage

function Import-MigrateAppliance {
    param(
        [Parameter(Mandatory)] [string]$ZipPath,
        [Parameter(Mandatory)] [string]$VmDir,
        [Parameter(Mandatory)] [string]$SwitchName
    )

    if (Get-VM -Name 'MIG-APPL' -ErrorAction SilentlyContinue) {
        Write-Host "  MIG-APPL already exists — skipping appliance import"
        return
    }

    $extractDir = Join-Path $baseImageDir 'AzureMigrateAppliance'
    if (-not (Test-Path $extractDir)) {
        Expand-Archive -Path $ZipPath -DestinationPath $extractDir -Force
    }

    $configFile = Get-ChildItem $extractDir -Recurse -Include *.vmcx,*.xml -File | Select-Object -First 1
    if (-not $configFile) {
        Write-Warning "Could not find an importable Hyper-V appliance config in $extractDir. Import MIG-APPL manually from the extracted package."
        return
    }

    $imported = Import-VM -Path $configFile.FullName -Copy -GenerateNewId -VirtualMachinePath (Join-Path $VmDir 'ImportedVMs') -VhdDestinationPath (Join-Path $VmDir 'ImportedDisks') -ErrorAction Stop
    Rename-VM -VM $imported -NewName 'MIG-APPL'
    Connect-VMNetworkAdapter -VMName 'MIG-APPL' -SwitchName $SwitchName -ErrorAction SilentlyContinue
    Start-VM -Name 'MIG-APPL' | Out-Null
    Write-Host "  Imported and started MIG-APPL"
}

$desktopPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
@"
Write-Host '=== Azure Migrate Demo Lab Status ===' -ForegroundColor Cyan
Get-VM | Sort-Object Name | Format-Table Name, State, CPUUsage, @{N='Memory(MB)';E={[math]::Round(`$_.MemoryAssigned/1MB)}}, Uptime -AutoSize
Write-Host ''
Write-Host 'Base images:' -ForegroundColor Yellow
Get-ChildItem 'F:\Virtual Machines\BaseImages' | Select-Object Name, Length
Write-Host ''
Write-Host 'Windows guest template password: Administrator / $($config.WindowsGuestAdminPassword)'
Write-Host 'Linux guest template password: $($config.LinuxGuestUsername) / $($config.LinuxGuestPassword)'
pause
"@ | Out-File "$desktopPath\AzureMigrateLab-Status.ps1" -Encoding utf8

Write-Host "[3/5] Creating nested VMs from sysprepped templates..."
Import-MigrateAppliance -ZipPath $baseImages.MigratePackage -VmDir $config.VMDir -SwitchName $config.SwitchName

$vmSpecs = @(
    @{ Name='APP01'; Parent=$baseImages.Windows2022; Child=(Join-Path $childDiskDir 'APP01.vhdx'); Memory=4GB; CPU=2; Os='Windows'; Diff=$true },
    @{ Name='WEB01'; Parent=$baseImages.Windows2022; Child=(Join-Path $childDiskDir 'WEB01.vhdx'); Memory=4GB; CPU=2; Os='Windows'; Diff=$true },
    @{ Name='SQL01'; Parent=$baseImages.Sql2022; Child=(Join-Path $childDiskDir 'SQL01.vhdx'); Memory=8GB; CPU=2; Os='Windows'; Diff=$true },
    @{ Name='LNX01'; Parent=$baseImages.Ubuntu2204; Child=(Join-Path $childDiskDir 'LNX01.vhdx'); Memory=4GB; CPU=2; Os='Linux'; Diff=$true }
)

foreach ($vm in $vmSpecs) {
    New-NestedVm -Name $vm.Name -ParentDiskPath $vm.Parent -ChildDiskPath $vm.Child -SwitchName $config.SwitchName -MemoryStartupBytes $vm.Memory -ProcessorCount $vm.CPU -OsType $vm.Os -UseDifferencingDisk:([bool]$vm.Diff)
}

$vmSpecs | ConvertTo-Json -Depth 4 | Out-File "$labPath\vm-specs.json" -Encoding utf8

Write-Host "[4/5] Waiting for guests to settle..."
Start-Sleep -Seconds 120

$vmAddresses = @{}
foreach ($vmName in @('MIG-APPL') + ($vmSpecs | ForEach-Object { $_.Name })) {
    $ips = (Get-VMNetworkAdapter -VMName $vmName -ErrorAction SilentlyContinue).IPAddresses |
        Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }
    $vmAddresses[$vmName] = @($ips)
    Write-Host "  ${vmName} -> $($ips -join ', ')"
}
$vmAddresses | ConvertTo-Json -Depth 4 | Out-File "$labPath\guest-addresses.json" -Encoding utf8

Write-Host "[5/5] Configuring Windows guest workloads via PowerShell Direct..."
powershell.exe -ExecutionPolicy Bypass -File "$labPath\scripts\Configure-GuestWorkloads.ps1"

Unregister-ScheduledTask -TaskName "AzureMigrateLab-ContinueSetup" -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Azure Migrate lab host setup complete." -ForegroundColor Green
Write-Host "Next: open Hyper-V Manager, finish appliance registration, and install dependency agents on APP01/WEB01/SQL01."
Stop-Transcript
