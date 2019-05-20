Function Get-DestinationDir($RubyVersion) {
  Write-Output ("C:\tools\ruby" + $RubyVersion.Replace(' ','').Replace('(','').Replace(')',''))
}
