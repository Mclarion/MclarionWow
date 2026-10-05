# Windows-only synthetic integration test. Never reads a player save.
param([Parameter(Mandatory=$true)][string]$Probe,
      [Parameter(Mandatory=$true)][string]$FixtureDirectory)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('MHWOW-Probe-' + [guid]::NewGuid().ToString('N'))
$client = Join-Path $root '_classic_beta_'
$saveDir = Join-Path $client 'WTF\Account\Synthetic\SavedVariables'
try {
    [void](New-Item -ItemType Directory -Path $saveDir -Force)
    # Only the basename check needs this disposable placeholder.
    [IO.File]::WriteAllBytes((Join-Path $client 'WowB.exe'), [byte[]]@())
    $target = Join-Path $saveDir 'MclarionWow.lua'
    $cases = @(
        @{ File = 'schema2-synthetic.lua'; Expected = 69860 },
        @{ File = 'schema2-synthetic-explicit.lua'; Expected = 69860 },
        @{ File = 'schema3-progression-synthetic.lua'; Expected = 10160 },
        @{ File = 'savedvars-size-escape-synthetic.lua'; Expected = 6088 }
    )
    foreach ($case in $cases) {
        Copy-Item -LiteralPath (Join-Path $FixtureDirectory $case.File) -Destination $target -Force
        $result = & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Probe -ClientRoot $client
        if ($LASTEXITCODE -ne 0) { throw 'synthetic probe refused' }
        $actual = (Get-Item -LiteralPath $target).Length
        $expected = "Checked=1; MaxActualBytes=$actual; MaxProjectedBytes=$($case.Expected); MinProjectionSlack=$($case.Expected - $actual)"
        if ($result -cne $expected) { throw 'synthetic aggregate mismatch' }
    }
    $result = & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Probe -ClientRoot $root
    if ($LASTEXITCODE -eq 0 -or $result -cne 'REFUSED: game running, file unavailable, unsupported shape, changed view, or over budget') {
        throw 'non-client root was not refused'
    }
    'synthetic size probe: four fixtures matched and non-client root refused'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
