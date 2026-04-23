$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$labPath = "C:\AzureMigrateLab"
$config = Get-Content "$labPath\lab-config.json" -Raw | ConvertFrom-Json

Start-Transcript -Path "$labPath\Logs\Configure-GuestWorkloads.log" -Append
Write-Host "=== Azure Migrate Demo — Configure Guest Workloads ===" -ForegroundColor Cyan

$securePassword = ConvertTo-SecureString $config.WindowsGuestAdminPassword -AsPlainText -Force
$windowsCred = [pscredential]::new("Administrator", $securePassword)
$windowsGuests = @('APP01', 'WEB01', 'SQL01')

function Wait-PowerShellDirect {
    param(
        [Parameter(Mandatory)] [string]$VmName,
        [int]$Attempts = 40,
        [int]$DelaySeconds = 20
    )

    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            Invoke-Command -VMName $VmName -Credential $windowsCred -ScriptBlock { 'ready' } -ErrorAction Stop | Out-Null
            Write-Host "  PowerShell Direct ready: $VmName"
            return
        }
        catch {
            Write-Host "  Waiting for $VmName ($i/$Attempts)..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw "PowerShell Direct never became ready for $VmName"
}

function Invoke-InGuest {
    param(
        [Parameter(Mandatory)] [string]$VmName,
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @()
    )

    Invoke-Command -VMName $VmName -Credential $windowsCred -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ErrorAction Stop
}

Write-Host "[1/5] Waiting for Windows guests..."
foreach ($guest in $windowsGuests) {
    Wait-PowerShellDirect -VmName $guest
}

Write-Host "[2/5] Renaming/configuring APP01, WEB01, SQL01..."
foreach ($guest in $windowsGuests) {
    Invoke-InGuest -VmName $guest -ScriptBlock {
        param($DesiredName)
        Set-TimeZone -Id 'W. Australia Standard Time' -ErrorAction SilentlyContinue
        Enable-PSRemoting -Force
        Set-NetFirewallRule -DisplayGroup 'Remote Desktop' -Enabled True -ErrorAction SilentlyContinue

        if ($env:COMPUTERNAME -ne $DesiredName) {
            Rename-Computer -NewName $DesiredName -Force
            Restart-Computer -Force
        }
    } -ArgumentList @($guest)
}

Start-Sleep -Seconds 90
foreach ($guest in $windowsGuests) {
    Wait-PowerShellDirect -VmName $guest
}

Write-Host "[3/5] Installing demo roles and sample content..."
Invoke-InGuest -VmName 'APP01' -ScriptBlock {
    Install-WindowsFeature Web-Server -IncludeManagementTools | Out-Null
    Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value '<html><body><h1>APP01</h1><p>Azure Migrate demo app tier</p></body></html>'
}

Invoke-InGuest -VmName 'WEB01' -ScriptBlock {
    Install-WindowsFeature Web-Server -IncludeManagementTools | Out-Null
    Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value '<html><body><h1>WEB01</h1><p>Azure Migrate demo web/helper tier</p></body></html>'
}

Invoke-InGuest -VmName 'SQL01' -ScriptBlock {
    Set-NetFirewallRule -DisplayGroup 'SQL Server' -Enabled True -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName 'Allow SQL 1433' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -ErrorAction SilentlyContinue | Out-Null

    $sqlcmd = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
    if ($sqlcmd) {
        & $sqlcmd.Path -Q "IF DB_ID('AzureMigrateDemo') IS NULL CREATE DATABASE AzureMigrateDemo;"
    }
}

Write-Host "[4/5] Building guest host mappings..."
$guestIps = @{}
foreach ($guest in $windowsGuests + 'LNX01') {
    $ip = (Get-VMNetworkAdapter -VMName $guest -ErrorAction SilentlyContinue).IPAddresses |
        Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
        Select-Object -First 1
    if ($ip) { $guestIps[$guest] = $ip }
}
$guestIps | ConvertTo-Json | Out-File "$labPath\guest-addresses.json" -Encoding utf8

$hostEntries = ($guestIps.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0}`t{1}" -f $_.Value, $_.Name }) -join "`r`n"
foreach ($guest in $windowsGuests) {
    Invoke-InGuest -VmName $guest -ScriptBlock {
        param($Entries)
        $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
        $current = Get-Content $hostsPath -Raw
        foreach ($line in ($Entries -split "`r?`n")) {
            if ($line -and $current -notmatch [regex]::Escape($line)) {
                Add-Content -Path $hostsPath -Value $line
            }
        }
    } -ArgumentList @($hostEntries)
}

Write-Host "[5/5] Installing light traffic generators for dependency demos..."
$trafficScript = @'
$targets = @(
    @{ Name = "WEB01"; Url = "http://WEB01/" },
    @{ Name = "SQL01"; Port = 1433 }
)
foreach ($target in $targets) {
    try {
        if ($target.Url) {
            Invoke-WebRequest -Uri $target.Url -UseBasicParsing -TimeoutSec 10 | Out-Null
        }
        elseif ($target.Port) {
            Test-NetConnection -ComputerName $target.Name -Port $target.Port -InformationLevel Quiet | Out-Null
        }
    }
    catch {
    }
}
'@

Invoke-InGuest -VmName 'APP01' -ScriptBlock {
    param($Content)
    $path = 'C:\AzureMigrateDemo'
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Content -Path "$path\Invoke-DemoTraffic.ps1" -Value $Content
    schtasks /Create /TN 'AzureMigrateDemoTraffic' /TR "powershell.exe -ExecutionPolicy Bypass -File C:\AzureMigrateDemo\Invoke-DemoTraffic.ps1" /SC MINUTE /MO 5 /RU SYSTEM /F | Out-Null
} -ArgumentList @($trafficScript)

Write-Host "Guest workload configuration complete." -ForegroundColor Green
Stop-Transcript
