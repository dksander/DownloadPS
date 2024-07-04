<# 
 .Synopsis
 Script to run deploy on from AL-Go-PTE
 .Description
    To Be Developed
#>

param(
    $BCVersion,
    $BCInstance,
    $syncMode,
    $appPath,
    $appName,
    $ServiceToRestart,
    $serverToRestart
)
$debug = $true;
#$debug = $false;
function PreLoadModule() {
    if (!(Get-Package -Name BcContainerHelper -ErrorAction Ignore)) {
        Write-Host "Installing BCContainerHelper PowerShell package"
        Install-Package BcContainerHelper -Force -WarningAction Ignore | Out-Null
    }
}

function ImportModule{
    Param (
        [string] $modulePath
    )
    
    if (Test-Path $modulePath) {
        Import-Module $modulePath -WarningAction SilentlyContinue | Out-Null 
    } else {
        throw "Could not find $modulePath"
    }
}
Function TestBCServiceIsRunning() {
  $navServerServiceName =  "MicrosoftDynamicsNavServer`$" + $BCInstance;
  try {
      $nstStatus = (get-service "$navServerServiceName").Status;
      if ($nstStatus -ne 'Running') {
          throw "$navServerServiceName service not running"
      }
  } catch {
      throw "$navServerServiceName service not installed"
  }
}

Function StopService {
    Param (
        $servers,
        $services
        )
    foreach($server in $servers) {
            foreach($service in $services) {
                Write-Host 'Stopping' $service 'on' $server;
                $ServiceName = 'MicrosoftDynamicsNavServer$' + $service
                invoke-Command -ComputerName $server -ScriptBlock {Stop-Service -Name $Using:ServiceName }
            }
    }
}
Function StartService {
    Param (
        $servers,
        $services
        )
    foreach($server in $servers) { 
        foreach($service in $services) {
            Write-Host 'Starting' $service 'on' $server;
            $ServiceName = 'MicrosoftDynamicsNavServer$' + $service
            invoke-Command -ComputerName $server -ScriptBlock {Start-Service -Name $Using:ServiceName }
        }
    }
}
Function BuildAppList() {
    #Search in App folder and add apps to list
    $appfiles = @();
    foreach($item in Get-ChildItem -Path $appPath -Recurse -Filter '*app') {
        $appfiles += $item.FullName;
    }

    #Sort app in dependencies 
    Sort-AppFilesByDependencies -appFiles $appfiles;
}
Function ImportBCModule() {
    $navAdminToolPath = $ENV:ProgramFiles + '\Microsoft Dynamics 365 Business Central\' + $BCVersion + '\Service\NavAdminTool.ps1'
    ImportModule $navAdminToolPath
}
$ErrorOccured = $false;
$ErrorList = New-Object "System.Collections.Generic.List[String]"


#Testing service
TestBCServiceIsRunning;

#Import PS modules
write-host 'Loading modules';
PreLoadModule;
ImportBCModule;

write-host 'Stopping services';
#Stop Service
if( !$debug) {
    StopService -servers $serverToRestart -services $ServiceToRestart
}


write-host 'Create app list';
#Search in App folder and add apps to list
$appfiles = BuildAppList;



# publish app / upgrade app
write-host 'Publishing app(s)...';

Foreach($appPath in $appfiles) {
    $AppInfo = Get-NAVAppInfo -Path $appPath
    if (Get-NAVAppInfo -ServerInstance $BCInstance -Name $AppInfo.Name) {
        write-host 'Upgrading:' $AppInfo.Name
        $AppversionInstalled = (Get-NAVAppInfo -ServerInstance $BCInstance -Name $AppInfo.Name -Version $AppInfo.version);
        if($AppversionInstalled.version -gt $AppInfo.version) {
            try {
                    Write-host 'Publishing..';
                    Publish-NAVApp -ServerInstance $BCInstance -Path $appPath -SkipVerification
                    Write-host 'Syncing..';
                    Sync-NAVApp -ServerInstance $BCInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.version
                    Write-host 'Upgrading..';
                    Start-NAVAppDataUpgrade -ServerInstance $BCInstance -Name  $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.version
                }
            catch {
                $ErrorOccured = $true;
                $ErrorList.add($_.Exception.Message);
            }
        }
        else {
            write-host $AppInfo.Name 'with version' $AppInfo.version 'or newer is already installed';
        }
    }
    else {
        write-host 'Installing:' $AppInfo.Name
        try {
            Write-host 'Publishing..';
            Publish-NAVApp -ServerInstance $BCInstance -Path $appPath -SkipVerification
            Write-host 'Syncing..';
            Sync-NAVApp -ServerInstance $BCInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.version
            Write-host 'Installing..';
            Install-NAVApp -ServerInstance $BCInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.version
        }
        catch {
            $ErrorOccured = $true;
            $ErrorList.add($_.Exception.Message);
        }
    }
    $ExistApp = Get-NAVAppInfo -ServerInstance $BCInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.version
    if($ExistApp -ne $null) {
        if($ExistApp.Version = $AppInfo.Version) {
            write-host 'App' $AppInfo.Name  'is installed' -BackgroundColor Green        
        }
    }
}
#####
#####
# Start services again
if( !$debug) {
    StartService -servers $serverToRestart -services $ServiceToRestart
}

# Write if error occured
IF ($ErrorOccured) {
    Clear-Host
    Write-Host 'One or more error occured, please handle error' -BackgroundColor Red
    if(!$ErrorList.Count -eq 0) {
        Write-Host 'Errors occured is as following:' -BackgroundColor Red
        foreach($e in $ErrorList) {
            Write-Host $e -BackgroundColor Red
        }
    }
}
else {
    Write-Host 'All Apps was installed' -BackgroundColor Green
}
