function Install-7zip {
  [cmdletBinding()]

  $7zExists = $false
  try {
    Get-Command '7z.exe' -ErrorAction 'Stop' | Out-Null
    $7zExists = $true
  } catch {
    $7zExists = $false
  }
  If (-not $7zExists) {
    Write-Verbose "Installing 7Zip command line..."
    Write-Progress -Activity "Installing 7Zip command line"
    & choco install 7zip.commandline -y
    Write-Progress -Activity "Installing 7Zip command line" -Completed
  } else {
    Write-Verbose "7Zip is installed"
  }
}
