param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$Stage,
    [Parameter(Mandatory=$true)][int]$GameProcessId
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
$Stage = [IO.Path]::GetFullPath($Stage).TrimEnd('\')
$statusPath = Join-Path $Stage 'status.txt'
$logPath = Join-Path $Stage 'update.log'
$lock = $null
$applied = [Collections.Generic.List[object]]::new()
$prepared = [Collections.Generic.List[object]]::new()

function Write-Status([string]$Value) {
    [IO.File]::WriteAllText($statusPath, $Value, [Text.Encoding]::ASCII)
}

function Get-Digest([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return '-' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

try {
    # CreateNew prevents two helpers from applying the same plan.
    $lock = [IO.File]::Open((Join-Path $Stage 'updater.lock'), 'CreateNew', 'Write', 'None')
} catch {
    exit 2
}

try {
    $game = Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue
    Write-Status 'WAITING'
    if ($null -ne $game) { $game.WaitForExit() }
    Write-Status 'APPLYING'

    $seen = @{}
    $lines = [IO.File]::ReadAllLines((Join-Path $Stage 'plan.tsv'))
    if ($lines.Count -eq 0) { throw 'Empty update plan' }
    foreach ($line in $lines) {
        $parts = $line.Split("`t")
        if ($parts.Length -ne 3) { throw 'Invalid plan row' }
        $relative, $expected, $previous = $parts
        if ($relative -cnotmatch '^lib/[A-Za-z0-9_/-]+\.(lua|dll)$' -or
            $relative.Contains('..') -or $relative.Contains('//') -or
            $expected -cnotmatch '^[0-9a-f]{64}$' -or
            $previous -cnotmatch '^(-|[0-9a-f]{64})$' -or $seen.ContainsKey($relative)) {
            throw "Invalid or duplicate path/hash: $relative"
        }
        $seen[$relative] = $true
        $target = Join-Path $Root $relative
        $source = Join-Path $Stage $relative
        if ((Get-Digest $source) -ne $expected) { throw "Download hash mismatch: $relative" }
        if ((Get-Digest $target) -ne $previous) { throw "Local file changed since approval: $relative" }
        $parent = Split-Path $target
        [IO.Directory]::CreateDirectory($parent) | Out-Null
        $backup = Join-Path (Join-Path $Stage 'backup') $relative
        if ($previous -ne '-') {
            [IO.Directory]::CreateDirectory((Split-Path $backup)) | Out-Null
            [IO.File]::Copy($target, $backup, $false)
            if ((Get-Digest $backup) -ne $previous) { throw "Backup hash mismatch: $relative" }
        }
        $temp = $target + '.checklogs-' + (Split-Path $Stage -Leaf) + '.new'
        [IO.File]::Copy($source, $temp, $false)
        $record = [pscustomobject]@{Target=$target; Temp=$temp; Backup=$backup; Previous=$previous; Expected=$expected}
        $prepared.Add($record)
        if ((Get-Digest $temp) -ne $expected) { throw "Prepared file hash mismatch: $relative" }
    }

    foreach ($file in $prepared) {
        if ((Get-Digest $file.Target) -ne $file.Previous) { throw "Local file changed before replacement: $($file.Target)" }
        if ($file.Previous -eq '-') {
            [IO.File]::Move($file.Temp, $file.Target)
        } else {
            [IO.File]::Replace($file.Temp, $file.Target, [NullString]::Value)
        }
        $applied.Add($file)
        if ((Get-Digest $file.Target) -ne $file.Expected) { throw "Installed file hash mismatch: $($file.Target)" }
    }
    "Updated $($applied.Count) files. Backups: $Stage\backup" | Out-File -LiteralPath $logPath -Encoding utf8
    Write-Status 'OK'
} catch {
    $failure = $_.Exception.ToString()
    $rollbackFailed = $false
    for ($i = $applied.Count - 1; $i -ge 0; $i--) {
        $file = $applied[$i]
        try {
            if ((Get-Digest $file.Target) -ne $file.Expected) { throw "File changed during rollback: $($file.Target)" }
            if ($file.Previous -eq '-') {
                [IO.File]::Delete($file.Target)
            } else {
                [IO.File]::Copy($file.Backup, $file.Temp, $true)
                [IO.File]::Replace($file.Temp, $file.Target, [NullString]::Value)
            }
        } catch {
            $rollbackFailed = $true
            $failure += "`r`nROLLBACK: " + $_.Exception.ToString()
        }
    }
    $failure | Out-File -LiteralPath $logPath -Encoding utf8
    if ($rollbackFailed) { Write-Status 'ROLLBACK_FAILED' } else { Write-Status 'FAILED' }
    exit 1
} finally {
    foreach ($file in $prepared) {
        if ([IO.File]::Exists($file.Temp)) { [IO.File]::Delete($file.Temp) }
    }
    if ($null -ne $lock) { $lock.Dispose() }
}
