Param(
    [cmdletbinding()]
    [string[]]$ModulesToPublish,
    [string]$NuGetApiKey,
    [switch]$Build,
    [switch]$Install,
    [switch]$Test,
    [switch]$Deploy,
    [switch]$InitialPublish
)

If ($env:ModulesToPublish)      { $ModulesToPublish = $env:ModulesToPublish }
If ($ModulesToPublish)          { $ModulesToPublish = $ModulesToPublish.Split(',') }
If ($env:NuGetApiKey)           { $NuGetApiKey = $env:NuGetApiKey }
If ($Deploy -and !$NuGetApiKey) { Throw "-NuGetApiKey must be defined in order to deploy to PS Gallery" }

If ($Build) {

    If ($env:APPVEYOR){
        Write-Host "Build Version    : $env:APPVEYOR_BUILD_VERSION"
        Write-Host "Author           : $env:APPVEYOR_REPO_COMMIT_AUTHOR"
        Write-Host "Branch           : $env:APPVEYOR_REPO_BRANCH"
    }
        Write-Host "ModulesToPublish : $ModulesToPublish"
}


If ($Install) {

    Write-Host 'Installing NuGet Package Provider ..'
    Install-PackageProvider -Name NuGet -Force | Out-Null
    
    Write-Host 'Installing Pester ..'
    Install-Module -Name Pester -Repository PSGallery -Force

    Write-Host 'Installing PSScriptAnalyzer ..'
    Install-Module PSScriptAnalyzer -Repository PSGallery -force
}


If ($Test) {

    $testResultsFile = 'TestsResults.xml'
    $Results = Invoke-Pester -Script .\Tests\*.Tests.ps1 -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru

    If ($env:APPVEYOR){
        Write-Host "Uploading results to AppVeyor .."
        (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
    }

    If (($Results.FailedCount -gt 0) -or ($Results.PassedCount -eq 0)) { 
        Throw "$($Results.FailedCount) tests failed."
    } Else {
        Write-Host 'All tests passed.' -ForegroundColor Green
    }
}


If ($Deploy) {
    
    If ($env:APPVEYOR -and $env:APPVEYOR_REPO_BRANCH -notmatch 'master') {
        Write-Host "Finished testing of branch $env:APPVEYOR_REPO_BRANCH - Exiting." -ForegroundColor Green
        Exit
    }
 
    If (!$ModulesToPublish) {
        Write-Host "No modules are defined to be published - Exiting." -ForegroundColor Green
        Exit
    }

    $ModulesToPublish | ForEach-Object {
        
        $ModuleManifest = Get-ChildItem "$pwd\$_\*.psd1"
        
        If ($ModuleManifest) {

            $Module           = $ModuleManifest.BaseName
            $ModulePath       = $ModuleManifest.Directory
            $ManifestFullName = $ModuleManifest.FullName
            $env:psmodulepath = $env:psmodulepath + ';' + $ModulePath
            
            If (!$InitialPublish) {
                        
                Write-Host "$Module : Checking module for differences with existing PowerShell Gallery version .."
            
                Try {
                    Save-Module -Name $Module -Path .\ -ErrorAction Stop
                    $ModuleContents    = Get-ChildItem -Exclude *.psd1 "$ModulePath\" | Where-Object { -not $_.PsIsContainer } -ErrorAction Stop | Get-Content
                    $PSGModuleContents = Get-ChildItem -Exclude *.psd1 "$ModulePath\*\*" | Where-Object { -not $_.PsIsContainer } -ErrorAction Stop | Get-Content
                } Catch {
                    Throw "$Module : Could not get the contents of the local or Gallery module."
                } Finally {
                    Remove-Item "$ModulePath\*\*" -Recurse -Force
                }

                $Differences = Compare-Object $ModuleContents $PSGModuleContents

                If ($Differences){
            
                    If (!$env:APPVEYOR_BUILD_VERSION) { 
                        
                        Write-Host "$Module : Importing module to establish current version .."
                        
                        Try{
                            Import-Module $ManifestFullName -Force -ErrorAction Stop
                            $CurVersion = Get-Module $Module | Select-Object -ExpandProperty Version
                            $NewVersion = New-Object -TypeName System.Version -ArgumentList $CurVersion.Major, $CurVersion.Minor, ($CurVersion.Build + 1), 0
                        } Catch {
                            Throw "$Module : Could not establish new module version."
                        }

                    } Else { $NewVersion = $env:APPVEYOR_BUILD_VERSION }

                    If (!$NuGetApiKey) { Throw "NuGetApiKey not specified. Cannot publish to PowerShell Gallery." }

                    Write-Host "$Module : Updating manifest to version $NewVersion .."
                    
                    Try{
                        $ModuleManifest = Get-Content $ManifestFullName -Raw
                        [regex]::replace($ModuleManifest,'(ModuleVersion = )(.*)',"`$1'$NewVersion'") | Out-File -LiteralPath $ManifestFullName -ErrorAction Stop
                    } Catch {
                        Throw "$Module : Could not update manifest."
                    }
                
                } Else {
                    Write-Host "$Module : The module is already up to date in the Gallery - Exiting." -ForegroundColor Green
                    Exit
                }
            }
        
            Write-Host "$Module : Publishing module to the PowerShell Gallery .."
            
            Try { 
                Publish-Module -Path $ModulePath -NuGetApiKey $NuGetApiKey

            } Catch { 
                Throw "$Module : Could not publish $ModulePath"
            }
            
        } Else {
            Throw "$Module : Could not locate a module manifest in $pwd\$Module\"
        }
        
        Write-Host "$Module published successfully." -ForegroundColor Green
    }
}
