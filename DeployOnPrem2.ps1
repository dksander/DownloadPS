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
)
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

#Do some pretest on App files
###############################

#Testing service
TestBCServiceIsRunning();
PreLoadModule;


######
#Stop service
#####


#####
# Sort app
#####
#####
# test if app needs to be published
#####
#####
# publish app / upgrade app
#####
#####
# Start services again
#####
#####
# Write back new apps installed
#####




