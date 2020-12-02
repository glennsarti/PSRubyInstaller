Function Install-Ruby {
  [cmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='High',DefaultParameterSetName='Interactive')]
  param(
    [Parameter(ValueFromPipeline=$true, Mandatory=$true, Position = 0, ParameterSetName="SpecificVersions")]
    [ValidateNotNull()]
    [Alias("Version", "Versions")]
    [String[]]
    $RubyVersions
  )

  begin {
    $is64bit = ([System.IntPtr]::Size -eq 8)
    if (-not $is64bit) {
      Throw "Install-Ruby is not supported on 32bit operating systems"; return
    }
    if ($Host.Name -eq 'ServerRemoteHost') {
      Throw "Install-Ruby is not supported over remote connections due to Ruby DevKit failing to install correctly"; return
    }

    # Remember and fiddle with the allowed protocols for web requests
    $CurrentProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    # Workaround for https://github.com/majkinetor/au/issues/142
    [System.Net.ServicePointManager]::SecurityProtocol = `
      [System.Net.SecurityProtocolType]::Tls11 -bor
      [System.Net.SecurityProtocolType]::Tls12 -bor
      [System.Net.SecurityProtocolType]::Tls

    try {
      # Preflight checks...
      Install-Chocolatey -ErrorAction 'Stop'
      Install-7zip -ErrorAction 'Stop'
      Install-URU -ErrorAction 'Stop'

      # Opinionated Ruby List (mainly for Puppet Developers)
      # TODO: Update for 2.5, 2.4 and 2.6? Drop 2.1?
      $rubyList = @(
        '2.4.4-2 (x86)', '2.4.4-2 (x64)',
        '2.5.1-2 (x86)', '2.5.1-2 (x64)',
        '2.7.2-1 (x86)', '2.7.2-1 (x64)'
      )
      $ChocolateyTools = Get-ChocolateyTools
      $devKit2_64 = Join-Path -Path $ChocolateyTools -ChildPath 'DevKit2-x64'
      $devKit2_32 = Join-Path -Path $ChocolateyTools -ChildPath 'DevKit2'
      $msys_64 = Join-Path -Path $ChocolateyTools -ChildPath 'msys64'
      $msys_32 = Join-Path -Path $ChocolateyTools -ChildPath 'msys32'

      if ($PsCmdlet.ParameterSetName -eq 'Interactive') {
        $RubyVersions = Invoke-InteractiveRubyVersions -RubyList $rubyList
      }
      # Sometimes single element arrays come through as a string.  Convert it into an array
      if ($RubyVersions.GetType().ToString() -eq 'System.String') { $RubyVersions = @($RubyVersions) }

      # Now we have the names of the rubies, time to install!
      $ProgressActivity = 'Install Ruby'
      Write-Progress -Activity $ProgressActivity
      $RubyVersions | ForEach-Object -Process {
        $rubyVersionString = $_
        Write-Verbose "Installing Ruby ${rubyVersionString} ..."
        Write-Progress -Activity $ProgressActivity -CurrentOperation "Installing Ruby ${rubyVersionString}"

        $rubyIs64 = $rubyVersionString -match 'x64'
        $rubyVersionString -match '^([\d.-]+)' | Out-Null
        $rubyVersion = $matches[1]

        $rubyURL = $null
        $32bitDevKit = $false
        $64bitDevKit = $false
        $RIDKDevKit = $false
        $destDir = Get-DestinationDir -RubyVersion $rubyVersionString
        $uruTag = Get-UruTag -RubyVersion $rubyVersionString

        # URL base page
        # https://rubyinstaller.org/downloads/archives/
        switch -Regex ($rubyVersion) {
          '^2\.[0123]\.' {
            # Example URL
            # 32bit 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.3-i386-mingw32.7z'
            # 64bit 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.3-x64-mingw32.7z'
            if ($rubyIs64) {
              $rubyURL = "https://dl.bintray.com/oneclick/rubyinstaller/ruby-${rubyVersion}-x64-mingw32.7z"
              $64bitDevKit = $true
            } else {
              $rubyURL = "https://dl.bintray.com/oneclick/rubyinstaller/ruby-${rubyVersion}-i386-mingw32.7z"
              $32bitDevKit = $true
            }
          }
          '^2\.4\.1\-' {
            # Example URL
            # 2.4.1 only
            # 32bit 'https://github.com/oneclick/rubyinstaller2/releases/download/2.4.1-2/rubyinstaller-2.4.1-2-x86.7z'
            # 64bit 'https://github.com/oneclick/rubyinstaller2/releases/download/2.4.1-2/rubyinstaller-2.4.1-2-x64.7z'
            if ($rubyIs64) {
              $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/${rubyVersion}/rubyinstaller-${rubyVersion}-x64.7z"
            } else {
              $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/${rubyVersion}/rubyinstaller-${rubyVersion}-x86.7z"
            }
            $RIDKDevKit = $true
          }

          '^2\.[56789]\.|^2\.4\.[23456789]-' {
            # Example URL
            # 2.4.2+ and 2.5+ only
            # 32bit 'https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.5.1-1/rubyinstaller-2.5.1-1-x86.7z'
            # 64bit 'https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.5.1-1/rubyinstaller-2.5.1-1-x64.7z'
            if ($rubyIs64) {
              $Ref = Get-FirstGitHubRef -Owner 'oneclick' -Repo 'rubyinstaller2' -Refs "rubyinstaller-${rubyVersion}","RubyInstaller-${rubyVersion}"
              $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/$Ref/rubyinstaller-${rubyVersion}-x64.7z"
            } else {
              $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/$Ref/rubyinstaller-${rubyVersion}-x86.7z"
            }
            $RIDKDevKit = $true
          }
          default { Throw "Unknown Ruby Version $rubyVersion"; return }
        }

        # Install the ruby files
        if (-not (Test-Path -Path $destDir)) {
          $tempFile = Join-Path -path $ENV:Temp -ChildPath 'rubydl.7z'
          $tempExtract = Join-Path -path $ENV:Temp -ChildPath ('rubydl_extracted' + [guid]::NewGuid().ToString())
          if (Test-Path -Path $tempExtract) { Start-Sleep -Seconds 2; Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }

          Write-Verbose "Downloading from $rubyURL ..."
          if (Test-Path -Path $tempFile) { Start-Sleep -Seconds 2; Remove-Item -Path $tempFile -Confirm:$false -Force | Out-Null }
          Invoke-WebRequest -URI $rubyURL -OutFile $tempFile -UseBasicParsing

          & 7z x $tempFile "`"-o$tempExtract`"" -y

          # Get the root directory from the extract
          $misc = (Get-ChildItem -Path $tempExtract | ? { $_.PSIsContainer } | Select -First 1).Fullname

          Write-Verbose "Install ruby to $destDir ..."
          if (Test-Path -Path $destDir) { Remove-Item -Path $destDir -Recurse -Confirm:$false -Force | Out-Null }
          Move-Item -Path $misc -Destination $destDir -Force -Confirm:$false | Out-Null

          Write-Verbose "Adding to URU..."
          & uru admin add "$($destDir)\bin" --tag $uruTag

          Write-Verbose "Cleaning up..."
          if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Confirm:$false -Force | Out-Null }
          if (Test-Path -Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }
        } else { Write-Verbose "Ruby ${rubyVersionString} is already installed to $destDir"}

        # Configure the ruby installation
        Write-Progress -Activity $ProgressActivity -CurrentOperation "Configuring Ruby ${rubyVersionString}"
        & uru $uruTag
        # Write-Output "Ruby version..."
        # & ruby -v
        # Write-Output "Gem version..."
        # & gem -v

        # Update the system gems
        $tempRC =  Join-Path -path $ENV:Temp -ChildPath 'gem.rc'
