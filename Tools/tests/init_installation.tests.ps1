$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot '..\init_installation.ps1'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('rime installation tests ' + [Guid]::NewGuid().ToString('N'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.Directory]::CreateDirectory($sandbox) | Out-Null
$global:RimeInstallationTestState = @{
    RemoteFile = Join-Path $sandbox 'remote.yaml'
    Settings = @{}
    AdbCalls = New-Object 'System.Collections.Generic.List[string]'
    PushCount = 0
    FailPush = $false
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-FieldValue {
    param([string]$Path, [string]$Key)
    $match = [regex]::Match([IO.File]::ReadAllText($Path), ('(?m)^' + [regex]::Escape($Key) + ':\s*([^\r\n]+)'))
    Assert-True $match.Success "Missing installation field: $Key"
    $value = $match.Groups[1].Value.Trim()
    if ($value.StartsWith('"')) { return ($value | ConvertFrom-Json) }
    return $value.Trim("'")
}

function Assert-CompleteInstallation {
    param([string]$Path, [string]$DeviceName, [string]$Distribution, [string]$SyncDir)
    foreach ($key in @('distribution_code_name', 'distribution_name', 'distribution_version', 'install_time', 'rime_version', 'name', 'installation_id', 'sync_dir')) {
        Assert-True ([bool](Get-FieldValue $Path $key)) "Empty installation field: $key"
    }
    Assert-True ((Get-FieldValue $Path 'name') -ceq $DeviceName) 'Device name mismatch.'
    Assert-True ((Get-FieldValue $Path 'installation_id') -ceq $DeviceName) 'Installation ID mismatch.'
    Assert-True ((Get-FieldValue $Path 'distribution_code_name') -ceq $Distribution) 'Distribution mismatch.'
    Assert-True ((Get-FieldValue $Path 'sync_dir') -ceq $SyncDir) 'Sync directory mismatch.'
}

function adb {
    $arguments = @($args)
    $command = $arguments -join ' '
    $state = $global:RimeInstallationTestState
    $state.AdbCalls.Add($command)
    $global:LASTEXITCODE = 0
    if ($command -match '^shell settings get (secure|system|global) bluetooth_name$' -or $command -eq 'shell settings get system device_name' -or $command -eq 'shell getprop persist.sys.device_name' -or $command -match '^shell getprop ro\.product\.(model|marketname|vendor\.marketname|odm\.marketname)$') {
        if ($state.Settings.ContainsKey($command)) { return $state.Settings[$command] }
        return 'null'
    }
    if ($arguments[0] -eq 'shell' -and $arguments[1].StartsWith('if [')) {
        if (Test-Path -LiteralPath $state.RemoteFile) { return 'FILE' }
        return 'MISSING'
    }
    if ($arguments[0] -eq 'pull') {
        Copy-Item -LiteralPath $state.RemoteFile -Destination $arguments[2] -WhatIf:$false
        return
    }
    if ($arguments[0] -eq 'push') {
        if ($state.FailPush) {
            $global:LASTEXITCODE = 1
            return
        }
        Copy-Item -LiteralPath $arguments[1] -Destination $state.RemoteFile
        $state.PushCount++
        return
    }
    if ($command -eq 'shell mkdir -p /sdcard/rime') { return }
    throw "Unexpected adb command: $command"
}

function Invoke-Helper {
    param([hashtable]$Parameters, [bool]$ShouldFail = $false)
    $global:LASTEXITCODE = 0
    $output = & $helper @Parameters 2>&1
    $failed = $LASTEXITCODE -ne 0
    Assert-True ($failed -eq $ShouldFail) ("Unexpected helper result: " + ($output -join "`n"))
}

try {
    $state = $global:RimeInstallationTestState
    $metadata = "distribution_name: Trime`nsync_dir: `"/sdcard/com.hxlh/Rime`"`ninstallation_id: `"OLD`"`nrime_version: 1.15.0`n"
    $state.Settings['shell settings get secure bluetooth_name'] = 'HXLHSP08'
    $state.Settings['shell getprop persist.sys.device_name'] = 'HXLHSP8'
    [IO.File]::WriteAllText($state.RemoteFile, $metadata, $utf8)
    Invoke-Helper @{ Platform = 'Android' }
    $expected = [IO.File]::ReadAllText($state.RemoteFile)
    Assert-True ($expected.StartsWith($metadata.Replace('"OLD"', '"HXLHSP08"'))) 'Android metadata or ID mismatch.'
    Assert-CompleteInstallation $state.RemoteFile 'HXLHSP08' 'trime' '/sdcard/com.hxlh/Rime'
    $nameQueries = @($state.AdbCalls | Where-Object { $_ -like 'shell settings get *' })
    Assert-True ($nameQueries[0] -eq 'shell settings get secure bluetooth_name') 'Custom Bluetooth name must be queried first among name sources.'
    Assert-True (-not ($state.AdbCalls -contains 'shell getprop persist.sys.device_name')) 'Stale property was queried despite a custom Bluetooth name.'
    'PASS: custom name takes precedence and other installation fields are preserved.'

    Invoke-Helper @{ Platform = 'Android'; WhatIf = $true }
    Assert-True ($state.PushCount -eq 1) 'WhatIf pushed to Android.'
    Assert-True ([IO.File]::ReadAllText($state.RemoteFile) -ceq $expected) 'WhatIf changed Android metadata.'
    'PASS: WhatIf never pushes.'

    $state.Settings['shell settings get secure bluetooth_name'] = 'HXLHSP0B'
    $state.Settings['shell getprop persist.sys.device_name'] = 'Xiaomi 17 Pro'
    $state.Settings['shell getprop ro.product.model'] = '25098PN5AC'
    $state.Settings['shell getprop ro.product.marketname'] = 'Xiaomi 17 Pro'
    $state.Settings['shell getprop ro.product.odm.marketname'] = 'Xiaomi 17 Pro'
    $wrongMetadata = $expected.Replace('HXLHSP08', 'Xiaomi 17 Pro')
    [IO.File]::WriteAllText($state.RemoteFile, $wrongMetadata, $utf8)
    Invoke-Helper @{ Platform = 'Android' }
    Assert-CompleteInstallation $state.RemoteFile 'HXLHSP0B' 'trime' '/sdcard/com.hxlh/Rime'
    Assert-True ([IO.File]::ReadAllText($state.RemoteFile) -ceq $wrongMetadata.Replace('Xiaomi 17 Pro', 'HXLHSP0B')) 'Repair changed unrelated metadata.'
    'PASS: Xiaomi 17 Pro uses HXLHSP0B and repairs both stored name fields.'

    foreach ($bluetoothName in @('null', 'Xiaomi 17 Pro', '25098PN5AC')) {
        $state.Settings['shell settings get secure bluetooth_name'] = $bluetoothName
        $before = [IO.File]::ReadAllText($state.RemoteFile)
        $pushCount = $state.PushCount
        Invoke-Helper @{ Platform = 'Android' } -ShouldFail $true
        Assert-True ($state.PushCount -eq $pushCount) 'Product/model name was pushed as a custom name.'
        Assert-True ([IO.File]::ReadAllText($state.RemoteFile) -ceq $before) 'Rejected model name changed metadata.'
    }
    $state.Settings['shell settings get secure bluetooth_name'] = 'Xiaomi 17 Pro'
    $state.Settings['shell getprop persist.sys.device_name'] = 'HXLHSP0B'
    Invoke-Helper @{ Platform = 'Android' }
    Assert-CompleteInstallation $state.RemoteFile 'HXLHSP0B' 'trime' '/sdcard/com.hxlh/Rime'
    'PASS: model-only sources fail without writing; a custom fallback can replace a default Bluetooth name.'

    $state.Settings.Clear()
    $state.Settings['shell settings get secure bluetooth_name'] = 'HXLHSP08'
    $state.Settings['shell getprop persist.sys.device_name'] = 'HXLHSP8'
    Remove-Item -LiteralPath $state.RemoteFile
    Invoke-Helper @{ Platform = 'Android' }
    Assert-CompleteInstallation $state.RemoteFile 'HXLHSP08' 'trime' '/sdcard/com.hxlh/Rime'
    Assert-True ((Get-FieldValue $state.RemoteFile 'distribution_name') -ceq 'Trime') 'Android distribution name mismatch.'
    'PASS: missing Android installation file includes all metadata.'

    $state.Settings.Remove('shell settings get secure bluetooth_name')
    Invoke-Helper @{ Platform = 'Android' }
    Assert-CompleteInstallation $state.RemoteFile 'HXLHSP8' 'trime' '/sdcard/com.hxlh/Rime'
    $state.Settings.Clear()
    $pushCount = $state.PushCount
    Invoke-Helper @{ Platform = 'Android' } -ShouldFail $true
    Assert-True ($state.PushCount -eq $pushCount) 'Missing custom name still pushed a file.'
    'PASS: custom property fallback works; missing custom name fails without using a model.'

    $state.Settings['shell settings get secure bluetooth_name'] = 'Name & ! $ Test'
    Invoke-Helper @{ Platform = 'Android' }
    Assert-CompleteInstallation $state.RemoteFile 'Name & ! $ Test' 'trime' '/sdcard/com.hxlh/Rime'
    $state.Settings['shell settings get secure bluetooth_name'] = '../unsafe'
    $pushCount = $state.PushCount
    Invoke-Helper @{ Platform = 'Android' } -ShouldFail $true
    Assert-True ($state.PushCount -eq $pushCount) 'Unsafe device name was written.'
    'PASS: shell metacharacters remain data; unsafe path characters are rejected.'

    $state.Settings['shell settings get secure bluetooth_name'] = 'HXLHSP08'
    $state.FailPush = $true
    Invoke-Helper @{ Platform = 'Android' } -ShouldFail $true
    $state.FailPush = $false
    'PASS: adb push failure is reported.'

    $windowsDirectory = Join-Path $sandbox 'Windows config'
    $windowsFile = Join-Path $windowsDirectory 'installation.yaml'
    Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory }
    $entry = 'installation_id: "' + [Environment]::MachineName + '"'
    Assert-CompleteInstallation $windowsFile ([Environment]::MachineName) 'Weasel' (Join-Path $env:APPDATA 'RimeSync')
    Assert-True ((Get-FieldValue $windowsFile 'distribution_name') -ceq (-join ([char[]]@(0x5c0f, 0x72fc, 0x6beb)))) 'Windows distribution name mismatch.'
    $windowsMetadata = "distribution_name: ExistingName`r`ndistribution_version: 9.0`r`nrime_version: 8.0`r`ninstall_time: OriginalTime`r`nsync_dir: 'C:\RimeSync'`r`ninstallation_id: OLD`r`ncustom_field: keep`r`n"
    [IO.File]::WriteAllText($windowsFile, $windowsMetadata, $utf8)
    Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory }
    Assert-True ([IO.File]::ReadAllText($windowsFile).StartsWith($windowsMetadata.Replace('installation_id: OLD', $entry))) 'Windows metadata or CRLF changed.'
    $withoutId = "sync_dir: 'C:\RimeSync'`r`nrime_version: 1.13.1`r`n"
    [IO.File]::WriteAllText($windowsFile, $withoutId, $utf8)
    Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory }
    Assert-True ([IO.File]::ReadAllText($windowsFile).StartsWith($withoutId)) 'Missing ID did not preserve existing fields.'
    Assert-CompleteInstallation $windowsFile ([Environment]::MachineName) 'Weasel' 'C:\RimeSync'
    'PASS: Windows creates complete metadata and preserves existing fields and CRLF.'

    $syncPaths = @('D:\Rime Sync\User & ! Files', '\\server\share\Rime Sync')
    foreach ($syncPath in $syncPaths) {
        Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory; SyncDir = $syncPath }
        Assert-CompleteInstallation $windowsFile ([Environment]::MachineName) 'Weasel' $syncPath
    }
    $androidSync = '/sdcard/My Sync & ! Files'
    Invoke-Helper @{ Platform = 'Android'; SyncDir = $androidSync }
    Assert-CompleteInstallation $state.RemoteFile 'HXLHSP08' 'trime' $androidSync
    $before = [IO.File]::ReadAllText($state.RemoteFile)
    Invoke-Helper @{ Platform = 'Android'; SyncDir = '/sdcard/Preview'; WhatIf = $true }
    Assert-True ([IO.File]::ReadAllText($state.RemoteFile) -ceq $before) 'WhatIf changed sync_dir.'
    Invoke-Helper @{ Platform = 'Android'; SyncDir = 'C:\WrongPlatform' } -ShouldFail $true
    Assert-True ([IO.File]::ReadAllText($state.RemoteFile) -ceq $before) 'Invalid Android sync path changed metadata.'
    $before = [IO.File]::ReadAllText($windowsFile)
    Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory; SyncDir = '/sdcard/WrongPlatform' } -ShouldFail $true
    Assert-True ([IO.File]::ReadAllText($windowsFile) -ceq $before) 'Invalid Windows sync path changed metadata.'
    'PASS: explicit sync paths override old values, preserve special characters, and validate platform paths.'

    [IO.File]::WriteAllText($windowsFile, "name: null`nsync_dir: ''`ndistribution_name: `"`"`ninstall_time: ~`n", $utf8)
    Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory; DistributionVersion = '2.0'; RimeVersion = '3.0' }
    Assert-CompleteInstallation $windowsFile ([Environment]::MachineName) 'Weasel' (Join-Path $env:APPDATA 'RimeSync')
    Assert-True ((Get-FieldValue $windowsFile 'distribution_version') -ceq '2.0') 'Distribution version fallback mismatch.'
    Assert-True ((Get-FieldValue $windowsFile 'rime_version') -ceq '3.0') 'Rime version fallback mismatch.'
    $before = [IO.File]::ReadAllText($windowsFile)
    Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory }
    Assert-True ([IO.File]::ReadAllText($windowsFile) -ceq $before) 'Repeated initialization changed existing metadata.'
    'PASS: empty fields are repaired, version defaults are configurable, and repeated initialization is stable.'

    foreach ($invalid in @("installation_id: OLD`ninstallation_id: DUPLICATE`n", "installation_id: >`n  OLD`n", "sync_dir: 'C:\Old'`nsync_dir: 'C:\Duplicate'`n", "name: >`n  OLD`n")) {
        [IO.File]::WriteAllText($windowsFile, $invalid, $utf8)
        Invoke-Helper @{ Platform = 'Windows'; RimeDir = $windowsDirectory } -ShouldFail $true
        Assert-True ([IO.File]::ReadAllText($windowsFile) -ceq $invalid) 'Unsupported installation file was overwritten.'
    }
    'PASS: duplicate and multiline IDs fail without overwriting the file.'
} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force
    Remove-Variable -Name RimeInstallationTestState -Scope Global
}