Function Select-Ruby {
  [cmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='Medium')]
  param(
    [Parameter(ValueFromPipeline=$true, Mandatory=$true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [String]
    $RubyTag
  )

  begin {
    $uruResult = & uru $RubyTag

    if ($LASTEXITCODE -ne 0) {
      throw "Error selecting ruby ${RubyTag}: $uruResult"
    } else {
      Write-Verbose $uruResult
    }
  }
}
