function Install-Chocolatey {
  [cmdletBinding()]
  $ChocoExists = $false
  try {
    Get-Command 'choco.exe' -ErrorAction 'Stop' | Out-Null
    $ChocoExists = $true
  } catch {
    $ChocoExists = $false
  }
  If (-not $ChocoExists) {
    Write-Verbose "Installing Chocolatey..."
    Write-Progress -Activity "Installing Chocolatey"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Progress -Activity "Installing Chocolatey" -Completed
  } else {
    Write-Verbose "Chocolatey is installed"
  }
}
