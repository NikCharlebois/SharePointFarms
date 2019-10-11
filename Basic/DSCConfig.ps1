Configuration SPFoundations
{
    Import-DSCResource -ModuleName SharePointDSC -ModuleVersion 3.6.0.0

    #region Credentials
    $CredsSPSetup = Get-Credential -Message "Setup Account" -UserName "contoso\sp_setup"
    $CredsSPFarm  = Get-Credential -Message "Farm Account"  -UserName "contoso\sp_Farm"
    #endregion
    Node SPWFE
    {
        SPInstallPrereqs Prerequisites
        {
            IsSingleInstance     = "Yes"
            InstallerPath        = "C:\SharePoint\PrerequisiteInstaller.exe"
            OnlineMode           = $true
            PsDscRunAsCredential = $CredsSPSetup
        }

        SPInstall InstallBinaries
        {
            IsSingleInstance     = "Yes"
            BinaryDir            = "C:\SharePoint"
            ProductKey           = "M692G-8N2JP-GG8B2-2W2P7-YY7J6"
            PsDscRunAsCredential = $CredsSPSetup
        }

        SPFarm CreateFarm
        {
            IsSingleInstance         = "Yes"
            RunCentralAdmin          = $true
            FarmConfigDatabaseName   = "WSS_Config"          
            AdminContentDatabaseName = "WSS_Admin"
            DatabaseServer           = "SPSQL"
            FarmAccount              = $CredsSPFarm
            PassPhrase               = $CredsSPSetup
            PsDscRunAsCredential     = $CredsSPSetup
        }
    }

    Node SPAPP
    {
        SPInstallPrereqs Prerequisites
        {
            IsSingleInstance     = "Yes"
            InstallerPath        = "C:\SharePoint\PrerequisiteInstaller.exe"
            OnlineMode           = $true
            PsDscRunAsCredential = $SPSetup
        }

        SPInstall InstallBinaries
        {
            IsSingleInstance     = "Yes"
            BinaryDir            = "C:\SharePoint"
            ProductKey           = "M692G-8N2JP-GG8B2-2W2P7-YY7J6"
            PsDscRunAsCredential = $SPSetup
        }

        WaitForAny WFECreatedFarm
        {
            ResourceName     = "[SPFarm]CreateFarm"
            NodeName         = "SPWFE"
            RetryIntervalSec = 60
            RetryCount       = 15
        }

        SPFarm JoinFarm
        {
            IsSingleInstance         = "Yes"
            RunCentralAdmin          = $False
            FarmConfigDatabaseName   = "WSS_Config"          
            AdminContentDatabaseName = "WSS_Admin"
            DatabaseServer           = "SPSQL"
            FarmAccount              = $CredsSPFarm
            PassPhrase               = $CredsSPSetup
            PsDscRunAsCredential     = $CredsSPSetup
        }
    }

    Node SPSearch
    {
        SPInstallPrereqs Prerequisites
        {
            IsSingleInstance     = "Yes"
            InstallerPath        = "C:\SharePoint\PrerequisiteInstaller.exe"
            OnlineMode           = $true
            PsDscRunAsCredential = $SPSetup
        }

        SPInstall InstallBinaries
        {
            IsSingleInstance     = "Yes"
            BinaryDir            = "C:\SharePoint"
            ProductKey           = "M692G-8N2JP-GG8B2-2W2P7-YY7J6"
            PsDscRunAsCredential = $SPSetup
        }

        WaitForAny WFECreatedFarm
        {
            ResourceName     = "[SPFarm]CreateFarm"
            NodeName         = "SPWFE"
            RetryIntervalSec = 60
            RetryCount       = 15
        }

        SPFarm JoinFarm
        {
            IsSingleInstance         = "Yes"
            RunCentralAdmin          = $False
            FarmConfigDatabaseName   = "WSS_Config"          
            AdminContentDatabaseName = "WSS_Admin"
            DatabaseServer           = "SPSQL"
            FarmAccount              = $CredsSPFarm
            PassPhrase               = $CredsSPSetup
            PsDscRunAsCredential     = $CredsSPSetup
        }
    }
}

$settings = @{
    AllNodes = @(
        @{
            NodeName = "SPWFE"
            PsDscAllowPlaintextPassword = $true
        },
        @{
            NodeName = "SPAPP"
            PsDscAllowPlaintextPassword = $true
        },
        @{
            NodeName = "SPSearch"
            PsDscAllowPlaintextPassword = $true
        }
    )
}

SPFoundations -ConfigurationData $settings