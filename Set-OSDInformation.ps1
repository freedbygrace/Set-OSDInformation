#Requires -Version 3

<#
    .SYNOPSIS
    Records the requested deployment information into the system during operating system deployment (OSD).
          
    .DESCRIPTION
    This script will add build, task sequence, and other information to the operating system so that it can later be examined or inventoried. That data can then be used as the driving force behind SCCM collections, and or SCCM reports.
    Information can be added to the registry, WMI, or both.
          
    .PARAMETER Registry
    Records the requested deployment information into the registry for later examination or usage.

    .PARAMETER RegistryKeyPath
    Specifies the registry key path where the requested deployment information will be recorded when the registry parameter is specified. Input will be validated by a regular expression that forces the specified path to start with a registry hive location, followed by a colon, a backslash, and finally the path you want after that.
    Example: "HKLM:\Software\SomeRegistryPath"

    .PARAMETER WMI
    Records the requested deployment information into WMI for later examination or usage.

    .PARAMETER Namespace
    A valid WMI namespace. If the WMI namespace does not exist, it will be created.

    .PARAMETER Class
    A valid WMI class. If the WMI class does not exist, it will be created. The class will be removed and recreated if it exists!

    .PARAMETER ClassDescription
    A valid string. This string will be set as the WMI class description.

    .PARAMETER OSDVariablePrefix
    Any valid string that ends with an underscore will be used as the attribute prefix.
    If you create a task sequence during operating system deployment and prefix the task sequence variable name with what is specified in this parameter, that task sequence variable will be dynamically detected by this script and included as part of information recorded within WMI or the registry without additional modification of this script.
    This parameter will be validated using a regular expression to ensure that the string ends with an underscore and is formatted like the following. Example: "MyOSDVariablePrefix_"

    .PARAMETER DestinationTimeZoneID
    A valid string. Specify a time zone ID that exists on the current system. Input will be validated against the list of time zones available on the system.
    All date/time operations within this script will converted the current system time to the destination timezone for standardization. That time will then be converted to UTC. The UTC time will then be converted to the WMI format and stored.

    .PARAMETER FinalConversionTimeZoneID
    A valid string. Specify a time zone ID that exists on the current system. Input will be validated against the list of time zones available on the system.
    All date/time operations within this script will convert the timestamps to the final conversion timezone ID. UTC by default.
    
    .PARAMETER LogDir
    A valid folder path. If the folder does not exist, it will be created. This parameter can also be specified by the alias "LogPath".

    .PARAMETER ContinueOnError
    Ignore failures.
          
    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Set-OSDInformation.ps1"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Set-OSDInformation.ps1" -WMI -Namespace "Root\CIMv2" -Class "Custom_OSD_Info" -OSDVariablePrefix "CustomOSDInfo_" -LogDir "%_SMSTSLogPath%\Set-OSDInformation"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Set-OSDInformation.ps1" -Registry -RegistryKeyPath "HKLM:\Software\Microsoft\Deployment\CustomOSDInfo" -OSDVariablePrefix "CustomOSDInfo_" -LogDir "%_SMSTSLogPath%\Set-OSDInformation"
  
    .NOTES
    Additional function(s) are required and will be imported automatically for this script to function properly. Look inside the "%ScriptDirectory%\Functions" folder.
    When the values get written to WMI, the attribute prefix will be removed automatically so that the value(s) in the registry or WMI will not have that prefix and be easier to read.
    Create an SCCM package (the legacy kind) that points to the folder containing all file(s)/folder(s) included with this script and simply reference that package during the task sequence by using the "Run Powershell Script" action.
    All Date/Time values can be converted to the traditional Date/Time format from the WMI Date/Time format by using the following command ([System.Management.ManagementDateTimeConverter]::ToDateTime("YourDateAndTime")). They were placed in this format to allow data sorting and conversion once the data is inventoried, which would not be possible by just using strings.
          
    .LINK
    https://github.com/freedbygrace/Set-OSDTime
    
    .LINK
    https://powershell.one/wmi/datatypes

    .LINK
    https://gallery.technet.microsoft.com/Tatoo-custom-information-e1febe32

    .LINK
    http://woshub.com/how-to-set-timezone-from-command-prompt-in-windows/
    
    .LINK
    https://devblogs.microsoft.com/scripting/powertip-use-powershell-to-retrieve-the-date-and-time-of-the-given-time-zone-id/
#>

