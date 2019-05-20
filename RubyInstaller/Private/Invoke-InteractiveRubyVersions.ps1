Function Invoke-InteractiveRubyVersions {
  param(
    [ValidateNotNull()]
    [string[]]
    $RubyList
  )

  # Sometimes single element arrays come through as a string.  Convert it into an array
  if ($RubyList.GetType().ToString() -eq 'System.String') { $RubyList = @($RubyList) }

  # Prompt the user for which ruby versions to install
  $itemsToInstall = @()
  do {
    Write-Host ""
    Write-Host ""
    Write-Host "A. Install all versions ('$($RubyList -join "', '")')"
    For($index = 0; $index -lt $RubyList.Count; $index++) {
      Write-Host "$([char]($index + 66)). Install '$($RubyList[$index])'"
    }
    Write-Host "----"
    Write-Host "Z. Install custom version"
    Write-Host ""
    $misc = (Read-Host "Select an option").ToUpper()
  } until ( ($misc -ge 'A') -and $misc -le 'Z')

  $option = ([int][char]$misc - 65)
  switch ($option) {
    0 {
      $itemsToInstall = $RubyList
      break;
    }
    25 {
      # Ask the user for the version string
      do {
        $misc = ''
        Write-Host ""
        Write-Host "Note, the version must match one on the Ruby Installer archive website"
        Write-Host "  https://rubyinstaller.org/downloads/archives/"
        $misc = (Read-Host "Enter Ruby version to install (e.g. '2.4.3-2 (x64)')")
      } until ($misc -ne '')
      $itemsToInstall = @($misc)
    }
    default {
      $itemsToInstall = @($RubyList[$option - 1])
    }
  }

  if ( ($itemsToInstall -join '') -eq '' ) { Throw "Nothing to install!!"; return; }
  Write-Output $itemsToInstall
}