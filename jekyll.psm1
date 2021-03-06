<#
.Synopsis
Gets the path to a file for a jekyll blog

.Description
Gets the path to a file for a jekyll blog

.Parameter Title
The title of the blog post

.Parameter Date
The timestamp of when the post should be published

.Parameter Draft
Flag indicating that the blog post is a draft file
#>
function Get-JekyllFileName {
    param(
        [string] $Title,
        [datetime] $Date,
        [switch] $Draft
    )
    
    $fileTitle = (($title.ToLower() -replace "[^\w\s]", "") -replace "\s+", "-") + ".md"
    $targetDir = ".\_drafts"

    if (!$Draft) {
        $targetDir = ".\_posts"
        $fileTitle = "{0}-{1:D2}-{2:D2}-{3}" -f $Date.Year, $Date.Month, $Date.Day, $fileTitle
    }
    
    return Join-Path -Path $targetDir -ChildPath $fileTitle
}

<#
.Description
Gets the title from an entry 

.Parameter Path
The path to the entry
#>
function Get-JekyllPostTitle {
    param(
        [string] $Path
    )

    $titleSearch = "^title:\s+(.+)"
    Get-Content -Path $Path | Where-Object { $_ -match $titleSearch } | ForEach-Object {
        return ($_ | Select-String -Pattern $titleSearch).Matches[0].Groups[1].ToString()
    }
}

<#
.Synopsis
Lists out posts and drafts

.Description
Lists out posts and drafts

.Parameter Drafts
If set and -Posts not set, lists drafts only. If neither are set lists both

.Parameter Posts
If set and -Drafts not set, lists posts only. If neither are set lists both
#>
function Get-JekyllEntries {
    param(
        [switch] $Drafts = $false,
        [switch] $Posts = $false
    )

    $list = @()
    if ((!$Posts -or $Drafts) -and (Test-Path -Path ".\_drafts")) {
        Get-ChildItem -Path ".\_drafts" | ForEach-Object {
            $title = Get-JekyllPostTitle -Path $_.FullName
            $list += New-Object PSObject -Property @{ State="Draft"; Title=$title; Path=$_.FullName }
        }
    }

    if ((!$Drafts -or $Posts) -and (Test-Path -Path ".\_posts")) {
        Get-ChildItem -Path ".\_posts" | ForEach-Object {
            $title = Get-JekyllPostTitle -Path $_.FullName
            $list += New-Object PSObject -Property @{ State="Post"; Title=$title; Path=$_.FullName }
        }
    }

    return $list
}

<#
.Synopsis
Creates a new Jekyll Post

.Description
Creates a new Jekyll Jekyll Blog Post/Draft

.Parameter Title
The title of the blog post

.Parameter Categories
The categories the blog post belongs to

.Parameter Draft
Flag indicating that the blog post is a draft file
#>
function New-JekyllPost {
    param(
        [string] $Title,
        [string[]] $Categories = "uncategorized",
        [switch] $Draft = $false
    )

    $now = Get-Date

    if (!$Draft -and !(Test-Path -Path ".\_posts")) {
        New-Item -Path ".\_posts" -ItemType Directory > $null
    }

    if ($Draft -and !(Test-Path -Path ".\_drafts")) {
        New-Item -Path ".\_drafts" -ItemType Directory > $null
    }

    $targetPath = Get-JekyllFileName -Title $Title -Date $now
    if ($Draft) {
        $targetPath = Get-JekyllFileName -Title $Title -Date $now -Draft $Draft
    }

    if (!(Test-Path -Path $targetPath)) {
        Out-File -Encoding UTF8 -FilePath $targetPath -Append -InputObject "---"
        Out-File -Encoding UTF8 -FilePath $targetPath -Append -InputObject "layout: post"
        Out-File -Encoding UTF8 -FilePath $targetPath -Append -InputObject "title: $Title"
        Out-File -Encoding UTF8 -FilePath $targetPath -Append -InputObject ("categories: [" + ($categories -join ", ") + "]")

        if (!$Draft) {
            Out-File -Encoding UTF8 -FilePath $targetPath -Append -InputObject ("date: " + $now.ToString("yyyy-MM-dd HH:mm:ss"))
        }

        Out-File -Encoding UTF8 -FilePath $targetPath -Append -InputObject "---"
    }
}

Class CurrentDrafts : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return Get-JekyllEntries -Drafts | ForEach-Object { $_.Title }
    }
}

<#
.Synopsis
Publishes an existing Jekyll Draft

.Description
Moves a draft entry to posts to be published

.Parameter Title
The title of the blog post
#>
function Publish-JekyllDraft {
    param(
        [ValidateSet([CurrentDrafts])][string] $Title
    )

    $now = Get-Date

    $draftLocation = Get-JekyllFileName -Title $Title -Date $now -Draft $true

    if (Test-Path -Path $draftLocation) {
        $postLocation = Get-JekyllFileName -Title $Title -Date $now

        if (!(Test-Path -Path ".\_posts")) {
            New-Item -Path ".\_posts" -ItemType Directory > $null
        }

        if (Test-Path -Path $postLocation) {
            Write-Error -Message "Post already exists, cannot publish draft $Title"
        } else {
            $headerCount = 0 
            $hasDate = $false
            Get-Content -Path $draftLocation | ForEach-Object {
                if ($_.ToString().StartsWith("date: ")) {
                    $hasDate = $true
                }

                if ($_.ToString().Equals("---")) {
                    $headerCount += 1
                    if ($headerCount.Equals(2) -and !$hasDate) {
                        Out-File -Encoding UTF8 -FilePath $postLocation -Append -InputObject ("date: " + $now.ToString("yyyy-MM-dd HH:mm:ss"))
                        $hasDate = $true
                    }
                }

                Out-File -Encoding UTF8 -FilePath $postLocation -Append -InputObject $_
            }

            if (Test-Path -Path $postLocation) {
                Remove-Item -Path $draftLocation
            }
        }
    }
}