[CmdletBinding()]
    Param
        (        	     
            [Parameter(Mandatory=$False)]
            [Switch]$Registry,

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^HKLM|^HKCU|^HKCR|^HKU|^HKCC|^HKPD\:\\.*$')})]
            [Alias('RKP')]
            [String]$RegistryKeyPath = "HKLM:\Software\Microsoft\Deployment\CustomOSDInfo",

            [Parameter(Mandatory=$False)]
            [Switch]$WMI,
                        
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^Root\\.*')})]
            [Alias('NS')]
            [String]$Namespace = "Root\CIMv2",

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [String]$Class = "Custom_OSD_Info",
            
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [String]$ClassDescription = "Contains operating system deployment details that can be inventoried and used for reporting and/or collection criteria purposes.",

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^.*\_$')})]
            [Alias('OSDVP')]
            [String]$OSDVariablePrefix = "CustomOSDInfo_",
            
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -iin ([System.TimeZoneInfo]::GetSystemTimeZones().ID | Sort-Object))})]
            [Alias('DTZID')]
            [String]$DestinationTimeZoneID = "Eastern Standard Time",

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -iin ([System.TimeZoneInfo]::GetSystemTimeZones().ID | Sort-Object))})]
            [Alias('FCTZID')]
            [String]$FinalConversionTimeZoneID = "UTC",
            
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^[a-zA-Z][\:]\\.*?[^\\]$')})]
            [Alias('LogPath')]
            [System.IO.DirectoryInfo]$LogDir = "$($Env:Windir)\Logs\Software\Set-OSDInformation",
            
            [Parameter(Mandatory=$False)]
            [Switch]$ContinueOnError
        )

#Define Default Action Preferences
    $Script:DebugPreference = 'SilentlyContinue'
    $Script:ErrorActionPreference = 'Stop'
    $Script:VerbosePreference = 'SilentlyContinue'
    $Script:WarningPreference = 'Continue'
    $Script:ConfirmPreference = 'None'
    
#Load WMI Classes
  $Baseboard = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_Baseboard" -Property * | Select-Object -Property *
  $Bios = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_Bios" -Property * | Select-Object -Property *
  $ComputerSystem = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_ComputerSystem" -Property * | Select-Object -Property *
  $OperatingSystem = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_OperatingSystem" -Property * | Select-Object -Property *

#Retrieve property values
  $OSArchitecture = $($OperatingSystem.OSArchitecture).Replace("-bit", "").Replace("32", "86").Insert(0,"x").ToUpper()

