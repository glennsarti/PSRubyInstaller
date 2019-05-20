function Get-UruTag($RubyVersion) {
  $bareRubyVersion = ($RubyVersion -split ' ')[0]

  if ($RubyVersion -match 'x64') {
    Write-Output "$($bareRubyVersion)-x64"
  } else {
    Write-Output "$($bareRubyVersion)-x86"
  }
}
