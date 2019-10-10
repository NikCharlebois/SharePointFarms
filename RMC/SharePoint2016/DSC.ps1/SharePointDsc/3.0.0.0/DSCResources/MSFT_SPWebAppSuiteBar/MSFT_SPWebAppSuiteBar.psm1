function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebAppUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoNavigationUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoTitle,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingText,

        [Parameter()]
        [System.String]
        $SuiteBarBrandingElementHtml,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Getting web app suite bar properties for $WebAppUrl"

    $result = Invoke-SPDSCCommand -Credential $InstallAccount `
                                  -Arguments $PSBoundParameters `
                                  -ScriptBlock {
        $params = $args[0]

        $wa = Get-SPWebApplication -Identity $params.WebAppUrl `
                                   -ErrorAction SilentlyContinue

        $returnval = @{
            WebAppUrl = $wa.Url
            SuiteNavBrandingLogoNavigationUrl = $null
            SuiteNavBrandingLogoTitle = $null
            SuiteNavBrandingLogoUrl = $null
            SuiteNavBrandingText = $null
            SuiteBarBrandingElementHtml = $null
        }

        if ($null -eq $wa)
        {
            return $returnval
        }

        $installedVersion = Get-SPDSCInstalledProductVersion

        if($installedVersion.FileMajorPart -eq 15)
        {
            $returnval.SuiteBarBrandingElementHtml = $wa.SuiteBarBrandingElementHtml
        }
        elseif($installedVersion.FileMajorPart -ge 16)
        {
            $returnval.SuiteNavBrandingLogoNavigationUrl = $wa.SuiteNavBrandingLogoNavigationUrl
            $returnval.SuiteNavBrandingLogoTitle = $wa.SuiteNavBrandingLogoTitle
            $returnval.SuiteNavBrandingLogoUrl = $wa.SuiteNavBrandingLogoUrl
            $returnval.SuiteNavBrandingText = $wa.SuiteNavBrandingText
        }

        return $returnval
    }
    return $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebAppUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoNavigationUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoTitle,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingText,

        [Parameter()]
        [System.String]
        $SuiteBarBrandingElementHtml,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Setting web app suite bar properties for $WebAppUrl"

    $installedVersion = Get-SPDSCInstalledProductVersion

    <# Handle SP2013 #>
    switch($installedVersion.FileMajorPart)
    {
        15
        {
            <# Exception: One of the SP2016/SP2019 specific parameter was passed with SP2013 #>
            if($PSBoundParameters.ContainsKey("SuiteNavBrandingLogoNavigationUrl") `
            -or $PSBoundParameters.ContainsKey("SuiteNavBrandingLogoTitle") `
            -or $PSBoundParameters.ContainsKey("SuiteNavBrandingLogoUrl") `
            -or $PSBoundParameters.ContainsKey("SuiteNavBrandingText"))
            {
                throw ("Cannot specify SuiteNavBrandingLogoNavigationUrl, SuiteNavBrandingLogoTitle, " + `
                                        "SuiteNavBrandingLogoUrl or SuiteNavBrandingText with SharePoint 2013. Instead," + `
                                        " only specify the SuiteBarBrandingElementHtml parameter")
            }

            <# Exception: The SP2013 optional parameter is null. #>
            if(!$PSBoundParameters.ContainsKey("SuiteBarBrandingElementHtml"))
            {
                throw ("You need to specify a value for the SuiteBarBrandingElementHtml parameter with" + `
                                        " SharePoint 2013")
            }
        }
        16
        {
            <# Exception: The SP2013 specific SuiteBarBrandingElementHtml parameter was passed with SP2016. #>
            if($PSBoundParameters.ContainsKey("SuiteBarBrandingElementHtml"))
            {
                throw ("Cannot specify SuiteBarBrandingElementHtml with SharePoint 2016 and 2019. Instead," + `
                                        " use the SuiteNavBrandingLogoNavigationUrl, SuiteNavBrandingLogoTitle, " + `
                                        "SuiteNavBrandingLogoUrl and SuiteNavBrandingText parameters")
            }

            <# Exception: All the optional parameters are null for SP2016/SP2019. #>
            if(!$PSBoundParameters.ContainsKey("SuiteNavBrandingLogoNavigationUrl") `
            -and !$PSBoundParameters.ContainsKey("SuiteNavBrandingLogoTitle") `
            -and !$PSBoundParameters.ContainsKey("SuiteNavBrandingLogoUrl") `
            -and !$PSBoundParameters.ContainsKey("SuiteNavBrandingText"))
            {
                throw ("You need to specify a value for either SuiteNavBrandingLogoNavigationUrl" + `
                                        ", SuiteNavBrandingLogoTitle, SuiteNavBrandingLogoUrl and SuiteNavBrandingText " + `
                                        "with SharePoint 2016 and 2019")
            }
        }
    }

    $CurrentValues = Get-TargetResource @PSBoundParameters

    if ($null -eq $CurrentValues.WebAppUrl)
    {
        throw "Web application does not exist"
    }

    ## Perform changes
    Invoke-SPDSCCommand -Credential $InstallAccount `
                        -Arguments @($PSBoundParameters) `
                        -ScriptBlock {
        $params = $args[0]

        $installedVersion = Get-SPDSCInstalledProductVersion

        $wa = Get-SPWebApplication -Identity $params.WebAppUrl -ErrorAction SilentlyContinue

        if ($null -eq $wa)
        {
            throw "Specified web application could not be found."
        }

        Write-Verbose -Message "Processing changes"

        if($installedVersion.FileMajorPart -eq 15)
        {
            $wa.SuiteBarBrandingElementHtml = $params.SuiteBarBrandingElementHtml
        }
        elseif($installedVersion.FileMajorPart -ge 16)
        {
            $wa.SuiteNavBrandingLogoNavigationUrl = $params.SuiteNavBrandingLogoNavigationUrl
            $wa.SuiteNavBrandingLogoTitle = $params.SuiteNavBrandingLogoTitle
            $wa.SuiteNavBrandingLogoUrl = $params.SuiteNavBrandingLogoUrl
            $wa.SuiteNavBrandingText = $params.SuiteNavBrandingText
        }
        $wa.Update()
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $WebAppUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoNavigationUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoTitle,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingLogoUrl,

        [Parameter()]
        [System.String]
        $SuiteNavBrandingText,

        [Parameter()]
        [System.String]
        $SuiteBarBrandingElementHtml,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Testing web app suite bar properties for $WebAppUrl"

    $CurrentValues = Get-TargetResource @PSBoundParameters

    if ($null -eq $CurrentValues.WebAppUrl)
    {
        return $false
    }

    return Test-SPDscParameterState -CurrentValues $CurrentValues `
    -DesiredValues $PSBoundParameters `
    -ValuesToCheck @("Ensure")
}

Export-ModuleMember -Function *-TargetResource
