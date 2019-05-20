Function Get-Ruby {
  [cmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='Low')]
  param()

  process {
    $uruResult = & uru ls

    # Use a simple text parser to extract what we want and emit PS Objects
    $uruResult | ForEach-Object {
      $result = $_ -split ':', 2

      if (($result[0] -ne '') -and ($result[1] -ne '')) {
        Write-Output (New-Object -TypeName PSCustomObject -Property @{
          'Tag' = $result[0].Trim()
          'Description' = $result[1].Trim()
        } )
      }
    }
  }
}
