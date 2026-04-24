param(
    [string]$LabPath                    = "C:\AzureMigrateLab",
    [string]$VMDir                      = "F:\Virtual Machines",
    [string]$SwitchName                 = "AzureMigrateSwitch",
    [string]$NATName                    = "AzureMigrateNAT",
    [string]$NestedSubnetCidr           = "10.10.1.0/24",
    [string]$NestedGatewayIp            = "10.10.1.1",
    [string]$DhcpStart                  = "10.10.1.100",
    [string]$DhcpEnd                    = "10.10.1.200",
    [string]$WindowsTemplateVhdUrl      = "https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-Win2K22.vhdx",
    [string]$SqlTemplateVhdUrl          = "https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-SQL-DEV.vhdx",
    [string]$LinuxTemplateVhdUrl        = "https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/ArcBox-Ubuntu-01.vhdx",
    [string]$MigrateApplianceVhdUrl     = "https://go.microsoft.com/fwlink/?linkid=2191848",
    [string]$WindowsGuestAdminPassword  = "ArcDemo123!!",
    [string]$LinuxGuestUsername         = "jumpstart",
    [string]$LinuxGuestPassword         = "JS123!!"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

New-Item -ItemType Directory -Path $LabPath -Force | Out-Null
New-Item -ItemType Directory -Path "$LabPath\Logs" -Force | Out-Null
New-Item -ItemType Directory -Path "$LabPath\scripts" -Force | Out-Null

Start-Transcript -Path "$LabPath\Logs\Bootstrap-HyperVHost.log" -Append

Write-Host "=== Azure Migrate Demo -- Hyper-V Host Bootstrap ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host "[1/6] Initialising nested VM data disk..."
$rawDisk = Get-Disk | Where-Object PartitionStyle -eq 'raw' | Select-Object -First 1
$existingF = Get-Volume -DriveLetter F -ErrorAction SilentlyContinue

if ($rawDisk) {
    $rawDisk | Initialize-Disk -PartitionStyle GPT -PassThru |
        New-Partition -UseMaximumSize -DriveLetter F |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "NestedVMs" -Confirm:$false -Force
    Write-Host "  Data disk formatted as F:"
}
elseif ($existingF) {
    Write-Host "  Data disk already available as F:"
}
else {
    Write-Warning "No RAW disk found and F: is not present. Nested VM storage may fail."
}
New-Item -ItemType Directory -Path $VMDir -Force | Out-Null

Write-Host "[2/6] Installing Hyper-V and DHCP roles..."
$features = @('Hyper-V', 'DHCP', 'RSAT-Hyper-V-Tools', 'RSAT-DHCP')
$rebootNeeded = $false
foreach ($featureName in $features) {
    $feature = Get-WindowsFeature -Name $featureName
    if (-not $feature.Installed) {
        $result = Install-WindowsFeature -Name $featureName -IncludeManagementTools
        if ($result.RestartNeeded -eq 'Yes') {
            $rebootNeeded = $true
        }
        Write-Host "  Installed: $featureName"
    }
    else {
        Write-Host "  Already installed: $featureName"
    }
}

Write-Host "[3/6] Installing prerequisites (Azure CLI + azcopy)..."
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri "https://aka.ms/installazurecliwindowsx64" -OutFile "$env:TEMP\AzureCLI.msi"
    Start-Process msiexec.exe -ArgumentList "/i `"$env:TEMP\AzureCLI.msi`" /qn /norestart" -Wait
    $env:PATH += ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
    Write-Host "  Azure CLI installed"
}
else {
    Write-Host "  Azure CLI already installed"
}

if (-not (Get-Command azcopy -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile "$env:TEMP\azcopy.zip"
    Expand-Archive -Path "$env:TEMP\azcopy.zip" -DestinationPath "$env:TEMP\azcopy" -Force
    $azcopyExe = Get-ChildItem "$env:TEMP\azcopy" -Recurse -Filter azcopy.exe | Select-Object -First 1
    Copy-Item $azcopyExe.FullName "C:\Windows\System32\azcopy.exe" -Force
    Write-Host "  azcopy installed"
}
else {
    Write-Host "  azcopy already installed"
}

Write-Host "[4/6] Saving lab configuration..."
$labConfig = [ordered]@{
    LabPath                   = $LabPath
    VMDir                     = $VMDir
    SwitchName                = $SwitchName
    NATName                   = $NATName
    NestedSubnetCidr          = $NestedSubnetCidr
    NestedGatewayIp           = $NestedGatewayIp
    DhcpStart                 = $DhcpStart
    DhcpEnd                   = $DhcpEnd
    WindowsTemplateVhdUrl     = $WindowsTemplateVhdUrl
    SqlTemplateVhdUrl         = $SqlTemplateVhdUrl
    LinuxTemplateVhdUrl       = $LinuxTemplateVhdUrl
    MigrateApplianceVhdUrl    = $MigrateApplianceVhdUrl
    WindowsGuestAdminPassword = $WindowsGuestAdminPassword
    LinuxGuestUsername        = $LinuxGuestUsername
    LinuxGuestPassword        = $LinuxGuestPassword
}
$labConfig | ConvertTo-Json -Depth 4 | Out-File "$LabPath\lab-config.json" -Encoding utf8

Write-Host "[5/6] Copying continuation scripts..."
$scriptSource = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($scriptName in @('Continue-HyperVHostSetup.ps1', 'New-NestedVm.ps1', 'Configure-GuestWorkloads.ps1')) {
    $sourcePath = Join-Path $scriptSource $scriptName
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath "$LabPath\scripts\$scriptName" -Force
        Write-Host "  Copied $scriptName"
    }
    else {
        throw "Required script not found: $sourcePath"
    }
}

Write-Host "[6/6] Registering continuation task..."
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $LabPath\scripts\Continue-HyperVHostSetup.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Seconds 45)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "AzureMigrateLab-ContinueSetup" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

Write-Host "Bootstrap complete. Rebooting host to finish Hyper-V installation..." -ForegroundColor Green
Stop-Transcript
Restart-Computer -Force
exit 0
