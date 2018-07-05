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
    $targetDir = "_drafts"

    if (!$Draft) {
        $targetDir = "_posts"
        $fileTitle = "{0}-{1:D2}-{2:D2}-{3}" -f $Date.Year, $Date.Month, $Date.Day, $fileTitle
    }
    
    return Join-Path -Path $targetDir -ChildPath $fileTitle
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

    if (!$Draft -And !(Test-Path -Path _posts)) {
        New-Item -Path _posts -ItemType Directory
    }

    if ($Draft -And !(Test-Path -Path _drafts)) {
        New-Item -Path _drafts -ItemType Directory
    }

    $targetPath = Get-JekyllFileName -Title $Title -Date $now
    if ($Draft) {
        $targetPath = Get-JekyllFileName -Title $Title -Date $now -Draft $Draft
    }

    if (!(Test-Path -Path $targetPath)) {
        Out-File -FilePath $targetPath -Append -InputObject "---"
        Out-File -FilePath $targetPath -Append -InputObject "layout: post"
        Out-File -FilePath $targetPath -Append -InputObject "title: $Title"
        Out-File -FilePath $targetPath -Append -InputObject ("categories: [" + ($categories -join ", ") + "]")

        if (!$Draft) {
            Out-File -FilePath $targetPath -Append -InputObject ("date: " + $now.ToString("yyyy-MM-dd HH:mm:ss"))
        }

        Out-File -FilePath $targetPath -Append -InputObject "---"
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
        [string] $Title
    )

    $now = Get-Date

    $draftLocation = Get-JekyllFileName -Title $Title -Date $now -Draft $true

    if (Test-Path -Path $draftLocation) {
        $postLocation = Get-JekyllFileName -Title $Title -Date $now

        $headerCount = 0 
        $hasDate = $false
        Get-Content -Path $draftLocation | ForEach-Object {
            if ($_.ToString().StartsWith("date: ")) {
                $hasDate = $true
            }

            if ($_.ToString().Equals("---")) {
                $headerCount += 1
                if ($headerCount.Equals(2) -And !$hasDate) {
                    Out-File -FilePath $postLocation -Append -InputObject ("date: " + $now.ToString("yyyy-MM-dd HH:mm:ss"))
                    $hasDate = $true
                }
            }

            Out-File -FilePath $postLocation -Append -InputObject $_
        }

        if (Test-Path -Path $postLocation) {
            Remove-Item -Path $draftLocation
        }
    }
}