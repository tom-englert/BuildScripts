function Vsix-SetBuildVersion 
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$manifestFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    [xml]$vsixXml=Get-Content $manifestFilePath

    [Version]$version = $vsixXml.PackageManifest.Metadata.Identity.Version

    $version = New-Object Version ([int]$version.Major),([int]$version.Minor),$buildNumber

    $vsixXml.PackageManifest.Metadata.Identity.Version = [string]$version

    $vsixXml.Save($vsixManifest)
}

function Project-SetBuildVersion
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$projectFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    [xml]$projectXml=Get-Content $projectFilePath
    [Version]$version = $projectXml.Project.PropertyGroup[0].ApplicationVersion

    $version = New-Object Version ([int]$version.Major),([int]$version.Minor),$buildNumber

    $projectXml.Project.PropertyGroup[0].ApplicationVersion = [string]$version

    $projectXml.Save($projectFilePath)
}

function Source-SetBuildVersion
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$sourceFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    $source = Get-Content $sourceFilePath
    $replacement = "`$1.$buildNumber.`$2"
    $source = $source -replace '(version\s+=\s+"\d+.\d+).\d+.(\d+")', $replacement
    $source | Set-Content $sourceFilePath
}

function Vsix-PublishToGallery{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1 ,ValueFromPipeline=$true)]
        [string[]]$vsixFile,
        [Parameter(Position=1, Mandatory=0)]
        [string[]]$repository = $env:BUILD_REPOSITORY_URI
    )

    "Upload to VsixGallery: $vsixFile $repository" | Write-Host

    $vsixUploadEndpoint = "http://vsixgallery.com/api/upload"
    
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $repository=[System.Web.HttpUtility]::UrlEncode($repository)
    $issueTracker=[System.Web.HttpUtility]::UrlEncode($repository + "issues/")

    [string]$url = ($vsixUploadEndpoint + "?repo=" + $repository + "&issuetracker=" + $issueTracker)

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