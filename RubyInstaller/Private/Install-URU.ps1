function Install-URU {
  [cmdletBinding()]

  $ChocoInstall = $ENV:ChocolateyInstall
  # The env var may not be set yet.  Do a best guess.
  if ($null -eq $ChocoInstall) { $ChocoInstall = Join-Path -Path $ENV:ALLUSERSPROFILE -ChildPath 'chocolatey' }

  $URUPath = Join-Path $ChocoInstall -Child "\bin\uru.ps1"

  if (-not (Test-Path -Path $URUPath)) {
    Write-Verbose "Installing URU..."
    Write-Progress -Activity "Installing URU"
    Write-Verbose "Determining the current version of URU..."
    $uruver = (Invoke-WebRequest 'https://bitbucket.org/jonforums/uru/downloads/uru.json' -UseBasicParsing -ErrorAction 'Stop' | ConvertFrom-JSON).version
    if ($null -eq $uruver) {
      Throw "Could not determine the current version of URU"; return
    }
    $downloadURL = "https://bitbucket.org/jonforums/uru/downloads/uru.${uruver}.nupkg"
    $uruRoot = Get-ChocolateyTools
    $uruInstall = Join-Path -Path $uruRoot -ChildPath 'URUInstall'
    $uruInstallNuget = Join-Path -Path $uruInstall -ChildPath 'uru.0.8.5.nupkg'
    if (Test-Path -Path $uruInstall) { Remove-Item -Path $uruInstall -Force -Recurse -Confirm:$false | Out-Null }
    New-Item -Path $uruInstall -ItemType Directory | Out-Null
    Write-Verbose "Downloading URU installer..."
    (New-Object System.Net.WebClient).DownloadFile($downloadURL, $uruInstallNuget)

    Write-Verbose "Running the URU installer..."
    & choco install uru -source $uruInstall -f -y

    # Cleaning up...
    if (Test-Path -Path $uruInstall) { Remove-Item -Path $uruInstall -Force -Recurse -Confirm:$false | Out-Null }
    Write-Progress -Activity "Installing URU" -Completed
  } else {
    Write-Verbose "Uru is installed"
  }
}
