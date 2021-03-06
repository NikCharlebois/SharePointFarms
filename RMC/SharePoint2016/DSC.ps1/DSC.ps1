#
# Copyright="© Microsoft Corporation. All rights reserved."
#

configuration Config
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [String]$primaryAdIpAddress = "10.0.0.4",

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetup,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPFarm,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Passphrase,

        [parameter(Mandatory)]
        [String]$DatabaseName,

        [parameter(Mandatory)]
        [String]$AdministrationContentDatabaseName,

        [parameter(Mandatory)]
        [String]$DatabaseServer,
        
        [parameter(Mandatory)]
        [String]$Configuration,

        [parameter(Mandatory)]
        [String]$InstallSourceDrive,
    
        [parameter(Mandatory)]
        [String]$InstallSourceFolderName,

        [parameter(Mandatory)]
        [String]$ProductKey,

        [parameter(Mandatory)]
        [String]$SPDLLink,

        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$Credsspsapppool = New-Object System.Management.Automation.PSCredential ("rmc-cmr\spsapppool", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$Credsspssvcsearch = New-Object System.Management.Automation.PSCredential ("rmc-cmr\spssvcsearch", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$Credsspssvc = New-Object System.Management.Automation.PSCredential ("rmc-cmr\spssvc", $Admincreds.Password)

    $currentDNS = (Get-DnsClientServerAddress -InterfaceAlias Ethernet -Family IPv4).ServerAddresses
    $newdns = @($primaryAdIpAddress) + $currentDNS
    Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $currentDNS
    ipconfig /flushdns
    ipconfig /registerdns

    # Get the disk number of the data disk
    $dataDisk = Get-Disk | where{$_.PartitionStyle -eq "RAW"}
    $dataDiskNumber = $dataDisk[0].Number

    Import-DscResource -ModuleName "xComputerManagement" -ModuleVersion "3.1.0.0"
    Import-DscResource -ModuleName "xDisk" -ModuleVersion "1.0"
    Import-DscResource -ModuleName "cDisk" -ModuleVersion "1.0"
    Import-DscResource -ModuleName "xNetworking" -ModuleVersion "5.3.0.0"
    Import-DscResource -ModuleName "SharePointDSC" -ModuleVersion "3.0.0.0"
    Import-DscResource -ModuleName "xDownloadISO" -ModuleVersion "1.0"
    Import-DscResource -ModuleName "xDownloadFile" -ModuleVersion "1.0"

    Node localhost
    {
        xDownloadISO DownloadTAPBits
        {
            SourcePath               = $SPDLLink
            DestinationDirectoryPath = "c:\SharePoint"
            PsDscRunAsCredential     = $Admincreds
        }

        xDownloadFile PointFireLP
        {
            SourcePath               = "https://dscpackages.blob.core.windows.net/rmcpackages/icefire.pointfire.res._1036.wsp"
            FileName                 = "icefire.pointfire.res._1036.wsp"
            DestinationDirectoryPath = "c:\Solutions"
            PsDscRunAsCredential     = $Admincreds
        }

        xDownloadFile PointFire
        {
            SourcePath               = "https://dscpackages.blob.core.windows.net/rmcpackages/pointfire2016.features.wsp"
            FileName                 = "pointfire2016.features.wsp"
            DestinationDirectoryPath = "c:\Solutions"
            PsDscRunAsCredential     = $Admincreds
        }

        xDownloadFile Extradium
        {
            SourcePath               = "https://dscpackages.blob.core.windows.net/rmcpackages/riolinx.extradium.core.wsp"
            FileName                 = "riolinx.extradium.core.wsp"
            DestinationDirectoryPath = "c:\Solutions"
            PsDscRunAsCredential     = $Admincreds
        }

        xDownloadFile Branding
        {
            SourcePath               = "https://dscpackages.blob.core.windows.net/rmcpackages/rmc_sp2016_branding.wsp"
            FileName                 = "rmc_sp2016_branding.wsp"
            DestinationDirectoryPath = "c:\Solutions"
            PsDscRunAsCredential     = $Admincreds
        }

        xWaitforDisk Disk2
        {
            DiskNumber           = $dataDiskNumber
            RetryIntervalSec     = $RetryIntervalSec
            RetryCount           = $RetryCount
            PsDscRunAsCredential = $Admincreds
        }

        cDiskNoRestart SPDataDisk
        {
            DiskNumber           = $dataDiskNumber
            DriveLetter          = "F"
            DependsOn            = "[xWaitforDisk]Disk2"
            PsDscRunAsCredential = $Admincreds
        }

        WindowsFeature DotNet
        {
            Name                 = "Net-Framework-Core"
            Ensure               = 'Present'
            PsDscRunAsCredential = $Admincreds
        }

        xComputer DomainJoin
        {
            Name                 = $env:COMPUTERNAME
            DomainName           = $DomainName
            Credential           = $AdminCreds
            PsDscRunAsCredential = $Admincreds
        }

        Script DisableFirewall
        {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result = -not('True' -in (Get-NetFirewallProfile -All).Enabled)        
                }
            }
            SetScript = {
                Set-NetFirewallProfile -All -Enabled False -Verbose
            }    
            TestScript = {
                $Status = -not('True' -in (Get-NetFirewallProfile -All).Enabled)
                $Status -eq $True
            }
        }

        Group AddUserAccountToLocalAdminsGroup
        {
            GroupName            = "Administrators"
            Credential           = $DomainCreds
            MembersToInclude     = @($SPSetup.UserName, $SPFarm.UserName)
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainCreds
        }

        SPInstallPrereqs Prereqs
        {
            IsSIngleInstance     = "Yes"
            InstallerPath        = "C:\SharePoint\PrerequisiteInstaller.exe"
            OnlineMode           = $true
            PsDscRunAsCredential = $DomainCreds
        }

        SPInstall Install
        {
            IsSingleInstance     = "Yes"
            BinaryDir            = "C:\SharePoint"
            ProductKey           = $ProductKey
            PsDscRunAsCredential = $DomainCreds
        }

        SPFarm PSConfig
        {
            IsSingleInstance         = "Yes"
            FarmConfigDatabaseName   = "SP_Config"
            DatabaseServer           = $DatabaseServer
            FarmAccount              = $SPFarm
            Passphrase               = $Passphrase
            AdminContentDatabaseName = $AdministrationContentDatabaseName
            ServerRole               = "Custom"
            RunCentralAdmin          = $true
            PsDscRunAsCredential     = $SPSetup
        }
	SPManagedAccount 2682501a-4330-4a59-988b-313fdb9fe3cf
        {
            Account              = $Credsspssvc;
            AccountName          = $Credsspssvc.UserName;
            PsDscRunAsCredential = $SPSetup;
            Ensure               = "Present";
            EmailNotification    = 5;
            Schedule             = "";
            PreExpireDays        = 2;
        }
        SPManagedAccount 4d928202-7c24-4dd8-9f2a-1850e481db7d
        {
            Account              = $Credsspsapppool;
            AccountName          = $Credsspsapppool.UserName;
            PsDscRunAsCredential = $SPSetup;
            Ensure               = "Present";
            EmailNotification    = 5;
            Schedule             = "";
            PreExpireDays        = 2;
        }
        SPManagedAccount 40d84194-da26-4c2d-863c-52472da2b8ea
        {
            Account              = $Credsspssvcsearch;
            AccountName          = $Credsspssvcsearch.UserName;
            PsDscRunAsCredential = $SPSetup;
            Ensure               = "Present";
            EmailNotification    = 5;
            Schedule             = "";
            PreExpireDays        = 2;
        }
        SPWebApplication Collab
        {
            DatabaseName           = "WSS_Content_Collab_Application";
            ApplicationPool        = "SharePoint - Collab";
            Path                   = "C:\inetpub\wwwroot\wss\VirtualDirectories\collab.rmc.ca80";
            PsDscRunAsCredential   = $SPSetup
            AllowAnonymous         = $False;
            Name                   = "Collab";
            Ensure                 = "Present";
            UseClassic             = $False;
            ApplicationPoolAccount = "rmc-cmr\spsapppool"
            DatabaseServer         = $DatabaseServer;
            WebAppUrl              = "https://collab.rmc.ca/";
            HostHeader             = "collab.rmc.ca";
        }
        SPDesignerSettings WebApplication39a52782-4a1d-4224-a15d-c67e6db35d0f
        {
            SettingsScope                          = "WebApplication";
            PsDscRunAsCredential                   = $SPSetup;
            AllowSharePointDesigner                = $True;
            AllowDetachPagesFromDefinition         = $True;
            AllowCustomiseMasterPage               = $True;
            WebAppUrl                              = "https://collab.rmc.ca/";
            AllowCreateDeclarativeWorkflow         = $True;
            AllowSavePublishDeclarativeWorkflow    = $True;
            AllowSaveDeclarativeWorkflowAsTemplate = $True;
            AllowManageSiteURLStructure            = $True;
            DependsOn = "[SPWebApplication]Collab";
        }
        SPOutgoingEmailSettings 27b12872-b207-4390-b7dd-b3f234433ce8
        {
            FromAddress          = "sharepoint-admin@rmc-cmr.ca";
            CharacterSet         = "65001";
            PsDscRunAsCredential = $SPSetup;
            SMTPServer           = "email.rmc.ca";
            ReplyToAddress       = "sharepoint-admin@rmc-cmr.ca";
            SMTPPort             = 0;
            UseTLS               = $True;
            WebAppUrl            = "https://collab.rmc.ca/";
            DependsOn = "[SPWebApplication]Collab";
        }
        SPWebApplication Dept
        {
            DatabaseName           = "WSS_Content_AMS_DB";
            ApplicationPool        = "SharePoint - Dept";
            Path                   = "C:\inetpub\wwwroot\wss\VirtualDirectories\Dept.rmc.ca443";
            PsDscRunAsCredential   = $SPSetup;
            AllowAnonymous         = $False;
            Name                   = "Dept";
            Ensure                 = "Present";
            UseClassic             = $False;
            ApplicationPoolAccount = "rmc-cmr\spsapppool";
            DatabaseServer         = $DatabaseServer;
            WebAppUrl              = "https://dept.rmc.ca/";
            HostHeader             = "dept.rmc.ca";
        }
        SPDesignerSettings WebApplication564b36f0-a5bc-4570-94bf-7a141c20f541
        {
            SettingsScope                          = "WebApplication";
            PsDscRunAsCredential                   = $SPSetup;
            AllowSharePointDesigner                = $True;
            AllowDetachPagesFromDefinition         = $True;
            AllowCustomiseMasterPage               = $True;
            WebAppUrl                              = "https://dept.rmc.ca/";
            AllowCreateDeclarativeWorkflow         = $True;
            AllowSavePublishDeclarativeWorkflow    = $True;
            AllowSaveDeclarativeWorkflowAsTemplate = $True;
            AllowManageSiteURLStructure            = $True;
            DependsOn = "[SPWebApplication]Dept";
        }
        SPOutgoingEmailSettings 590b7ad5-ebf6-43bd-b9b0-2b30ce1e26d8
        {
            FromAddress          = "sharepoint-admin@rmc-cmr.ca";
            CharacterSet         = "65001";
            PsDscRunAsCredential = $SPSetup;
            SMTPServer           = "email.rmc.ca";
            ReplyToAddress       = "sharepoint-admin@rmc-cmr.ca";
            SMTPPort             = 0;
            UseTLS               = $True;
            WebAppUrl            = "https://dept.rmc.ca/";
            DependsOn = "[SPWebApplication]Dept";
        }
        SPWebApplication MySites
        {
            DatabaseName           = "WSS_Content_MySite_Root";
            ApplicationPool        = "SharePoint - MySites";
            Path                   = "C:\inetpub\wwwroot\wss\VirtualDirectories\MySites.rmc.ca443";
            PsDscRunAsCredential   = $SPSetup;
            AllowAnonymous         = $False;
            Name                   = "MySites";
            Ensure                 = "Present";
            UseClassic             = $False;
            ApplicationPoolAccount = "rmc-cmr\spsapppool";
            DatabaseServer         = $DatabaseServer;
            WebAppUrl              = "https://mysites.rmc.ca/";
            HostHeader             = "mysites.rmc.ca";
        }
        SPDesignerSettings WebApplication36d33471-77c3-42b8-a7ce-606bb9730be7
        {
            SettingsScope                          = "WebApplication";
            PsDscRunAsCredential                   = $SPSetup
            AllowSharePointDesigner                = $True;
            AllowDetachPagesFromDefinition         = $True;
            AllowCustomiseMasterPage               = $True;
            WebAppUrl                              = "https://mysites.rmc.ca/";
            AllowCreateDeclarativeWorkflow         = $True;
            AllowSavePublishDeclarativeWorkflow    = $True;
            AllowSaveDeclarativeWorkflowAsTemplate = $True;
            AllowManageSiteURLStructure            = $True;
            DependsOn = "[SPWebApplication]MySites";
        }
        SPOutgoingEmailSettings a80687ad-2a62-4594-b5c6-ad7b606596cf
        {
            FromAddress          = "sharepoint-admin@rmc-cmr.ca";
            CharacterSet         = "65001";
            PsDscRunAsCredential = $SPSetup
            SMTPServer           = "email.rmc.ca";
            ReplyToAddress       = "sharepoint-admin@rmc-cmr.ca";
            SMTPPort             = 0;
            UseTLS               = $True;
            WebAppUrl            = "https://mysites.rmc.ca/";
            DependsOn = "[SPWebApplication]MySites";
        }

        SPFarmSolution PointFireLP
        {
            Version              = "";
            Deployed             = $True;
            SolutionLevel        = "14";
            PsDscRunAsCredential = $SPSetup;
            Name                 = "icefire.pointfire.res._1036.wsp";
            Ensure               = "Present";
            LiteralPath          = "C:\Solutions\icefire.pointfire.res._1036.wsp";
            WebAppUrls           = @("https://mysites.rmc.ca/","https://collab.rmc.ca/");
        }
        SPFarmSolution PointFire
        {
            Version              = "";
            Deployed             = $True;
            SolutionLevel        = "14";
            PsDscRunAsCredential = $SPSetup;
            Name                 = "pointfire2016.features.wsp";
            Ensure               = "Present";
            LiteralPath          = "C:\Solutions\pointfire2016.features.wsp";
            WebAppUrls           = @("https://dept.rmc.ca/","https://mysites.rmc.ca/","https://collab.rmc.ca/");
        }
        SPFarmSolution Extradium
        {
            Version              = "";
            Deployed             = $True;
            SolutionLevel        = "14";
            PsDscRunAsCredential = $SPSetup;
            Name                 = "riolinx.extradium.core.wsp";
            Ensure               = "Present";
            LiteralPath          = "C:\Solutions\riolinx.extradium.core.wsp";
            WebAppUrls           = @();
        }
        SPFarmSolution Branding
        {
            Version              = "";
            Deployed             = $True;
            SolutionLevel        = "14";
            PsDscRunAsCredential = $SPSetup;
            Name                 = "rmc_sp2016_branding.wsp";
            Ensure               = "Present";
            LiteralPath          = "C:\Solutions\rmc_sp2016_branding.wsp";
            WebAppUrls           = @();
        }

        LocalConfigurationManager 
        {
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $true 
        }
    }
}
