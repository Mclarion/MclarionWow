# Read-only, aggregate-only calibration probe. Never executes SavedVariables Lua.
# Reads the stopped Forever client's MclarionWow.lua files in memory, never prints their paths
# or contents, and rejects anything outside the small data-only Lua subset.
# Repeated process checks and a read-only file handle cannot atomically prevent
# a user launching WoW between checks; the operator must keep all clients closed.
param([string]$ClientRoot)
$ErrorActionPreference = 'Stop'
$Limit = 3000000
$MaxFileBytes = 4194304
$MaxNodes = 50000
$MaxDepth = 8
$Utf8 = New-Object System.Text.UTF8Encoding($false, $true)

function Refuse { throw 'refused' }
function WoW-Running { return [bool](Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) }
function Skip-Space {
    while ($script:At -lt $script:Text.Length) {
        if ([char]::IsWhiteSpace($script:Text[$script:At])) { $script:At++; continue }
        if ($script:At + 2 -le $script:Text.Length -and
            $script:Text.Substring($script:At, 2) -ceq '--') {
            $script:At += 2
            if ($script:At -lt $script:Text.Length -and $script:Text[$script:At] -eq '[') { Refuse }
            while ($script:At -lt $script:Text.Length -and $script:Text[$script:At] -ne "`n") {
                $script:At++
            }
            continue
        }
        break
    }
}
function Need([string]$expected) {
    Skip-Space
    if ($script:At + $expected.Length -gt $script:Text.Length -or
        $script:Text.Substring($script:At, $expected.Length) -cne $expected) { Refuse }
    $script:At += $expected.Length
}
function Charge([long]$amount) {
    if ($amount -gt $script:Limit - $script:Projected) { Refuse }
    $script:Projected += $amount
}
function Node {
    $script:Nodes++
    if ($script:Nodes -gt $script:MaxNodes) { Refuse }
}
function Parse-StringLength {
    $quote = $script:Text[$script:At]
    if ($quote -ne '"' -and $quote -ne "'") { Refuse }
    $script:At++
    $start = $script:At
    [long]$length = 0
    while ($script:At -lt $script:Text.Length) {
        $char = $script:Text[$script:At]
        if ($char -eq $quote -or $char -eq '\') {
            $length += $script:Utf8.GetByteCount($script:Text.Substring($start, $script:At - $start))
            $script:At++
            if ($char -eq $quote) { return $length }
            if ($script:At -ge $script:Text.Length) { Refuse }
            $escape = $script:Text[$script:At]
            if ($escape -match '^[0-9]$') {
                $digits = 0
                $value = 0
                while ($digits -lt 3 -and $script:At -lt $script:Text.Length -and
                    $script:Text[$script:At] -match '^[0-9]$') {
                    $value = $value * 10 + [int]::Parse([string]$script:Text[$script:At])
                    $script:At++
                    $digits++
                }
                if ($value -gt 255) { Refuse }
                $length++
            } elseif ($escape -ceq 'x') {
                $script:At++
                if ($script:At + 2 -gt $script:Text.Length -or
                    $script:Text.Substring($script:At, 2) -cnotmatch '^[0-9a-fA-F]{2}$') { Refuse }
                $script:At += 2
                $length++
            } elseif (@('a','b','f','n','r','t','v','\','"',"'") -ccontains [string]$escape) {
                $script:At++
                $length++
            } else { Refuse }
            $start = $script:At
        } else {
            if ($char -eq "`n" -or $char -eq "`r") { Refuse }
            $script:At++
        }
    }
    Refuse
}
function Parse-Number {
    $start = $script:At
    if ($script:Text[$script:At] -eq '-') { $script:At++ }
    $digits = $script:At
    while ($script:At -lt $script:Text.Length -and $script:Text[$script:At] -match '^[0-9]$') {
        $script:At++
    }
    if ($digits -eq $script:At) { Refuse }
    [long]$value = 0
    if (-not [long]::TryParse($script:Text.Substring($start, $script:At - $start),
        [ref]$value) -or [Math]::Abs([double]$value) -gt 9007199254740991) { Refuse }
    return $value
}
function Parse-Value([int]$depth) {
    Skip-Space
    if ($script:At -ge $script:Text.Length) { Refuse }
    Node
    $char = $script:Text[$script:At]
    if ($char -eq '"' -or $char -eq "'") {
        $length = Parse-StringLength
        Charge (4 * $length + 16)
    } elseif ($char -eq '{') {
        if ($depth -ge $script:MaxDepth) { Refuse }
        $script:At++
        Charge (128 + $depth * 32)
        [long]$implicit = 0
        while ($true) {
            Skip-Space
            if ($script:At -ge $script:Text.Length) { Refuse }
            if ($script:Text[$script:At] -eq '}') { $script:At++; break }
            Node # Count the key, as the synthetic projection does.
            if ($script:Text[$script:At] -eq '[') {
                $script:At++
                Skip-Space
                if ($script:At -ge $script:Text.Length) { Refuse }
                if ($script:Text[$script:At] -eq '"' -or $script:Text[$script:At] -eq "'") {
                    $keyBytes = Parse-StringLength
                    Charge (128 + 4 * $keyBytes)
                } else {
                    $key = Parse-Number
                    if ($key -lt 1 -or $key -gt 2147483647) { Refuse }
                    Charge 192
                }
                Need ']'
                Need '='
            } else {
                # WoW's serializer also writes implicit numeric bank-page arrays.
                $implicit++
                if ($implicit -gt 2147483647) { Refuse }
                Charge 192
            }
            Parse-Value ($depth + 1)
            Skip-Space
            if ($script:At -ge $script:Text.Length) { Refuse }
            if ($script:Text[$script:At] -eq ',' -or $script:Text[$script:At] -eq ';') {
                $script:At++
            } elseif ($script:Text[$script:At] -ne '}') { Refuse }
        }
    } elseif ($char -eq '-' -or $char -match '^[0-9]$') {
        [void](Parse-Number)
        Charge 64
    } elseif ($script:At + 4 -le $script:Text.Length -and
        $script:Text.Substring($script:At, 4) -ceq 'true') {
        $script:At += 4
        Charge 16
    } elseif ($script:At + 5 -le $script:Text.Length -and
        $script:Text.Substring($script:At, 5) -ceq 'false') {
        $script:At += 5
        Charge 16
    } else { Refuse }
}
function Measure-One([string]$path) {
    if (WoW-Running) { Refuse }
    $before = Get-Item -LiteralPath $path
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        if ($stream.Length -gt $script:MaxFileBytes -or $stream.Length -lt 1) { Refuse }
        $size = [int]$stream.Length
        $buffer = New-Object byte[] $size
        $offset = 0
        while ($offset -lt $size) {
            $read = $stream.Read($buffer, $offset, $size - $offset)
            if ($read -le 0) { Refuse }
            $offset += $read
        }
        if ($stream.Length -ne $size) { Refuse }
        $script:Text = $script:Utf8.GetString($buffer)
    } finally { $stream.Dispose() }
    $after = Get-Item -LiteralPath $path
    if ($before.Length -ne $after.Length -or
        $before.LastWriteTimeUtc -ne $after.LastWriteTimeUtc -or
        (WoW-Running)) { Refuse }
    $script:At = 0
    $script:Nodes = 0
    $script:Projected = 4096
    if ($script:Text.Length -gt 0 -and $script:Text[0] -eq [char]0xFEFF) { $script:At++ }
    Skip-Space
    Need 'MclarionWowData'
    Need '='
    Parse-Value 0
    Skip-Space
    if ($script:At -ne $script:Text.Length -or $script:Projected -lt $size) { Refuse }
    $script:Text = $null
    return @($size, $script:Projected)
}
try {
    if (WoW-Running) { Refuse }
    if (-not $ClientRoot -or
        [IO.Path]::GetFileName($ClientRoot.TrimEnd('\','/')) -cne '_classic_beta_' -or
        -not (Test-Path -LiteralPath (Join-Path $ClientRoot 'WowB.exe') -PathType Leaf)) { Refuse }
    $accountRoot = Join-Path $ClientRoot 'WTF\Account'
    $files = @(Get-ChildItem -LiteralPath $accountRoot -Directory | ForEach-Object {
        $candidate = Join-Path (Join-Path $_.FullName 'SavedVariables') 'MclarionWow.lua'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
    })
    if ($files.Count -lt 1 -or $files.Count -gt 10) { Refuse }
    [long]$maxActual = 0
    [long]$maxProjection = 0
    [long]$minSlack = [long]::MaxValue
    foreach ($file in $files) {
        $measure = Measure-One $file
        $maxActual = [Math]::Max($maxActual, [long]$measure[0])
        $maxProjection = [Math]::Max($maxProjection, [long]$measure[1])
        $minSlack = [Math]::Min($minSlack, [long]$measure[1] - [long]$measure[0])
    }
    if (WoW-Running) { Refuse }
    "Checked=$($files.Count); MaxActualBytes=$maxActual; MaxProjectedBytes=$maxProjection; MinProjectionSlack=$minSlack"
} catch {
    # Never emit exception messages: PowerShell errors may contain private paths or text.
    'REFUSED: game running, file unavailable, unsupported shape, changed view, or over budget'
    exit 1
}
