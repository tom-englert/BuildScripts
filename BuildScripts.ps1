# update the version number in the vsix manifest by replacing the build number with the specified value. 
# only works with manifest v2 (VS2012 and newer)
# returns the updated version
function Vsix-SetBuildVersion 
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$manifestFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    "Vsix-SetBuildVersion: $manifestFilePath, $buildNumber" | Write-Host

    [xml]$vsixXml = Get-Content $manifestFilePath

    [Version]$version = $vsixXml.PackageManifest.Metadata.Identity.Version

    $version = New-Object Version ([int]$version.Major),([int]$version.Minor),$buildNumber

    $vsixXml.PackageManifest.Metadata.Identity.Version = [string]$version

    $vsixXml.Save($manifestFilePath)

    return [string]$version
}

# update the publish application version number in a project file by replacing the build number with the specified value. 
# returns the updated version
function Project-SetBuildVersion
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$projectFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    "Project-SetBuildVersion: $projectFilePath, $buildNumber" | Write-Host

    [xml]$projectXml=Get-Content $projectFilePath
    [Version]$version = $projectXml.Project.PropertyGroup[0].ApplicationVersion

    $version = New-Object Version ([int]$version.Major),([int]$version.Minor),$buildNumber,([int]$version.Revision)

    $projectXml.Project.PropertyGroup[0].ApplicationVersion = [string]$version

    $projectXml.Save($projectFilePath)

    return [string]$version
}

# update the version number in a C# source file by replacing the build number with the specified value. 
# the version must be represented in the file as 'version = "#.#.#.#', usually 'const string version = "#.#.#.#";'
# returns the updated version
function Source-SetBuildVersion
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$sourceFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    "Source-SetBuildVersion: $sourceFilePath, $buildNumber" | Write-Host

    $source = Get-Content $sourceFilePath
    $replacement = "`$1.$buildNumber.`$2"
    $source = $source -replace '(version\s+=\s+"\d+.\d+).\d+.(\d+")', $replacement
    $source | Set-Content $sourceFilePath

    $matchInfo = $source | Select-String -Pattern 'version\s+=\s+"(\d+.\d+.\d+.\d+)"'
    return $matchInfo.Matches[0].Groups[1].Value
}

# generates the command string to update the vsNext build number by appending _$version
# write this command to the host to let the build server execute it.
function Build-AppendVersionToBuildNumber
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$version,

        [Parameter(Position=1, Mandatory=0)]
        [string]$buildNumber = $env:Build_BuildNumber
    )

   return "##vso[build.updatebuildnumber]" + $buildNumber + "_" + $version
}

function Vsix-PublishToGallery
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1 ,ValueFromPipeline=$true)]
        [string]$vsixFile,
        [Parameter(Position=1, Mandatory=0)]
        [string]$repository = "$env:BUILD_REPOSITORY_NAME"
    )

    "Upload to VsixGallery: $vsixFile $repository" | Write-Host

    $vsixUploadEndpoint = "http://vsixgallery.com/api/upload"
    
    [string]$url = Vsix-GetUpoadUrl $repository

    $url | Write-Host

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($vsixFile)

    try {
        $response = Invoke-WebRequest $url -Method Post -Body $bytes -UseBasicParsing
        'OK' | Write-Host -ForegroundColor Green
    }
    catch{
        'FAIL' | Write-Error
        $_.Exception.Response.Headers["x-error"] | Write-Error
    }
}

function Vsix-GetUpoadUrl
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=0)]
        [string]$repository = "$env:BUILD_REPOSITORY_NAME"
    )

    $vsixUploadEndpoint = "http://vsixgallery.com/api/upload"
    
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $repository = "https://github.com/$repository"

    [string]$issueTracker = "$repository/issues"

    $repository = [System.Web.HttpUtility]::UrlEncode($repository)
    $issueTracker = [System.Web.HttpUtility]::UrlEncode($issueTracker)

    [string]$url = $vsixUploadEndpoint + "?repo=" + $repository + "&issuetracker=" + $issueTracker

    return $url
}