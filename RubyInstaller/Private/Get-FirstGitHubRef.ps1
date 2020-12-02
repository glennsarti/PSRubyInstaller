Function Get-FirstGitHubRef($Owner, $Repo, $Refs) {
  $Found = $False
  ForEach($Ref in $Refs) {
    Try {
      Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/ref/tags/$Ref" | Out-Null
      Write-Output $Ref
      $Found = $True
      break
    } Catch {
      # Ignore the Error
    }
  }

  if (-Not $Found) { Throw "Could not find any suitable tags in GitHub Repo $Owner-$Repo for $($Refs -join ', ')"}
}
