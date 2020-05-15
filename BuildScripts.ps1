#remove semantic version suffixes from a version string, e.g. 3.3.4-beta1 => 3.3.4
function Version-Sanitize
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$version
    )

    $PATTERN = "(\d+)\-[\w\d]+"
    $REPLACEMENT = "`$1"

    return $version -replace $PATTERN, $REPLACEMENT
}

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
    $propertyGroup = $projectXml.Project.PropertyGroup | Select -First 1
    [Version]$version = $propertyGroup.ApplicationVersion

    $major = [math]::Max([int]$version.Major, 0)
    $minor = [math]::Max([int]$version.Minor, 0)
    $revision = [math]::Max([int]$version.Revision, 0)

    $version = New-Object Version ([int]$major),([int]$minor),$buildNumber,$revision

    $propertyGroup.ApplicationVersion = [string]$version

    $projectXml.Save($projectFilePath)

    return [string]$version
}

# update the version number in a project file by replacing the build number part with the specified value. 
# returns the updated version
function Project-SetVersion
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$projectFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    "Project-SetVersion: $projectFilePath, $buildNumber" | Write-Host

    [xml]$projectXml=Get-Content $projectFilePath

    $propertyGroup = $projectXml.Project.PropertyGroup | Select -First 1

    $version = $propertyGroup.Version
    $replacement = "`$1.$buildNumber`$3"
    $version = $version -replace '(\d+\.\d+)(\.\d+)?(.*)', $replacement

    $propertyGroup.Version = $version

    $projectXml.Save($projectFilePath)

    return [string]$version
}

# update the version number in a project file by replacing the revision part with the specified value. 
# returns the updated version
function Project-SetVersionRevision
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$projectFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    "Project-SetVersionRevision: $projectFilePath, $buildNumber" | Write-Host

    [xml]$projectXml=Get-Content $projectFilePath

    $propertyGroup = $projectXml.Project.PropertyGroup | Select -First 1

    $version = $propertyGroup.Version
    $replacement = "`$1.$buildNumber`$3"
    $version = $version -replace '(\d+\.\d+\.\d+)\.(\d+)(.*)', $replacement

    $propertyGroup.Version = $version

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

# update the version number in a C# source file by replacing the revision number with the specified value. 
# the version must be represented in the file as 'version = "#.#.#.#', usually 'const string version = "#.#.#.#";'
# returns the updated version
function Source-SetBuildVersionToRevision
{
    [cmdletbinding()]
    param (
        [Parameter(Position=0, Mandatory=1, ValueFromPipeline=$true)]
        [string]$sourceFilePath,

        [Parameter(Position=1, Mandatory=0)]
        [int]$buildNumber = $env:BUILD_BUILDID
    )

    "Source-SetBuildVersionToRevision: $sourceFilePath, $buildNumber" | Write-Host

    $source = Get-Content $sourceFilePath
    $replacement = "`$1.$buildNumber`$2"
    $source = $source -replace '(version\s+=\s+"\d+.\d+.\d+).\d+(")', $replacement
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