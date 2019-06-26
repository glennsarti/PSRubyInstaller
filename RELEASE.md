## How to do a release

1. Generate and merge a release prep

    * Move the Unreleased parts of the changelog to the released section

    * Modify `RubyInstaller/RubyInstaller.psd1` with the new version number

2. Once merged get the commit id of the preparation

3. Tag the commit

    `git tag -a '<version>' -m '<version>' <commit id>`

    For example;
    `git tag -a '0.11.0' -m '0.11.0' 8766a5dd5e476bb10c164962e8d9185810e96a17`

4. Push the commit

    `git push <remote> <version>`

    For example;
    `git push upstream 0.11.0`

5. Checkout and reset the repo for the new tag

    For example;

    ``` powershell
    PS> git checkout 0.11.0
    PS> git reset --hard 0.11.0
    ```

6. Build the artefacts

    `.\build.ps1`

7. Enure the version is correct in the `/Output/RubyInstaller/RubyInstaller.psd1` file

8. Publish the module to the Gallery

    `Publish-Module -Path Output\RubyInstaller -NugetApiKey abc123`
