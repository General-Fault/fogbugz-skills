function Get-FogBugzResponseValue {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [xml]) {
        $nodes = $InputObject.SelectNodes('//*')
        foreach ($node in $nodes) {
            if ($node.LocalName -ieq $Name) {
                return $node.InnerText
            }
        }
    }

    if ($InputObject -is [System.Xml.XmlNode]) {
        foreach ($child in $InputObject.ChildNodes) {
            if ($child.LocalName -ieq $Name) {
                return $child.InnerText
            }
        }

        foreach ($attribute in $InputObject.Attributes) {
            if ($attribute.LocalName -ieq $Name) {
                return $attribute.Value
            }
        }
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