#Define variable(s)
  $DateTimeLogFormat = 'dddd, MMMM dd, yyyy hh:mm:ss tt'  ###Monday, January 01, 2019 10:15:34 AM###
  [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
  $DateTimeFileFormat = 'yyyyMMdd_hhmmsstt'  ###20190403_115354AM###
  [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
  [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Definition)"
  [System.IO.FileInfo]$ScriptLogPath = "$($LogDir.FullName)\$($ScriptPath.BaseName)_$($GetCurrentDateTimeFileFormat.Invoke()).log"
  [System.IO.DirectoryInfo]$ScriptDirectory = "$($ScriptPath.Directory.FullName)"
  [System.IO.DirectoryInfo]$FunctionsDirectory = "$($ScriptDirectory.FullName)\Functions"
  [System.IO.DirectoryInfo]$ModulesDirectory = "$($ScriptDirectory.FullName)\Modules"
  [System.IO.DirectoryInfo]$ToolsDirectory = "$($ScriptDirectory.FullName)\Tools\$($OSArchitecture)"
  $IsWindowsPE = Test-Path -Path 'HKLM:\SYSTEM\ControlSet001\Control\MiniNT' -ErrorAction SilentlyContinue
	
#Log task sequence variables if debug mode is enabled within the task sequence
  Try
    {
        [System.__ComObject]$TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment"
              
        If ($TSEnvironment -ine $Null)
          {
              $IsRunningTaskSequence = $True
          }
    }
  Catch
    {
        $IsRunningTaskSequence = $False
    }

#Start transcripting (Logging)
  Try
    {
        If ($LogDir.Exists -eq $False) {[Void][System.IO.Directory]::CreateDirectory($LogDir.FullName)}
        Start-Transcript -Path "$($ScriptLogPath.FullName)" -IncludeInvocationHeader -Force -Verbose
    }
  Catch
    {
        If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message)"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
        $ErrorMessage = "[Error Message: $($ExceptionMessage)][ScriptName: $($_.InvocationInfo.ScriptName)][Line Number: $($_.InvocationInfo.ScriptLineNumber)][Line Position: $($_.InvocationInfo.OffsetInLine)][Code: $($_.InvocationInfo.Line.Trim())]"
        Write-Error -Message "$($ErrorMessage)"
    }

#Log any useful information
  $LogMessage = "IsWindowsPE = $($IsWindowsPE.ToString())"
  Write-Verbose -Message "$($LogMessage)" -Verbose

  $LogMessage = "Script Path = $($ScriptPath.FullName)"
  Write-Verbose -Message "$($LogMessage)" -Verbose

  $DirectoryVariables = Get-Variable | Where-Object {($_.Value -ine $Null) -and ($_.Value -is [System.IO.DirectoryInfo])}
  
  ForEach ($DirectoryVariable In $DirectoryVariables)
    {
        $LogMessage = "$($DirectoryVariable.Name) = $($DirectoryVariable.Value.FullName)"
        Write-Verbose -Message "$($LogMessage)" -Verbose
    }

#region Import Dependency Modules
$Modules = Get-Module -Name "$($ModulesDirectory.FullName)\*" -ListAvailable -ErrorAction Stop 

$ModuleGroups = $Modules | Group-Object -Property @('Name')

ForEach ($ModuleGroup In $ModuleGroups)
  {
      $LatestModuleVersion = $ModuleGroup.Group | Sort-Object -Property @('Version') -Descending | Select-Object -First 1
      
      If ($LatestModuleVersion -ine $Null)
        {
            $LogMessage = "Attempting to import dependency powershell module `"$($LatestModuleVersion.Name) [Version: $($LatestModuleVersion.Version.ToString())]`". Please Wait..."
            Write-Verbose -Message "$($LogMessage)" -Verbose
            Import-Module -Name "$($LatestModuleVersion.Path)" -Prefix "X" -Global -DisableNameChecking -Force -Verbose -ErrorAction Stop
        }
  }
#endregion

#region Dot Source Dependency Scripts
#Dot source any additional script(s) from the functions directory. This will provide flexibility to add additional functions without adding complexity to the main script and to maintain function consistency.
  Try
    {
        If ($FunctionsDirectory.Exists -eq $True)
          {
              [String[]]$AdditionalFunctionsFilter = "*.ps1"
        
              $AdditionalFunctionsToImport = Get-ChildItem -Path "$($FunctionsDirectory.FullName)" -Include ($AdditionalFunctionsFilter) -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}
        
              $AdditionalFunctionsToImportCount = $AdditionalFunctionsToImport | Measure-Object | Select-Object -ExpandProperty Count
        
              If ($AdditionalFunctionsToImportCount -gt 0)
                {                    
                    ForEach ($AdditionalFunctionToImport In $AdditionalFunctionsToImport)
                      {
                          Try
                            {
                                $LogMessage = "Attempting to dot source dependency script `"$($AdditionalFunctionToImport.Name)`". Please Wait...`r`n`r`nDependency Script Path: `"$($AdditionalFunctionToImport.FullName)`""
                                Write-Verbose -Message "$($LogMessage)" -Verbose
                          
                                . "$($AdditionalFunctionToImport.FullName)"
                            }
                          Catch
                            {
                                $ErrorMessage = "[Error Message: $($_.Exception.Message)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]"
                                Write-Error -Message "$($ErrorMessage)" -Verbose
                            }
                      }
                }
          }
    }
  Catch
    {
        $ErrorMessage = "[Error Message: $($_.Exception.Message)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]"
        Write-Error -Message "$($ErrorMessage)" -Verbose            
    }
#endregion

