function New-NestedVm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$ParentDiskPath,
        [Parameter(Mandatory)] [string]$ChildDiskPath,
        [Parameter(Mandatory)] [string]$SwitchName,
        [Parameter(Mandatory)] [UInt64]$MemoryStartupBytes,
        [Parameter(Mandatory)] [int]$ProcessorCount,
        [ValidateSet('Windows', 'Linux')] [string]$OsType = 'Windows',
        [switch]$UseDifferencingDisk,
        [switch]$ExposeVirtualizationExtensions
    )

    $existing = Get-VM -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  $Name already exists — skipping"
        return $existing
    }

    $parentExtension = [System.IO.Path]::GetExtension($ParentDiskPath)
    if (-not (Test-Path $ParentDiskPath)) {
        throw "Parent disk not found: $ParentDiskPath"
    }

    if ($UseDifferencingDisk) {
        if (-not (Test-Path $ChildDiskPath)) {
            Write-Host "  Creating differencing disk for $Name"
            New-VHD -Path $ChildDiskPath -ParentPath $ParentDiskPath -Differencing | Out-Null
        }
    }
    else {
        if (-not (Test-Path $ChildDiskPath)) {
            Write-Host "  Copying base disk for $Name"
            Copy-Item $ParentDiskPath $ChildDiskPath -Force
        }
    }

    New-VM -Name $Name `
        -Generation 2 `
        -VHDPath $ChildDiskPath `
        -SwitchName $SwitchName `
        -MemoryStartupBytes $MemoryStartupBytes | Out-Null

    Set-VM -Name $Name `
        -ProcessorCount $ProcessorCount `
        -DynamicMemory `
        -MemoryMinimumBytes 1GB `
        -MemoryMaximumBytes $MemoryStartupBytes `
        -AutomaticStartAction Start `
        -AutomaticStopAction ShutDown

    if ($ExposeVirtualizationExtensions) {
        Set-VMProcessor -VMName $Name -ExposeVirtualizationExtensions $true
    }

    if ($OsType -eq 'Linux') {
        Set-VMFirmware -VMName $Name -EnableSecureBoot Off
    }

    Start-VM -Name $Name | Out-Null
    Write-Host "  Created and started: $Name"
    return Get-VM -Name $Name
}
