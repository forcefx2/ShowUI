##Requires -Version 2.0
####################################################################################################
if(!(Test-Path Variable::PowerBootsPath)) {
New-Variable PowerBootsPath $PSScriptRoot -Description "PowerBoots Variable: The root folder for PowerBoots" -Option Constant, ReadOnly, AllScope -Scope Global
}
$ParameterHashCache = @{}
$DependencyProperties = @{}
if(Test-Path $PowerBootsPath\DependencyPropertyCache.clixml) {
   $DependencyProperties = [System.Windows.Markup.XamlReader]::Parse( (gc $PowerBootsPath\DependencyPropertyCache.xml) )
}
$LoadedAssemblies = @(); 

$null = [Reflection.Assembly]::Load( "PresentationFramework, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" )

## Dotsource these rather than autoloading because we're guaranteed to need them
. "$PowerBootsPath\Core\Add-BootsFunction.ps1"
. "$PowerBootsPath\Core\Set-DependencyProperty.ps1"
. "$PowerBootsPath\Core\Set-PowerBootsProperties.ps1"
. "$PowerBootsPath\Core\UtilityFunctions.ps1"
. "$PowerBootsPath\Core\ContentProperties.ps1"

## Dotsource this because calling it from inside AutoLoad messes with the -Scope value
# . "$PowerBootsPath\Core\Export-NamedControl.ps1"

## Autoload these for public consumption if needed
AutoLoad "$PowerBootsPath\Core\New-BootsImage.ps1" New-BootsImage PowerBoots
## TODO: This would be a great function to add, if we could make it ADD instead of SET.
# AutoLoad "$PowerBootsPath\New Functions\Add-ChildControl.ps1" Add-ChildControl PowerBoots

## Add-EventHandler is deprecated because the compiled Register-BootsEvent is a better way
#. "$PowerBootsPath\New Functions\Add-EventHandler.ps1"
## TODO: Can Register-BootsEvent be an actual PSEvent and still execute on the thread the way I need it to?

## Select-ChildControl (aka: Get-ChildControl) is deprecated because Export-NamedControls is a better way
#. "$PowerBootsPath\New Functions\Select-ChildControl.ps1"
## I don't need this one, 'cause I've integrated it into the core! ;)
# . "$PowerBootsPath\New Functions\ConvertTo-DataTemplate.ps1"

## TODO: I'm not really sure how these fit in yet
# "$PowerBootsPath\Core\ConvertTo-GridLength.ps1"
# "$PowerBootsPath\Extras\Enable-Multitouch.ps1"
# "$PowerBootsPath\Extras\Export-Application.ps1"

# This is #Requires -STA
New-Variable IsSTA ([System.Threading.Thread]::CurrentThread.ApartmentState -eq "STA") -Description "PowerBoots Variable: Whether the host is in Single-Threaded Apartment (STA) mode."

## In case they delete the "Deprecated" folder (like I would)...
if(Test-Path "$PowerBootsPath\Deprecated\Out-BootsWindow.ps1") {
   if( !$IsSTA ) { 
      function Out-BootsWindow {
         Write-Error "Out-BootsWindow disabled in MTA mode. Use New-BootsWindow instead. (You must run PowerShell with -STA switch to enable Out-BootsWindow)"
      }
   } else { # Requires -STA
      AutoLoad "$PowerBootsPath\Deprecated\Out-BootsWindow.ps1" Out-BootsWindow PowerBoots
   }
}

## Thanks to Autoload, I'm not altering the path ...
## Put the scripts into the path
#  [string[]]$path = ${Env:Path}.Split(";")
#  if($path -notcontains "$PowerBootsPath\Types_Generated\") {
   #  ## Note: Functions in "Types_StaticOverrides" override regular functions
   #  $path += "$PowerBootsPath\Types_StaticOverrides\","$PowerBootsPath\Types_Generated\"
   #  ${Env:Path} = [string]::Join(";", $path)
#  }


## Autoload all the functions ....
if(!(Get-ChildItem "$PowerBootsPath\Types_Generated\New-*.ps1" -ErrorAction SilentlyContinue)) {
   & "$PowerBootsPath\Core\Reset-DefaultBoots.ps1"
}

foreach($script in Get-ChildItem "$PowerBootsPath\Types_Generated\New-*.ps1", "$PowerBootsPath\Types_StaticOverrides\New-*.ps1" -ErrorAction 0) {
   $TypeName = $script.Name -replace 'New-(.*).ps1','$1'
   
   Set-Alias -Name "$($TypeName.Split('.')[-1])" "New-$TypeName"        -EA "SilentlyContinue" -EV +ErrorList
   AutoLoad $Script.FullName "New-$TypeName" PowerBoots
   # Write-Host -fore yellow $(Get-Command "New-$TypeName" | Out-String)
}

## Extra aliases....
$errorList = @()
## We don't need this work around for the "Grid" alias anymore
## but we preserve compatability by still generating GridPanel (which is what the class ought to be anyway?)
Set-Alias -Name GridPanel  -Value "New-System.Windows.Controls.Grid"   -EA "SilentlyContinue" -EV +ErrorList
if($ErrorList.Count) { Write-Warning """GridPanel"" alias not created, you must use New-System.Windows.Controls.Grid" }

$errorList = @()
Set-Alias -Name Boots      -Value "New-BootsWindow"         -EA "SilentlyContinue" -EV +ErrorList
if($ErrorList.Count) { Write-Warning "Boots alias not created, you must use the full New-BootsWindow function name!" }

$errorList = @()
Set-Alias -Name BootsImage -Value "Out-BootsImage"          -EA "SilentlyContinue" -EV +ErrorList
if($ErrorList.Count) { Write-Warning "BootsImage alias not created, you must use the full Out-BootsImage function name!" }

Set-Alias -Name obi    -Value "Out-BootsImage"          -EA "SilentlyContinue"
Set-Alias -Name sdp    -Value "Set-DependencyProperty"  -EA "SilentlyContinue"
Set-Alias -Name gbw    -Value "Get-BootsWindow"         -EA "SilentlyContinue"
Set-Alias -Name rbw    -Value "Remove-BootsWindow"      -EA "SilentlyContinue"
                                                    
$BootsFunctions = @("Add-BootsFunction", "Set-DependencyProperty", "New-*") +
                  @("Get-BootsModule", "Get-BootsAssemblies", "Get-Parameter", "Get-BootsParam" ) + 
                  @("Get-BootsContentProperty", "Add-BootsContentProperty", "Remove-BootsContentProperty") +
                  @("Get-BootsHelp", "Get-BootsCommand", "Out-BootsWindow", "New-BootsImage") +
                  @("Select-BootsElement","Select-ChildControl", "Add-ChildControl", "Add-EventHandler" ) +
                  @("ConvertTo-GridLength", "Enable-MultiTouch", "Export-Application") + 
                  @("Autoloaded", "Export-NamedElement")

Export-ModuleMember -Function $BootsFunctions -Cmdlet (Get-Command -Module PoshWpf) -Alias * -Variable "PowerBootsPath", "IsSTA"
