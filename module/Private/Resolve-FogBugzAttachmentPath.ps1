function Resolve-FogBugzAttachmentPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$AttachmentPath
    )

    $resolved = New-Object System.Collections.Generic.List[object]
    $seen = @()

    foreach ($path in $AttachmentPath) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        if ($item.PSIsContainer) {
            Write-Warning "Directory attachment '$($item.FullName)' will upload top-level files only."
            $children = @(Get-ChildItem -LiteralPath $item.FullName -File -Force -ErrorAction Stop)
            $excluded = @(
                $children | Where-Object {
                    (([int]$_.Attributes -band [int][System.IO.FileAttributes]::Hidden) -ne 0) -or
                    (([int]$_.Attributes -band [int][System.IO.FileAttributes]::System) -ne 0)
                }
            )
            if ($excluded.Count -gt 0) {
                Write-Warning "Skipping $($excluded.Count) hidden or system file(s) in '$($item.FullName)'."
            }

            foreach ($child in $children) {
                if (
                    (([int]$child.Attributes -band [int][System.IO.FileAttributes]::Hidden) -ne 0) -or
                    (([int]$child.Attributes -band [int][System.IO.FileAttributes]::System) -ne 0)
                ) {
                    continue
                }

                if ($seen -notcontains $child.FullName) {
                    $seen += $child.FullName
                    $resolved.Add($child)
                }
            }
            continue
        }

        if ($seen -notcontains $item.FullName) {
            $seen += $item.FullName
            $resolved.Add($item)
        }
    }

    if ($resolved.Count -eq 0) {
        throw 'No uploadable attachments were found.'
    }

    $resolved.ToArray()
}

