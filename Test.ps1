﻿cd $PSScriptRoot

# (new-object Net.WebClient).DownloadString("https://raw.github.com/tom-englert/BuildScripts/master/BuildScripts.ps1") | iex

(Get-Content "BuildScripts.ps1") -join "`r`n" | iex

$version = 42
$repository = "tom-englert/test"

function Assert-AreEqual
{
    $expected = $args[0]
    $actual = $args[1]
    if ($expected -ne $actual)
    {        
        "Assert failed"
        "Expected: $expected"
        "Actual:   $actual"
        throw [System.InvalidOperationException] "Items are not equal"
    }
}

function Assert-FilesEqual
{
    $fileName = $args[0]

    $expected = (Get-Content "$PSScriptRoot\TestFiles\Expected\$fileName") -join "`r`n"
    $actual = (Get-Content "$PSScriptRoot\TestFiles\Test\$fileName") -join "`r`n"

    Assert-AreEqual $expected $actual
}

New-Item "TestFiles\Test" -ItemType "directory" -Force
Copy-Item "TestFiles\Source\*.*" "TestFiles\Test" -Force


$uploadUrl = Vsix-GetUpoadUrl $repository
Assert-AreEqual "http://vsixgallery.com/api/upload?repo=https%3a%2f%2fgithub.com%2ftom-englert%2ftest&issuetracker=https%3a%2f%2fgithub.com%2ftom-englert%2ftest%2fissues" $uploadUrl

Source-SetBuildVersion "$PSScriptRoot\TestFiles\Test\version.cs" $version
Assert-FilesEqual "version.cs"

Vsix-SetBuildVersion "$PSScriptRoot\TestFiles\Test\source.extension.vsixmanifest" $version
Assert-FilesEqual "source.extension.vsixmanifest"

Project-SetBuildVersion "$PSScriptRoot\TestFiles\Test\ResXManager.csproj" $version
Assert-FilesEqual "ResXManager.csproj"