#Perform script action(s)
  Try
    {                          
        #Tasks defined within this block will only execute if a task sequence is running
          If (($IsRunningTaskSequence -eq $True))
            {            
                  #Determine the specified time zone properties
                    $OriginalTimeZone = Get-TimeZone
                    $DestinationTimeZone = Get-TimeZone -ID "$($DestinationTimeZoneID)"
                    $FinalConversionTimeZone = Get-TimeZone -ID "$($FinalConversionTimeZoneID)"
                  
                  #Load any required assemblies
                    [Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
            
                  #Create an empty array to store the combined/final set of OSD variable(s)
                    $OSDVariables = @()
                  
                  #Create an empty array to store the default OSD variable(s)
                    $DefaultOSDVariables = @()
                  
                  #Determine if we are running within a Microsoft Deployment Toolkit or Configuration Manager task sequence based on the "_SMSTSPackageID" task sequence variable. This will only be populated within Configuration Manager task sequences, which allows for the comparison.
                    [Boolean]$IsConfigurationManagerTaskSequence = [String]::IsNullOrEmpty($TSEnvironment.Value("_SMSTSPackageID")) -eq $False
            
                  #The variable(s) listed below will always get written to the storage location(s) as a standard (Default variable(s) can be specified based on whether a Microsoft Deployment Toolkit or Configuration Manager task sequence is running.
                    If ($IsConfigurationManagerTaskSequence -eq $True)
                      {
                          [String]$DeploymentProduct = "SCCM"
                      
                          [String[]]$DefaultOSDVariableList = @(
                                                                  "_SMSTSPackageName",
                                                                  "_SMSTSBootImageID",
                                                                  "_SMSTSPackageID",
                                                                  "_SMSTSMediaType",
                                                                  "_SMSTSSiteCode",
                                                                  "_SMSTSLaunchMode",
                                                                  "_SMSTSUserStarted",
                                                                  "OSBuildVersion",
                                                                  "_SMSTSBootUEFI",
                                                                  "SMSDP",
                                                                  "_SMSTSAdvertID",
                                                                  "DeploymentMethod",
                                                                  "_SMSTSTaskSequence"
                                                              )
                      }
                    ElseIf ($IsConfigurationManagerTaskSequence -eq $False)
                      {
                          [String]$DeploymentProduct = "MDT"
                      
                          [String[]]$DefaultOSDVariableList = @(
                                                                  "_SMSTSBootUEFI",
                                                                  "SMSDP",
                                                                  "InstallFromPath",
                                                                  "TaskSequenceVersion",
                                                                  "DeploymentMethod",
                                                                  "DeploymentType",
                                                                  "DeployRoot",
                                                                  "ImageIndex",
                                                                  "ImageFlags",
                                                                  "ImageBuild",
                                                                  "WDSServer",
                                                                  "TaskSequenceID"
                                                              )
                      }
                                                                                  
                    #Always define a variable that details when the system was deployed. The timestamp is according to when this script calculated the current date/time which is converted to the destination time zone ID, then to UTC, then converted to the WMI format and stored.
                      $DefaultOSDVariables += (Set-Variable -Name "DeploymentTimestamp" -Value ((Get-Process -ID $PID).StartTime) -PassThru -Force -Verbose)
            
                    #Always define a variable that details which product deployed the task sequence
                      $DefaultOSDVariables += (Set-Variable -Name "DeploymentProduct" -Value ($DeploymentProduct) -PassThru -Force -Verbose)
            
                    #Sort the default OSD variable list alphabetically and only return the unique value(s)
                      $DefaultOSDVariableListSorted = $DefaultOSDVariableList | Sort-Object -Unique
                      
                    #Create a variable for each default variable specified
                      ForEach ($DefaultOSDVariable In $DefaultOSDVariableListSorted)
                        {
                            $DefaultOSDVariableValueConverted = $Null
                        
                            #Remove all instances of invalid character(s) from the variable name(s) using a regular expression. This is to avoid potential WMI property creation error(s).
                              $DefaultOSDVariableName = $DefaultOSDVariable -ireplace "(_)|(\s)|(\.)", ""
                              
                            #Retrieve the value of the task sequence variable
                              $DefaultOSDVariableValue = $TSEnvironment.Value($DefaultOSDVariable) 
                      
                            #Attempt to retrieve data that can only be retrieved from within the xml definition of the task seqence, otherwise, by default, just retrieve the variable value from the task sequence com object
                              Switch ($DefaultOSDVariable)
                                {
                                    {($_ -imatch '.*Date.*|.*Timestamp.*|.*Start.*Time.*|.*End.*Time.*')}
                                      {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [DateTime] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          [DateTime]$DefaultOSDVariableValueAsDateTime = Get-Date -Date "$($DefaultOSDVariableValue)"
                                          [DateTime]$ConvertedDefaultOSDVariableDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($DefaultOSDVariableValueAsDateTime), ($DestinationTimeZone.ID))
                                          [DateTime]$ConvertedDefaultOSDVariableDateTimeFinal = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($ConvertedDefaultOSDVariableDateTime), ($FinalConversionTimeZone.ID))
                                          [DateTime]$DefaultOSDVariableValueConverted = $ConvertedDefaultOSDVariableDateTimeFinal
                                      }
                          
                                    {($DefaultOSDVariableValue -imatch "^True$|^False$")}
                                      {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          $DefaultOSDVariableValueConverted = [Boolean]::Parse($DefaultOSDVariableValue)
                                      }
                                                    
                                    {($DefaultOSDVariableValue -imatch "^Yes$")}
                                      {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          $DefaultOSDVariableValueConverted = [Boolean]::Parse("True")
                                      }
                                                    
                                    {($DefaultOSDVariableValue -imatch "^No$")}
                                      {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          $DefaultOSDVariableValueConverted = [Boolean]::Parse("False")
                                      }
                                      
                                    {([Microsoft.VisualBasic.Information]::IsNumeric($DefaultOSDVariableValue))}
                                      {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          $DefaultOSDVariableValueConverted = [Double]::Parse($DefaultOSDVariableValue)
                                      }
                                      
                                    {($_ -imatch '^_SMSTSTaskSequence$') -and ($IsConfigurationManagerTaskSequence -eq $True)}
                                      {
                                          $LogMessage = "Attempting to retrieve the `"ImagePackageID`" from the `"$($_)`" task sequence variable. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          $TaskSequenceXMLDefinition_ImagePackageID = @(Select-Xml -Content ($DefaultOSDVariableValue) -XPath "//variable[@name='ImagePackageID']")
                                          
                                          $DefaultOSDVariableValueConverted = "$($TaskSequenceXMLDefinition_ImagePackageID[0].Node.InnerText)"
                                          
                                          If ([String]::IsNullOrEmpty($DefaultOSDVariableValueConverted) -eq $False)
                                            {

                                                
                                                $DefaultOSDVariables += (Set-Variable -Name "ImagePackageID" -Value ($DefaultOSDVariableValueConverted) -PassThru -Force -Verbose)
                                            }
                                      }
                          
                                    Default
                                      {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [String] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          $DefaultOSDVariableValueConverted = [String]::New($DefaultOSDVariableValue)
                                      }    
                                }
                                
                            $DefaultOSDVariables += (Set-Variable -Name "$($DefaultOSDVariableName)" -Value ($DefaultOSDVariableValueConverted) -PassThru -Force -Verbose) 
                        }
                    	                	
                  #Add the default OSD variables to the final variable array
                    $OSDVariables += ($DefaultOSDVariables)
                  
                  #Create an empty array to store the custom set of OSD variable(s)
                    $CustomOSDVariables = @()
            
                  #Dynamically retrieve the additional task sequence variable(s) based on their prefix and add them to the information that will be written to either WMI, the registry, or both
                    $RetrievedCustomOSDVariables = $TSEnvironment.GetVariables() | Where-Object {($_ -imatch "$($OSDVariablePrefix).*")}
  
                  #Sort the custom OSD variable list alphabetically and only return the unique value(s)
                    $CustomOSDVariableListSorted = $RetrievedCustomOSDVariables | Sort-Object -Unique
            
                  #Create all the variable(s) that will be written to the system in the desired storage location
                    ForEach ($CustomOSDVariable In $CustomOSDVariableListSorted)
                      {
                          $CustomOSDVariableValueConverted = $Null
                      
                          #Remove the attribute prefix from the variable name(s). This is for cleaner output purposes.
                            $CustomOSDVariableName = $CustomOSDVariable -ireplace "$($OSDVariablePrefix)", ""
                            
                          #Retrieve the value of the task sequence variable
                            $CustomOSDVariableValue = $TSEnvironment.Value($CustomOSDVariable)
                            
                          #Attempt to format any custom variable(s) to their respective data types. This is for data consistency purposes.
                            Switch ($CustomOSDVariableName)
                              {
                                  {($_ -imatch '.*Date.*|.*Timestamp.*|.*Start.*Time.*|.*End.*Time.*')}
                                    {
                                          $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [DateTime] type. Please Wait..."
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                          [DateTime]$CustomOSDVariableValueAsDateTime = Get-Date -Date "$($CustomOSDVariableValue)"
                                          [DateTime]$ConvertedCustomOSDVariableDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($CustomOSDVariableValueAsDateTime), ($DestinationTimeZone.ID))
                                          [DateTime]$ConvertedCustomOSDVariableDateTimeFinal = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($ConvertedCustomOSDVariableDateTime), ($FinalConversionTimeZone.ID))
                                          [DateTime]$CustomOSDVariableValueConverted = $ConvertedCustomOSDVariableDateTimeFinal
                                    }
                                                                        
                                  {($CustomOSDVariableValue -imatch "^True$|^False$")}
                                    {
                                        $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                        Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                        $CustomOSDVariableValueConverted = [Boolean]::Parse($CustomOSDVariableValue)
                                    }
                                                    
                                  {($CustomOSDVariableValue -imatch "^Yes$")}
                                    {
                                        $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                        Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                        $CustomOSDVariableValueConverted = [Boolean]::Parse("True")
                                    }
                                                    
                                  {($CustomOSDVariableValue -imatch "^No$")}
                                    {
                                        $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Boolean] type. Please Wait..."
                                        Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                        $CustomOSDVariableValueConverted = [Boolean]::Parse("False")
                                    }
                                    
                                  {([Microsoft.VisualBasic.Information]::IsNumeric($CustomOSDVariableValue))}
                                    {
                                        $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [Double] type. Please Wait..."
                                        Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                        $CustomOSDVariableValueConverted = [Double]::Parse($CustomOSDVariableValue)
                                    }
                       
                                  Default
                                    {
                                        $LogMessage = "Attempting to cast the task sequence variable `"$($_)`" to a [String] type. Please Wait..."
                                        Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                        $CustomOSDVariableValueConverted = [String]::New($CustomOSDVariableValue)
                                    }     
                              }
                              
                            $CustomOSDVariables += (Set-Variable -Name "$($CustomOSDVariableName)" -Value ($CustomOSDVariableValueConverted) -PassThru -Force -Verbose)
                      }
                      
                  #Attempt to automatically create a timespan between the OSD Start Time and OSD End Time (This will only occur if these custom variables exist) (This data will allow you to track how long a task sequence deployment took for a device)                    
                    If (($CustomOSDVariables.Name -icontains "OSDStartTime") -and ($CustomOSDVariables.Name -icontains "OSDEndTime"))
                      {                          
                          $OSDTimeSpan = New-TimeSpan -Start ($OSDStartTime) -End ($OSDEndTime)

                          $CustomOSDVariables += (Set-Variable -Name "OSDTotalSeconds" -Value ([System.Math]::Round($OSDTimeSpan.TotalSeconds, 2)) -PassThru -Force -Verbose)
                          $CustomOSDVariables += (Set-Variable -Name "OSDTotalMinutes" -Value ([System.Math]::Round($OSDTimeSpan.TotalMinutes, 2)) -PassThru -Force -Verbose)
                          $CustomOSDVariables += (Set-Variable -Name "OSDTotalHours" -Value ([System.Math]::Round($OSDTimeSpan.TotalHours, 2)) -PassThru -Force -Verbose)
                      }
     
                  #Add the custom OSD variables to the final variable array
                    $OSDVariables += ($CustomOSDVariables)
                    
                  #Only write the collected data if the variable(s) were successfully created and populated in the OSDVariables array
                    If ($OSDVariables -ine $Null)
                      {
                          #If specified, write the OSD information to a new or existing registry key
                            If ($Registry.IsPresent -eq $True)
                              {                              
                                  ForEach ($OSDVariable in $OSDVariables)
                                    {
                                        $OSDVariableName = "$($OSDVariable.Name)"
                                
                                        If ($OSDVariable.Value -ine $Null) 
                                          {
                                              $OSDVariableValue = ($OSDVariable.Value -Join ", ").ToString().Trim()
                                          } 
                                        Else 
                                          {
                                              $OSDVariableValue = ""
                                          }
        
                                        New-RegistryItem -Key "$($RegistryKeyPath)" -ValueName "$($OSDVariableName)" -Value ($OSDVariableValue) -ValueType 'String' -Verbose
                                    }
                              }
                              
#region Dynamic MOF Creation
                          #If specified, write the OSD information to a new WMI class. The class will be removed and recreated if it exists! A MOF file will be dynamically generated and compiled using MOFCOMP with auto recovery in the event of WMI repository rebuilds. In other words, this custom WMI class will survive rebuilds of the WMI repository.
                            If ($WMI.IsPresent -eq $True)
                              {      
                                  [System.Text.StringBuilder]$MOFContents = [System.Text.StringBuilder]::New()
                                  
                                  [System.Text.StringBuilder]$WMIInstanceDefinition = [System.Text.StringBuilder]::New()
                                          
                                  [Void]$MOFContents.AppendLine()
                                          
                                  [String]$WMIClassDefinitionHeader = @"
//==================================================================
// OSD Information class and instance definition
//==================================================================

#pragma namespace (`"$("\\\\.\\$($Namespace.Replace('\', '\\'))")`")

// Class definition

#pragma deleteclass("$($Class)",nofail)
[DYNPROPS]
class $($Class)
{
	[key]
	string InstanceKey;


"@

                                  [Void]$MOFContents.Append($WMIClassDefinitionHeader)
                                    
                                    #Add properties to the newly created WMI Class, set their individual data types, and set their individual values
                                      ForEach ($OSDVariable In $OSDVariables)
                                        {
                                            [String]$OSDVariableName = $OSDVariable.Name
                                          
                                            [String]$OSDVariableType = "$($OSDVariable.Value.GetType().Name)"
                                          
                                            $OSDVariableValue = ($OSDVariable.Value -Join ", ").ToString().Trim()
                                          
                                            #Attempt to specify data type before adding the property to the WMI class
                                            #Valid values are the following: None, SInt16, SInt32, Real32, Real64, String, Boolean, Object, SInt8, UInt8, UInt16, UInt32, SInt64, UInt64, DateTime, Reference, Char16 (Example: [System.Management.CimType]::GetNames([System.Management.CimType]))
                                              Switch ($OSDVariableType)
                                                {
                                                    {($_ -imatch '.*Date.*') -or ($OSDVariableName -imatch '.*Date.*|.*Timestamp.*|.*Start.*Time.*|.*End.*Time.*')}
                                                      {
                                                          $PropertyType = "DateTime"
                                                      }
                                                  
                                                    {($_ -imatch 'Bool|Boolean')}
                                                      {
                                                          $PropertyType = "Boolean"
                                                      }
                                                    
                                                    {($_ -imatch 'Double')}
                                                      {
                                                          $PropertyType = "Real64"
                                                      }
                                                                                                        
                                                    Default
                                                      {
                                                          $PropertyType = "String"
                                                      }     
                                                }
                                                                                   
                                            $WMIPropertyDefinition = "`t$($PropertyType) $($OSDVariableName);"
                                                      
                                            $WMIInstancePropertyName = "`t$($OSDVariableName);"
                                                      
                                            [Void]$WMIInstanceDefinition.Append($WMIInstancePropertyName)
                                            [Void]$WMIInstanceDefinition.AppendLine()
                                                      
                                            [Void]$MOFContents.Append($WMIPropertyDefinition)
                                            [Void]$MOFContents.AppendLine()
                                        }
                                  
                                    [Void]$MOFContents.Append("};")
                                          
                                    [Void]$MOFContents.AppendLine()
                                    [Void]$MOFContents.AppendLine()
                                          
                                    [String]$WMIInstanceDefinitionHeader = @"
// Instance definition

[DYNPROPS]
instance of $($Class)
{
	InstanceKey = "@";

"@
                                    [Void]$MOFContents.AppendLine()
                                    [Void]$MOFContents.Append($WMIInstanceDefinitionHeader)
                                    [Void]$MOFContents.AppendLine()
                                          
                                    [Void]$MOFContents.Append($WMIInstanceDefinition.ToString())
                                                                                    
                                    [Void]$MOFContents.Append("};")
                                          
                                    [Void]$MOFContents.AppendLine()
                                    
#region Export dynamically created MOF
                                    [System.IO.FileInfo]$MOFExportPath = "$([System.Environment]::SystemDirectory)\wbem\$($ScriptPath.BaseName).mof"

                                    $LogMessage = "####################Begin MOF File Contents####################`r`n$($MOFContents.ToString())`r`n####################End MOF File Contents####################`r`n`r`n"
                                    Write-Verbose -Message "$($LogMessage)" -Verbose

                                    If ($MOFExportPath.Directory.Exists -eq $False) {[Void][System.IO.Directory]::CreateDirectory($MOFExportPath.Directory.FullName)}
                                          
                                    $MOFContents.ToString() | Out-File -FilePath "$($MOFExportPath.FullName)" -Encoding ASCII -NoNewline -Force -Verbose
#endregion

#region Import dynamically created MOF into WMI using MofComp
                                    [System.IO.FileInfo]$BinaryPath = "$([System.Environment]::SystemDirectory)\wbem\mofcomp.exe"
                                    [String]$BinaryParameters = "-AutoRecover `"$($MOFExportPath.FullName)`""
                                    [System.IO.FileInfo]$BinaryStandardOutputPath = "$($LogDir.FullName)\$($BinaryPath.BaseName)_StandardOutput.log"
                                    [System.IO.FileInfo]$BinaryStandardErrorPath = "$($LogDir.FullName)\$($BinaryPath.BaseName)_StandardError.log"
                                            
                                    If ($BinaryPath.Exists -eq $True)
                                      {
                                          $LogMessage = "Attempting to import the dynamically created MOF file. Please Wait... - [$($MOFExportPath.Name)]"
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                        
                                          $LogMessage = "Binary Path - [$($BinaryPath.FullName)]"
                                          Write-Verbose -Message "$($LogMessage)" -Verbose

                                          $LogMessage = "Binary Parameters - [$($BinaryParameters)]"
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                            
                                          $LogMessage = "Binary Standard Output Path - [$($BinaryStandardOutputPath.FullName)]"
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                            
                                          $LogMessage = "Binary Standard Error Path - [$($BinaryStandardErrorPath.FullName)]"
                                          Write-Verbose -Message "$($LogMessage)" -Verbose
                            
                                          $ExecuteBinary = Start-Process -FilePath "$($BinaryPath.FullName)" -ArgumentList "$($BinaryParameters)" -WindowStyle Hidden -Wait -RedirectStandardOutput "$($BinaryStandardOutputPath.FullName)" -RedirectStandardError "$($BinaryStandardErrorPath.FullName)" -PassThru
                            
                                          [Int[]]$AcceptableExitCodes = @('0', '3010')
                        
                                          If ($ExecuteBinary.ExitCode -iin $AcceptableExitCodes)
                                            {
                                                $LogMessage = "Binary Execution Success - [Exit Code: $($ExecuteBinary.ExitCode.ToString())]"
                                                Write-Verbose -Message "$($LogMessage)" -Verbose
                                                      
                                                $BinaryStandardOutput = Get-Content -Path "$($BinaryStandardOutputPath.FullName)" -Raw -Force
                                                  
                                                $LogMessage = "Binary Standard Output - [$($BinaryPath.Name)]`r`n$($BinaryStandardOutput.ToString())"
                                                Write-Verbose -Message "$($LogMessage)" -Verbose
                                            }
                                          Else
                                            {
                                                $ErrorMessage = "Binary Execution Error - [Exit Code: $($ExecuteBinary.ExitCode.ToString())]"
                                                Write-Error -Message "$($ErrorMessage)" -Verbose
                                                      
                                                $BinaryErrorOutput = Get-Content -Path "$($BinaryStandardErrorPath.FullName)" -Raw -Force
                                                  
                                                $ErrorMessage = "Binary Error Output - [$($BinaryPath.Name)]`r`n$($BinaryErrorOutput.ToString())"
                                                Write-Error -Message "$($ErrorMessage)" -Verbose
                                            }
                                      }

                                    #Show the WMI class BEFORE the properties get their values assigned
                                      Write-Output -InputObject (Get-WMIObject -NameSpace ($Namespace) -Class ($Class))

                                    #Retrieve the newly created WMI class and set the values of each property
                                      $CIMInstance = Get-CIMInstance -Namespace ($Namespace) -ClassName ($Class)
                                    
                                      $CIMInstanceProperties = $CIMInstance.CimInstanceProperties | Where-Object {($_.Name -iin ($OSDVariables.Name))}
                                    
                                      ForEach ($CIMInstanceProperty In $CIMInstanceProperties)
                                        {
                                            $CIMInstancePropertyName = $CIMInstanceProperty.Name
                                            
                                            $OSDVariableProperties = $OSDVariables | Where-Object {($_.Name -ieq $CIMInstancePropertyName)}
                                            
                                            $LogMessage = "Attempting to assign the WMI property value for `"$($CIMInstancePropertyName)`". Please Wait... | [Namespace: $($Namespace)] - [Class: $($Class)]"
                                            Write-Verbose -Message "$($LogMessage)" -Verbose                                     
                                            
                                            Set-CIMInstance -InputObject ($CIMInstance) -Property @{"$($CIMInstancePropertyName)" = ($OSDVariableProperties.Value)}
                                        }

                                    #Show the WMI class AFTER the properties get their values assigned
                                      Write-Output -InputObject (Get-WMIObject -NameSpace ($Namespace) -Class ($Class))
#endregion  
                              }
#endregion
                      }
                    Else
                      {
                          $WarningMessage = "The powershell variable `"OSDVariables`" contains no properties or values. No further action will be taken."
                          Write-Warning -Message "$($WarningMessage)" -Verbose
                      }
            }

        #Tasks defined here will execute whether a task sequence is running or not
          ###Place the code here

        #Tasks defined here will execute whether only if a task sequence is not running
          If ($IsRunningTaskSequence -eq $False)
            {
                $WarningMessage = "There is no task sequence running.`r`n"
                Write-Warning -Message "$($WarningMessage)" -Verbose
            }
            
        #Stop transcripting (Logging)
          Try
            {
                Stop-Transcript -Verbose
            }
          Catch
            {
                If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message)"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
                $ErrorMessage = "[Error Message: $($ExceptionMessage)][ScriptName: $($_.InvocationInfo.ScriptName)][Line Number: $($_.InvocationInfo.ScriptLineNumber)][Line Position: $($_.InvocationInfo.OffsetInLine)][Code: $($_.InvocationInfo.Line.Trim())]"
                Write-Error -Message "$($ErrorMessage)"
            }
    }
  Catch
    {
        If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message -Join "`r`n`r`n")"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
        $ErrorMessage = "[Error Message: $($ExceptionMessage)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]`r`n"
        If ($ContinueOnError.IsPresent -eq $False) {Throw "$($ErrorMessage)"}
    }