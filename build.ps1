[CmdletBinding()]
param(
  $ModuleVersion = ''
)

Push-Location $PSScriptRoot
try {
    $BuildTimer = New-Object System.Diagnostics.Stopwatch
    $BuildTimer.Start()
    $ErrorActionPreference = "Stop"

    Write-Host "##  Building RubyInstaller script module" -ForegroundColor Cyan
    $args = @{
      'SourcePath' = (Join-Path -Path $PSScriptRoot -ChildPath 'RubyInstaller')
      'OutputDirectory' = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Output') -ChildPath 'RubyInstaller'
      'Target' = 'CleanBuild'
    }
    if ($ModuleVersion -ne '') { $args['Version'] = $ModuleVersion }
    Build-Module @args

    $BuildTimer.Stop()
    Write-Host "##  Total Elapsed $($BuildTimer.Elapsed.ToString("hh\:mm\:ss\.ff"))"
} catch {
    throw $_
} finally {
    Pop-Location
}