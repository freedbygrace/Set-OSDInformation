#Requires -Version 3

<#
    .SYNOPSIS
    Records the requested deployment information into the registry and/or WMI during operating system deployment (OSD).
          
    .DESCRIPTION
    This script will add build, task sequence, and other information to the operating system so that it can later be examined or inventoried. That data can then be used as the driving force behind SCCM collections, and or SCCM reports.
    Information can be added to the registry, WMI, or both.
          
    .PARAMETER Registry
    Records the requested deployment information into the registry for later examination, collection into hardware inventory, or referencing the data within other scripts.

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
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Set-OSDInformation.ps1" -WMI -Namespace "Root\CIMv2\OSD" -Class "OSDInfo" -OSDVariablePrefix "XOSDInfo_" -LogDir "%_SMSTSLogPath%\Set-OSDInformation"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Set-OSDInformation.ps1" -Registry -RegistryKeyPath "HKLM:\Software\Microsoft\Deployment\OSDInfo" -OSDVariablePrefix "CustomOSDInfo_" -LogDir "%_SMSTSLogPath%\Set-OSDInformation"
  
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
            [String]$RegistryKeyPath = "HKLM:\Software\Microsoft\Deployment\OSDInfo",

            [Parameter(Mandatory=$False)]
            [Switch]$WMI,
                        
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^Root\\.*')})]
            [Alias('NS')]
            [String]$Namespace = "Root\CIMv2\OSD",

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [String]$Class = "OSDInfo",
            
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [String]$ClassDescription = "Contains operating system deployment details that can be inventoried and used for reporting and/or collection criteria purposes.",

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^.*_$')})]
            [Alias('OSDVP')]
            [String]$OSDVariablePrefix = "XOSDInfo_",
            
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
            [ValidateScript({($_ -imatch '^[a-zA-Z][\:]\\.*?[^\\]$') -or ($_ -imatch "^\\(?:\\[^<>:`"/\\|?*]+)+$")})]
            [Alias('LogPath')]
            [System.IO.DirectoryInfo]$LogDir,
            
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

#Determine the default logging path if the parameter is not specified and is not assigned a default value
  If (($PSBoundParameters.ContainsKey('LogDir') -eq $False) -and ($LogDir -ieq $Null))
    {
        If ($IsRunningTaskSequence -eq $True)
          {
              [String]$_SMSTSLogPath = "$($TSEnvironment.Value('_SMSTSLogPath'))"
                    
              If ([String]::IsNullOrEmpty($_SMSTSLogPath) -eq $False)
                {
                    [System.IO.DirectoryInfo]$TSLogDirectory = "$($_SMSTSLogPath)"
                }
              Else
                {
                    [System.IO.DirectoryInfo]$TSLogDirectory = "$($Env:Windir)\Temp\SMSTSLog"
                }
                     
              [System.IO.DirectoryInfo]$LogDir = "$($TSLogDirectory.FullName)\$($ScriptPath.BaseName)"
          }
        ElseIf ($IsRunningTaskSequence -eq $False)
          {
              [System.IO.DirectoryInfo]$LogDir = "$($Env:Windir)\Logs\Software\$($ScriptPath.BaseName)"
          }
    }

#Start transcripting (Logging)
  Try
    {
        [System.IO.FileInfo]$ScriptLogPath = "$($LogDir.FullName)\$($ScriptPath.BaseName)_$($GetCurrentDateTimeFileFormat.Invoke()).log"
        If ($ScriptLogPath.Directory.Exists -eq $False) {[Void][System.IO.Directory]::CreateDirectory($ScriptLogPath.Directory.FullName)}
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
                  #Gather any additional details about the system
                    If ($IsWindowsPE -eq $False)
                      {
                          $OperatingSystemDetails = Get-Item -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"
                          [String]$OperatingSystemReleaseID = $OperatingSystemDetails.GetValue('ReleaseID')
                          [String]$OperatingSystemUBR = $OperatingSystemDetails.GetValue('UBR')
                          
                          If ([String]::IsNullOrEmpty($OperatingSystemUBR) -eq $False)
                            {
                                $OperatingSystemImageVersion = "$($OperatingSystem.Version).$($OperatingSystemUBR)"
                            }
                          Else
                            {
                                $OperatingSystemImageVersion = "$($OperatingSystem.Version)"
                            }
                      }
                  
                  #Determine the specified time zone properties
                    $OriginalTimeZone = Get-TimeZone
                    $DestinationTimeZone = Get-TimeZone -ID "$($DestinationTimeZoneID)"
                    $FinalConversionTimeZone = Get-TimeZone -ID "$($FinalConversionTimeZoneID)"
                  
                  #Load any required assemblies
                    [Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
            
                  #Create an empty array to store the combined/final set of OSD variable(s)
                    [System.Collections.ArrayList]$OSDVariables = @()
                  
                  #Create an empty array to store the default OSD variable(s)
                    [System.Collections.ArrayList]$DefaultOSDVariables = @()
                  
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
                                                                  "_SMSTSBootUEFI",
                                                                  "_SMSTSAdvertID",
                                                                  "_SMSTSMP",
                                                                  "_SMSTSType",
                                                                  "SMSTSPeerDownload",
                                                                  "SMSTSPersistContent",
                                                                  "SMSTSPreserveContent"
                                                                  "IPAddress001",
                                                                  "IPAddress002",
                                                                  "MACAddress001",
                                                                  "DefaultGateway001"
                                                               )

                          #Retrieve the image package ID so that we can know which image was deployed with the task sequence
                            $LogMessage = "Attempting to retrieve the `"ImagePackageID`" from the `"_SMSTSTaskSequence`" task sequence variable. Please Wait..."
                            Write-Verbose -Message "$($LogMessage)" -Verbose

                            $_SMSTSTaskSequence = $TSEnvironment.Value('_SMSTSTaskSequence')

                            Try {$TaskSequenceXMLDefinition_GetImagePackageID = @(Select-Xml -Content ($_SMSTSTaskSequence) -XPath "//variable[@name='ImagePackageID']")} Catch {$TaskSequenceXMLDefinition_GetImagePackageID = $Null}

                            If ($TaskSequenceXMLDefinition_GetImagePackageID -ine $Null)
                              {
                                  [String]$TaskSequenceXMLDefinition_ImagePackageID = $TaskSequenceXMLDefinition_GetImagePackageID[0].Node.InnerText
                              }
                            ElseIf ($TaskSequenceXMLDefinition_GetImagePackageID -ieq $Null)
                              {
                                  [String]$TaskSequenceXMLDefinition_ImagePackageID = $Null
                              }
                            
                            $DefaultOSDVariables += (Set-Variable -Name "ImagePackageID" -Value ($TaskSequenceXMLDefinition_ImagePackageID) -PassThru -Force -Verbose)

                          #Retrieve the last content download location and remove all other text except the server name
                            $LogMessage = "Attempting to retrieve the value of the `"_SMSTSLastContentDownloadLocation`" task sequence variable. Please Wait..."
                            Write-Verbose -Message "$($LogMessage)" -Verbose

                            $_SMSTSLastContentDownloadLocation = $TSEnvironment.Value('_SMSTSLastContentDownloadLocation')

                            Try {[String]$_SMSTSLastContentDownloadLocation_Formatted = ($_SMSTSLastContentDownloadLocation -isplit "(https?\:\/\/.+[\:]\d{1,5})")[1].Trim()} Catch {[String]$_SMSTSLastContentDownloadLocation_Formatted = $Null}

                            $DefaultOSDVariables += (Set-Variable -Name "SMSTSLastContentDownloadLocation" -Value ($_SMSTSLastContentDownloadLocation_Formatted) -PassThru -Force -Verbose)
                      }
                    ElseIf ($IsConfigurationManagerTaskSequence -eq $False)
                      {
                          [String]$DeploymentProduct = "MDT"
                          
                          [String[]]$Base64Variables = "UserDomain", "UserID"

                          ForEach ($Base64Variable In $Base64Variables)
                            {
                                $Base64VariableValue = $TSEnvironment.Value($Base64Variable)

                                If ([String]::IsNullOrEmpty($Base64VariableValue) -eq $False)
                                  {
                                      $DecodedBase64VariableValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64VariableValue))
                                      $DecodedBase64VariableValue = $DecodedBase64VariableValue.ToUpper()
                                  }
                                Else
                                  {
                                      $DecodedBase64VariableValue = $Null
                                  }

                                $DefaultOSDVariables += (Set-Variable -Name "$($Base64Variable)" -Value ($DecodedBase64VariableValue) -PassThru -Force -Verbose)
                            }
                                                    
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
                                                                  "WDSServer",
                                                                  "TaskSequenceID",
                                                                  "TaskSequenceName",
                                                                  "IPAddress001",
                                                                  "IPAddress002",
                                                                  "MACAddress001"
                                                               )
                      }
                                                                                              
                    #Always define a variables that could only be retrieved via script
                      $DefaultOSDVariables += (Set-Variable -Name "DeploymentProduct" -Value ($DeploymentProduct) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "OSImageVersion" -Value ($OperatingSystemImageVersion) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "OSImageReleaseID" -Value ($OperatingSystemReleaseID) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "ComputerName" -Value ($ComputerSystem.Name) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "Manufacturer" -Value ($ComputerSystem.Manufacturer) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "Model" -Value ($ComputerSystem.Model) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "SystemID" -Value ($Baseboard.Product) -PassThru -Force -Verbose)
                      $DefaultOSDVariables += (Set-Variable -Name "SerialNumber" -Value ($Bios.SerialNumber) -PassThru -Force -Verbose)
            
                    #Sort the default OSD variable list alphabetically and only return the unique value(s)
                      $DefaultOSDVariableListSorted = $DefaultOSDVariableList | Sort-Object -Unique
                      
                    #Create a variable for each default variable specified
                      ForEach ($DefaultOSDVariable In $DefaultOSDVariableListSorted)
                        {
                            #Remove all instances of invalid character(s) from the variable name(s) using a regular expression. This is to avoid potential WMI property creation error(s).
                              $DefaultOSDVariableName = $DefaultOSDVariable -ireplace "(_)|(\s)|(\.)", ""
                              
                            #Retrieve the value of the task sequence variable
                              $DefaultOSDVariableValue = $TSEnvironment.Value($DefaultOSDVariable)

                            $LogMessage = "Now processing task sequence variable `"$($DefaultOSDVariable)`" with a value of `"$($DefaultOSDVariableValue)`". Please Wait..."
                            Write-Verbose -Message "$($LogMessage)" -Verbose
                            
                            #Attempt to format any Default variable(s) to their respective data types. This is for data consistency purposes.
                              [Boolean]$DefaultOSDVariableDataTypeFound = $False

                              If ((([DateTime]::TryParse(($DefaultOSDVariableValue), [Ref](New-Object -TypeName 'DateTime')) -eq $True)) -and ($DefaultOSDVariableDataTypeFound -eq $False))
                                {
                                    $LogMessage = "Attempting to cast the task sequence variable `"$($DefaultOSDVariable)`" to a [DateTime] type. Please Wait..."
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                    $ConvertDefaultOSDVariableValueToDateTime = Convert-Date -Date "$($DefaultOSDVariableValue)" -Verbose

                                    If ($ConvertDefaultOSDVariableValueToDateTime.IsConvertable -eq $True)
                                      {
                                          $ConvertedDefaultOSDVariableDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($ConvertDefaultOSDVariableValueToDateTime.ConvertedDateTime), "$($DestinationTimeZone.ID)")
                                          $ConvertedDefaultOSDVariableDateTimeFinal = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($ConvertedDefaultOSDVariableDateTime), "$($FinalConversionTimeZone.ID)")
                                          $DefaultOSDVariableValueConverted = $ConvertedDefaultOSDVariableDateTimeFinal
                                        
                                          [Boolean]$DefaultOSDVariableDataTypeFound = $True
                                      }
                                }
                                  
                              If (($DefaultOSDVariableValue -imatch "^True$|^False$") -and ($DefaultOSDVariableDataTypeFound -eq $False))
                                {
                                    $LogMessage = "Attempting to cast the task sequence variable `"$($DefaultOSDVariable)`" to a [Boolean] type. Please Wait..."
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                    $DefaultOSDVariableValueConverted = [Boolean]::Parse($DefaultOSDVariableValue)

                                    [Boolean]$DefaultOSDVariableDataTypeFound = $True
                                }

                              If (($DefaultOSDVariableValue -imatch "^Yes$") -and ($DefaultOSDVariableDataTypeFound -eq $False))
                                {
                                    $LogMessage = "Attempting to cast the task sequence variable `"$($DefaultOSDVariable)`" to a [Boolean] type. Please Wait..."
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                    $DefaultOSDVariableValueConverted = [Boolean]::Parse("True")

                                    [Boolean]$DefaultOSDVariableDataTypeFound = $True
                                }

                              If (($DefaultOSDVariableValue -imatch "^No$") -and ($DefaultOSDVariableDataTypeFound -eq $False))
                                {
                                    $LogMessage = "Attempting to cast the task sequence variable `"$($DefaultOSDVariable)`" to a [Boolean] type. Please Wait..."
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                    $DefaultOSDVariableValueConverted = [Boolean]::Parse("False")

                                    [Boolean]$DefaultOSDVariableDataTypeFound = $True
                                }

                              If (([Microsoft.VisualBasic.Information]::IsNumeric($DefaultOSDVariableValue) -eq $True) -and ($DefaultOSDVariableDataTypeFound -eq $False))
                                {
                                    $LogMessage = "Attempting to cast the task sequence variable `"$($DefaultOSDVariable)`" to a [Double] type. Please Wait..."
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                    $DefaultOSDVariableValueConverted = [Double]::Parse($DefaultOSDVariableValue)

                                    [Boolean]$DefaultOSDVariableDataTypeFound = $True
                                }

                              If (($DefaultOSDVariableDataTypeFound -eq $False))
                                {
                                    $LogMessage = "Attempting to cast the task sequence variable `"$($DefaultOSDVariable)`" to a [String] type. Please Wait..."
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                    If ([String]::IsNullOrEmpty($DefaultOSDVariableValue) -eq $False) {$DefaultOSDVariableValueConverted = [String]::New($DefaultOSDVariableValue)} Else {$DefaultOSDVariableValueConverted = $Null}

                                    [Boolean]$DefaultOSDVariableDataTypeFound = $True
                                }

                              #Add the variable to the array if it was converted sucessfully, otherwise write a log entry for troubleshooting.
                                If (($DefaultOSDVariableDataTypeFound -eq $True))
                                  {
                                      $DefaultOSDVariables += (Set-Variable -Name "$($DefaultOSDVariableName)" -Value ($DefaultOSDVariableValueConverted) -PassThru -Force -Verbose)
                                  }
                                ElseIf (($DefaultOSDVariableDataTypeFound -eq $False))
                                  {
                                      $WarningMessage = "Task sequence variable `"$($DefaultOSDVariable)`" with a value of `"$($DefaultOSDVariableValue)`" could not be converted. Skipping...`r`n`r`n[Error Message: $($_.Exception.Message)]"
                                      Write-Warning -Message "$($WarningMessage)"
                                  }
                        }
                    	                	
                  #Add the default OSD variables to the final variable array
                    $OSDVariables += ($DefaultOSDVariables)
                  
                  #Create an empty array to store the custom set of OSD variable(s)
                    [System.Collections.ArrayList]$CustomOSDVariables = @()
            
                  #Dynamically retrieve the additional task sequence variable(s) based on their prefix and add them to the information that will be written to either WMI, the registry, or both
                    $RetrievedCustomOSDVariables = $TSEnvironment.GetVariables() | Where-Object {($_ -imatch "^$($OSDVariablePrefix).*")}
  
                  #Sort the custom OSD variable list alphabetically and only return the unique value(s)
                    $CustomOSDVariableListSorted = $RetrievedCustomOSDVariables | Sort-Object -Unique
            
                  #Create all the variable(s) that will be written to the system in the desired storage location
                    ForEach ($CustomOSDVariable In $CustomOSDVariableListSorted)
                      {
                          #Remove the attribute prefix from the variable name(s). This is for cleaner output purposes.
                            $CustomOSDVariableName = $CustomOSDVariable -ireplace "$($OSDVariablePrefix)", ""
                            
                          #Remove all instances of invalid character(s) from the variable name(s) using a regular expression. This is to avoid potential WMI property creation error(s).
                            $CustomOSDVariableName = $CustomOSDVariableName -ireplace "(_)|(\s)|(\.)", ""
                            
                          #Retrieve the value of the task sequence variable
                            $CustomOSDVariableValue = $TSEnvironment.Value($CustomOSDVariable)

                          $LogMessage = "Now processing task sequence variable `"$($CustomOSDVariable)`" with a value of `"$($CustomOSDVariableValue)`". Please Wait..."
                          Write-Verbose -Message "$($LogMessage)" -Verbose
                            
                          #Attempt to format any custom variable(s) to their respective data types. This is for data consistency purposes.
                            [Boolean]$CustomOSDVariableDataTypeFound = $False

                            If ((([DateTime]::TryParse(($CustomOSDVariableValue), [Ref](New-Object -TypeName 'DateTime')) -eq $True)) -and ($CustomOSDVariableDataTypeFound -eq $False))
                              {
                                  $LogMessage = "Attempting to cast the task sequence variable `"$($CustomOSDVariable)`" to a [DateTime] type. Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)" -Verbose
                                          
                                  $ConvertCustomOSDVariableValueToDateTime = Convert-Date -Date "$($CustomOSDVariableValue)" -Verbose

                                  If ($ConvertCustomOSDVariableValueToDateTime.IsConvertable -eq $True)
                                    {
                                        $ConvertedCustomOSDVariableDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($ConvertCustomOSDVariableValueToDateTime.ConvertedDateTime), "$($DestinationTimeZone.ID)")
                                        $ConvertedCustomOSDVariableDateTimeFinal = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(($ConvertedCustomOSDVariableDateTime), "$($FinalConversionTimeZone.ID)")
                                        $CustomOSDVariableValueConverted = $ConvertedCustomOSDVariableDateTimeFinal
                                        
                                        [Boolean]$CustomOSDVariableDataTypeFound = $True
                                    }
                              }
                                  
                            If (($CustomOSDVariableValue -imatch "^True$|^False$") -and ($CustomOSDVariableDataTypeFound -eq $False))
                              {
                                  $LogMessage = "Attempting to cast the task sequence variable `"$($CustomOSDVariable)`" to a [Boolean] type. Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                  $CustomOSDVariableValueConverted = [Boolean]::Parse($CustomOSDVariableValue)

                                  [Boolean]$CustomOSDVariableDataTypeFound = $True
                              }

                            If (($CustomOSDVariableValue -imatch "^Yes$") -and ($CustomOSDVariableDataTypeFound -eq $False))
                              {
                                  $LogMessage = "Attempting to cast the task sequence variable `"$($CustomOSDVariable)`" to a [Boolean] type. Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                  $CustomOSDVariableValueConverted = [Boolean]::Parse("True")

                                  [Boolean]$CustomOSDVariableDataTypeFound = $True
                              }

                            If (($CustomOSDVariableValue -imatch "^No$") -and ($CustomOSDVariableDataTypeFound -eq $False))
                              {
                                  $LogMessage = "Attempting to cast the task sequence variable `"$($CustomOSDVariable)`" to a [Boolean] type. Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                  $CustomOSDVariableValueConverted = [Boolean]::Parse("False")

                                  [Boolean]$CustomOSDVariableDataTypeFound = $True
                              }

                            If (([Microsoft.VisualBasic.Information]::IsNumeric($CustomOSDVariableValue) -eq $True) -and ($CustomOSDVariableDataTypeFound -eq $False))
                              {
                                  $LogMessage = "Attempting to cast the task sequence variable `"$($CustomOSDVariable)`" to a [Double] type. Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                  $CustomOSDVariableValueConverted = [Double]::Parse($CustomOSDVariableValue)

                                  [Boolean]$CustomOSDVariableDataTypeFound = $True
                              }

                            If (($CustomOSDVariableDataTypeFound -eq $False))
                              {
                                  $LogMessage = "Attempting to cast the task sequence variable `"$($CustomOSDVariable)`" to a [String] type. Please Wait..."
                                  Write-Verbose -Message "$($LogMessage)" -Verbose
                                        
                                  If ([String]::IsNullOrEmpty($CustomOSDVariableValue) -eq $False) {$CustomOSDVariableValueConverted = [String]::New($CustomOSDVariableValue)} Else {$CustomOSDVariableValueConverted = $Null}

                                  [Boolean]$CustomOSDVariableDataTypeFound = $True
                              }

                            #Add the variable to the array if it was converted sucessfully, otherwise write a log entry for troubleshooting.
                              If (($CustomOSDVariableDataTypeFound -eq $True))
                                {
                                    $CustomOSDVariables += (Set-Variable -Name "$($CustomOSDVariableName)" -Value ($CustomOSDVariableValueConverted) -PassThru -Force -Verbose)
                                }
                              ElseIf (($CustomOSDVariableDataTypeFound -eq $False))
                                {
                                    $WarningMessage = "Task sequence variable `"$($CustomOSDVariable)`" with a value of `"$($CustomOSDVariableValue)`" could not be converted. Skipping..."
                                    Write-Warning -Message "$($WarningMessage)"

                                    Continue
                                }
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
	String InstanceKey;


"@

                                  [Void]$MOFContents.Append($WMIClassDefinitionHeader)
                                    
                                    #Add properties to the newly created WMI Class, set their individual data types, and set their individual values
                                      ForEach ($OSDVariable In $OSDVariables)
                                        {
                                            [String]$OSDVariableName = $OSDVariable.Name
                                                                                                                              
                                            #Attempt to specify data type before adding the property to the WMI class
                                            #Valid values are the following: None, SInt16, SInt32, Real32, Real64, String, Boolean, Object, SInt8, UInt8, UInt16, UInt32, SInt64, UInt64, DateTime, Reference, Char16 (Example: [System.Management.CimType]::GetNames([System.Management.CimType]))
                                              $PropertyTypeFound = $False
                                              
                                              If (($OSDVariable.Value -is [DateTime]) -and ($PropertyTypeFound -eq $False))
                                                {
                                                    $PropertyType = "DateTime"
                                                    $PropertyTypeFound = $True
                                                }
                                              
                                              If (($OSDVariable.Value -is [Boolean]) -and ($PropertyTypeFound -eq $False))
                                                {
                                                    $PropertyType = "Boolean"
                                                    $PropertyTypeFound = $True
                                                }
                                              
                                              If (($OSDVariable.Value -is [Double]) -and ($PropertyTypeFound -eq $False))
                                                {
                                                    $PropertyType = "Real64"
                                                    $PropertyTypeFound = $True
                                                }
                                                                                            
                                              If (($OSDVariable.Value -is [String]) -and ($PropertyTypeFound -eq $False))
                                                {
                                                    $PropertyType = "String"
                                                    $PropertyTypeFound = $True
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

                                      $LogMessage = "Attempting to set the property value(s) for the WMI class `"$($Class)`" located in the `"$($Namespace)`" namespace. Please Wait..."
                                      Write-Verbose -Message "$($LogMessage)" -Verbose  
                                    
                                      ForEach ($CIMInstanceProperty In $CIMInstanceProperties)
                                        {
                                            $CIMInstancePropertyName = $CIMInstanceProperty.Name
                                            
                                            $OSDVariableProperties = $OSDVariables | Where-Object {($_.Name -ieq $CIMInstancePropertyName)}
                                            
                                            $LogMessage = "Attempting to set the WMI property value for `"$($CIMInstancePropertyName)`" to `"$($OSDVariableProperties.Value)`". Please Wait..."
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
        Write-Error -Message "$($ErrorMessage)"
        
        Stop-Transcript -Verbose
        
        If ($ContinueOnError.IsPresent -eq $False)
          {
              [System.Environment]::Exit(50)
          }
    }