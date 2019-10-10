function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]  
        [System.String] 
        $SiteUrl,

        [Parameter()] 
        [System.Management.Automation.PSCredential] 
        $InstallAccount
    )

    Write-Verbose -Message "Getting app catalog status of $SiteUrl"

    $result = Invoke-SPDSCCommand -Credential $InstallAccount `
                                  -Arguments $PSBoundParameters `
                                  -ScriptBlock {
        $params = $args[0]

        $site = Get-SPSite $params.SiteUrl -ErrorAction SilentlyContinue
        $nullreturn = @{
            SiteUrl = $null
            InstallAccount = $params.InstallAccount
        }
        if ($null -eq $site) 
        {
            return $nullreturn
        }
        $wa = $site.WebApplication
        $feature = $wa.Features.Item([Guid]::Parse("f8bea737-255e-4758-ab82-e34bb46f5828"))
        if($null -eq $feature) 
        {
            return $nullreturn
        }
        if ($site.ID -ne $feature.Properties["__AppCatSiteId"].Value) 
        {
            return $nullreturn
        } 
        return @{
            SiteUrl = $site.Url
            InstallAccount = $params.InstallAccount
        }
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
        $SiteUrl,

        [Parameter()] 
        [System.Management.Automation.PSCredential] 
        $InstallAccount
    )

    Write-Verbose -Message "Setting app catalog status of $SiteUrl"

    Invoke-SPDSCCommand -Credential $InstallAccount `
                        -Arguments $PSBoundParameters `
                        -ScriptBlock {
        $params = $args[0]
        try 
        {
            Update-SPAppCatalogConfiguration -Site $params.SiteUrl -Confirm:$false 
        }
        catch [System.UnauthorizedAccessException] 
        {
            throw ("This resource must be run as the farm account (not a setup account). " + `
                   "Please ensure either the PsDscRunAsCredential or InstallAccount " + `
                   "credentials are set to the farm account and run this resource again")
        }
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
        $SiteUrl,

        [Parameter()] 
        [System.Management.Automation.PSCredential] 
        $InstallAccount
    )

    Write-Verbose -Message "Testing app catalog status of $SiteUrl"

    return Test-SPDscParameterState -CurrentValues (Get-TargetResource @PSBoundParameters) `
                                    -DesiredValues $PSBoundParameters `
                                    -ValuesToCheck @("SiteUrl") 
}

Export-ModuleMember -Function *-TargetResource