@"
---
:backtrace: false
:bulk_threshold: 1000
:sources:
- http://rubygems.org
:update_sources: true
:verbose: true
gem: --no-document
"@ | Set-Content -Encoding Ascii -Path $tempRC -Force -Confirm:$false

        $extraGemUpdate = ''
        if ($rubyVersion -match '^(?:1\.|2\.[012]\.)') {
          # Rubygems 3.x requires Ruby 2.3.0, so pin to latest in 2.x
          $extraGemUpdate += ' 2.7.10'
        }

        Write-Progress -Activity $ProgressActivity -CurrentOperation "Updating System Gems for Ruby ${rubyVersionString} (via HTTP)"
        Write-Verbose "Updating system gems (via HTTP)..."
        & gem update --system --config-file $tempRC $extraGemUpdate
        Remove-Item -Path $tempRC -Force -Confirm:$false | Out-Null

        # Install bundler if it's not already there
        $BundleExists = $false
        try {
          Get-Command 'bundle' -ErrorAction 'Stop' | Out-Null
          $BundleExists = $true
        } catch {
          $BundleExists = $false
        }
        if (-not $BundleExists) {
          Write-Progress -Activity $ProgressActivity -CurrentOperation "Installing Bundler"
          Write-Verbose "Installing bundler..."
          if ($rubyVersion -match '^1\.') {
            # Bundler 2.x requires Ruby 2.3.0, so pin to latest in 1.x
            & gem install bundler --no-ri --no-rdoc --version 1.17.3
          } elseif ($rubyVersion -match '2\.[012]\.') {
            # Bundler 2.x requires Ruby 2.3.0, so pin to latest in 1.x
            & gem install bundler --no-document --force --version 1.17.3
          } else {
            & gem install bundler --no-document --force
          }
        } else { Write-Verbose "Bundler already installed" }

        # MSYS2 dev kit (Ruby 2.4+)
        if ($RIDKDevKit) {
          if ($rubyIs64) {
            # DevKit for Ruby 2.4+ 64bit
            if (-not (Test-Path -Path $msys_64)) {
              Write-Verbose "Installing DevKit 2.4+ x64"
              Write-Progress -Activity $ProgressActivity -CurrentOperation "Installing DevKit 2.4+ x64"
              Start-Process -FilePath 'choco' -ArgumentList (@('install','msys2','-y','--params','/NoUpdate')) -NoNewWindow -Wait | Out-Null
            } else { Write-Verbose "DevKit 2.4+ 64bit is installed" }
          } else {
            # DevKit for Ruby 2.4+ 32bit
            if (-not (Test-Path -Path $msys_32)) {
              Write-Verbose "Installing DevKit 2.4+ x86"
              Write-Progress -Activity $ProgressActivity -CurrentOperation "Installing DevKit 2.4+ x86"
              Start-Process -FilePath 'choco' -ArgumentList (@('install','msys2','-y','-x86','-f','--params','/NoUpdate')) -NoNewWindow -Wait | Out-Null
            } else { Write-Verbose "DevKit 2.4+ 32bit is installed" }
          }

          & ridk install 2 3
        }

        # 64 and 32 bit legacy DevKit
        if ($64bitDevKit -or $32bitDevKit) {
          #******************
          # ORDER IS VERY IMPORTANT - 64bit Devkit MUST be installed before 32bit
          #******************
          # DevKit for Ruby 2.x 64bit
          if ($is64bit -and (-not (Test-Path -Path $devKit2_64))) {
            Write-Verbose "Installing DevKit 2.x x64. NOTE - Errors are expected"
            Write-Progress -Activity $ProgressActivity -CurrentOperation "Installing DevKit 2.x x64"
            Start-Process -FilePath 'choco' -ArgumentList (@('install','ruby2.devkit','-y')) -NoNewWindow -Wait | Out-Null
            if (-not (Test-Path -Path $devKit2_32)) { Throw "DevKit 2.x x64 did not install" }
            Move-Item $devKit2_32 $devKit2_64 -Force -EA Stop
          } else { Write-Verbose "DevKit 2.x 64bit is installed" }

          # DevKit for Ruby 2.x 32bit
          if (-not (Test-Path -Path $devKit2_32)) {
            Write-Verbose "Installing DevKit 2.x x86. NOTE - Errors are expected"
            Write-Progress -Activity $ProgressActivity -CurrentOperation "Installing DevKit 2.x x86"
            Start-Process -FilePath 'choco' -ArgumentList (@('install','ruby2.devkit','-y','-x86','-f')) -NoNewWindow -Wait | Out-Null
            if (-not (Test-Path -Path $devKit2_32)) { Throw "DevKit 2.x x86 did not install" }
          } else { Write-Verbose "DevKit 2.x 32bit is installed" }

          # 64bit legacy devkit
          if ($64bitDevKit) {
@"
---
- $( $destDir -replace '\\','/' )
"@ | Set-Content -Path "$($devKit2_64)\config.yml"
            Push-Location $devKit2_64
            Write-Verbose "Installing DevKit $devKit2_64 for $rubyVersion"
            & ruby dk.rb install
            Pop-Location
          }

        # 32bit legacy devkit
          if ($32bitDevKit) {
@"
---
- $( $destDir -replace '\\','/' )
"@ | Set-Content -Path "$($devKit2_32)\config.yml"
            Push-Location $devKit2_32
            Write-Verbose "Installing DevKit $devKit2_32 for $rubyVersion"
            & ruby dk.rb install
            Pop-Location
          }
        }
      }
      Write-Progress -Activity $ProgressActivity -Completed

      Write-Verbose "Cleanup URU assignment"
      & uru nil

    }
    finally {
      # Restore the old security protocol
      [System.Net.ServicePointManager]::SecurityProtocol = $CurrentProtocol
    }
  }

  end {
    & uru list
  }
}
