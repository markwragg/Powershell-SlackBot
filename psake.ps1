﻿# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
    $ProjectRoot = $ENV:BHProjectPath
    if(-not $ProjectRoot)
    {
        $ProjectRoot = $PSScriptRoot
    }

    $Verbose = @{}
    if($ENV:BHCommitMessage -match "!verbose")
    {
        $Verbose = @{Verbose = $True}
    }
}

Task Default -Depends Deploy

Task Init {
    '----------------------------------------------------------------------'
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}

Task Test -Depends Init  {
    '----------------------------------------------------------------------'
    
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
        
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -ExcludeTag Integration

    # In Appveyor?  Upload our tests! #Abstract this into a function?
    If($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            "$ProjectRoot\$TestFile" )
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    if($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Test {
    '----------------------------------------------------------------------'
    #Set-ModuleFunctions
}

Task Deploy -Depends Build {
    '----------------------------------------------------------------------'

    # Update Manifest version number
    $ManifestPath = $Env:BHPSModuleManifest
    
    If (-Not $env:APPVEYOR_BUILD_VERSION) {
        $Manifest = Test-ModuleManifest -Path $manifestPath
        [System.Version]$Version = $Manifest.Version
        [String]$NewVersion = New-Object -TypeName System.Version -ArgumentList ($Version.Major, $Version.Minor, $Version.Build, ($Version.Revision+1))
    } Else {
        $NewVersion = $env:APPVEYOR_BUILD_VERSION
    }
    "New Version: $NewVersion"

     $FunctionList = ((Get-ChildItem -Path .\$Env:BHProjectName\Public).BaseName)

    Update-ModuleManifest -Path $ManifestPath -ModuleVersion $NewVersion -FunctionsToExport $functionList
    (Get-Content -Path $ManifestPath) -replace "PSGet_$Env:BHProjectName", "$Env:BHProjectName" | Set-Content -Path $ManifestPath
    (Get-Content -Path $ManifestPath) -replace 'NewManifest', "$Env:BHProjectName" | Set-Content -Path $ManifestPath
    (Get-Content -Path $ManifestPath) -replace 'FunctionsToExport = ', 'FunctionsToExport = @(' | Set-Content -Path $ManifestPath -Force
    (Get-Content -Path $ManifestPath) -replace "$($FunctionList[-1])'", "$($FunctionList[-1])')" | Set-Content -Path $ManifestPath -Force

    $Params = @{
        Path = $ProjectRoot
        Force = $true
        Recurse = $false # We keep psdeploy artifacts, avoid deploying those : )
    }
    Invoke-PSDeploy @Verbose @Params

}