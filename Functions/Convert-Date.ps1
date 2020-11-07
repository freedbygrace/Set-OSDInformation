## Microsoft Function Naming Convention: http://msdn.microsoft.com/en-us/library/ms714428(v=vs.85).aspx

#region Function Convert-Date
Function Convert-Date
    {
        <#
          .SYNOPSIS
          Attempts to convert one or more dates formatted as strings into actual [DateTime] objects
          
          .DESCRIPTION
          Storing dates as actual [DateTime] objects has major benefits such as native sorting (Newest to Oldest), and being able to get pieces of the date you may need for other operations.
          All data is returned as a native powershell object containing each converted date.
          
          .PARAMETER Date
          One or more dates in string format

          .PARAMETER InvariantCulture
          Limits the number of acceptable/parsable date/time formats to those that are not culture specific. When this parameter is NOT specified, the current culture of the operating system is used.
          Example: Get-Culture

          .PARAMETER LogDateTimeFormats
          Shows the acceptable/parsable date/time formats based on the culture format within the function logging.

          .PARAMETER ContinueOnError
          Allows the function to ignore any terminating errors.
          
          .EXAMPLE
          [String[]]$DatesToConvert = "03/22/2020", '23/43/22'
          Convert-Date -Date ($DatesToConvert) -LogDateTimeFormats -Verbose

          .EXAMPLE
          [String[]]$DatesToConvert = "03/22/2020", '23/43/22'
          Convert-Date -Date ($DatesToConvert) -LogDateTimeFormats -Verbose

          .EXAMPLE
          [String[]]$DatesToConvert = "03/22/2020", '23/43/22'
          Convert-Date -Date ($DatesToConvert) -InvariantCulture -LogDateTimeFormats -Verbose
  
          .NOTES
          Any useful tidbits
          
          .LINK
          https://www.powershellmagazine.com/2013/07/08/pstip-converting-a-string-to-a-system-datetime-object/
        #>
        
        [CmdletBinding(ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByInputObject', HelpURI = '', SupportsShouldProcess = $True, PositionalBinding = $True)]
       
        Param
          (        
              [Parameter(Mandatory=$True, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
              [ValidateNotNullOrEmpty()]
              [String[]]$Date,
                
              [Parameter(Mandatory=$False)]
              [Switch]$InvariantCulture,

              [Parameter(Mandatory=$False)]
              [Switch]$LogDateTimeFormats,
                              
              [Parameter(Mandatory=$False)]
              [Switch]$ContinueOnError        
          )
                    
        Begin
          {
              [ScriptBlock]$ErrorHandlingDefinition = {
                                                          If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message -Join "`r`n`r`n")"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
                                                          [String]$ErrorMessage = "[Error Message: $($ExceptionMessage)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]"

                                                          If ($ContinueOnError.IsPresent -eq $True)
                                                            {
                                                                Write-Warning -Message ($ErrorMessage)
                                                            }
                                                          ElseIf ($ContinueOnError.IsPresent -eq $False)
                                                            {
                                                                Throw ($ErrorMessage)
                                                            }
                                                      }
              
              Try
                {
                    $DateTimeLogFormat = 'dddd, MMMM dd, yyyy hh:mm:ss tt'  ###Monday, January 01, 2019 10:15:34 AM###
                    [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
                    $DateTimeFileFormat = 'yyyyMMdd_hhmmsstt'  ###20190403_115354AM###
                    [ScriptBlock]$GetDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
                    [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
                    $TextInfo = (Get-Culture).TextInfo
                    
                    #Determine the date and time we executed the function
                      $FunctionStartTime = (Get-Date)
                    
                    [String]$CmdletName = $MyInvocation.MyCommand.Name 
                    
                    $LogMessage = "Function `'$($CmdletName)`' is beginning. Please Wait..."
                    Write-Verbose -Message $LogMessage
              
                    #Define Default Action Preferences
                      $ErrorActionPreference = 'Stop'
                      
                    $LogMessage = "The following parameters and values were provided to the `'$($CmdletName)`' function." 
                    Write-Verbose -Message $LogMessage

                    $FunctionProperties = Get-Command -Name $CmdletName
                    
                    $FunctionParameters = $FunctionProperties.Parameters.Keys
              
                    ForEach ($Parameter In $FunctionParameters)
                      {
                          If (!([String]::IsNullOrEmpty($Parameter)))
                            {
                                $ParameterProperties = Get-Variable -Name $Parameter -ErrorAction SilentlyContinue
                                $ParameterValueCount = $ParameterProperties.Value | Measure-Object | Select-Object -ExpandProperty Count
                          
                                If ($ParameterValueCount -gt 1)
                                  {
                                      $ParameterValueStringFormat = ($ParameterProperties.Value | ForEach-Object {"`"$($_)`""}) -Join "`r`n"
                                      $LogMessage = "$($ParameterProperties.Name):`r`n`r`n$($ParameterValueStringFormat)"
                                  }
                                Else
                                  {
                                      $ParameterValueStringFormat = ($ParameterProperties.Value | ForEach-Object {"`"$($_)`""}) -Join ', '
                                      $LogMessage = "$($ParameterProperties.Name): $($ParameterValueStringFormat)"
                                  }
                           
                                If (!([String]::IsNullOrEmpty($ParameterProperties.Name)))
                                  {
                                      Write-Verbose -Message $LogMessage
                                  }
                            }
                      }

                    $LogMessage = "Execution of $($CmdletName) began on $($FunctionStartTime.ToString($DateTimeLogFormat))"
                    Write-Verbose -Message $LogMessage
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
          }

        Process
          {                         
              Try
                {  
                    If ($InvariantCulture.IsPresent -eq $True)
                      {
                          $CultureInfo = [System.Globalization.CultureInfo]::InvariantCulture
                          [String[]]$DateTimeFormats = [System.Globalization.DateTimeFormatInfo]::InvariantInfo.GetAllDateTimePatterns()
                      }
                    ElseIf ($InvariantCulture.IsPresent -eq $False)
                      {
                          $CultureInfo = [System.Globalization.CultureInfo]::CurrentCulture
                          [String[]]$DateTimeFormats = [System.Globalization.DateTimeFormatInfo]::CurrentInfo.GetAllDateTimePatterns()
                      }

                    If ($LogDateTimeFormats.IsPresent -eq $True)
                      {
                          $LogMessage = "See the valid date time formats for culture `"$($CultureInfo.DisplayName)`" below.`r`n`r`n$($DateTimeFormats -Join "`r`n")`r`n" 
                          Write-Verbose -Message $LogMessage -Verbose
                      }
                                                                                
                    #Create an object to store all processed dates that will be returned to the pipeline
                      [PSObject]$OutputObject = @()
                    
                    ForEach ($Item In $Date)
                      {
                          Try
                            {
                                $LogMessage = "Attempting to convert date `"$($Item)`". Please Wait..." 
                                Write-Verbose -Message $LogMessage

                                $ConvertedDateTime = New-Object -TypeName 'DateTime'

                                $ConvertDateTime = [DateTime]::TryParseExact(
                                                                                ($Item),
                                                                                ($DateTimeFormats),
                                                                                ($CultureInfo),
                                                                                ([System.Globalization.DateTimeStyles]::None),
                                                                                ([Ref]$ConvertedDateTime)
                                                                            )
                           
                                $ItemObject = New-Object -TypeName 'PSObject'
                                
                                $ItemObject | Add-Member -Name "OriginalDateTime" -Value ($Item) -MemberType NoteProperty
                                
                                If ($ConvertDateTime -eq $True)
                                  {   
                                      $LogMessage = "`"$($Item)`" was successfully converted to `"$($ConvertedDateTime.ToString($DateTimeLogFormat))`"." 
                                      Write-Verbose -Message $LogMessage

                                      $ItemObject | Add-Member -Name "ConvertedDateTime" -Value ($ConvertedDateTime) -MemberType NoteProperty    
                                  }
                                ElseIf ($ConvertDateTime -eq $False)
                                  {
                                      $WarningMessage = "The value `"$($Item)`" is an invalid date/time format and could not be converted." 
                                      Write-Warning -Message $WarningMessage

                                      $ItemObject | Add-Member -Name "ConvertedDateTime" -Value ($Null) -MemberType NoteProperty
                                  }

                                $ItemObject | Add-Member -Name "IsConvertable" -Value ([Boolean]::Parse($ConvertDateTime.ToString())) -MemberType NoteProperty

                                $OutputObject += ($ItemObject)
                            }
                          Catch
                            {
                                $ErrorHandlingDefinition.Invoke()
                            }
                      }

                    #Return the compiled object to the pipeline
                      Write-Output -InputObject ($OutputObject)
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
          }
        
        End
          {                                        
              Try
                {
                    #Determine the date and time the function completed execution
                      $FunctionEndTime = (Get-Date)

                      $LogMessage = "Execution of $($CmdletName) ended on $($FunctionEndTime.ToString($DateTimeLogFormat))"
                      Write-Verbose -Message $LogMessage

                    #Log the total script execution time  
                      $FunctionExecutionTimespan = New-TimeSpan -Start ($FunctionStartTime) -End ($FunctionEndTime)

                      $LogMessage = "Function execution took $($FunctionExecutionTimespan.Hours.ToString()) hour(s), $($FunctionExecutionTimespan.Minutes.ToString()) minute(s), $($FunctionExecutionTimespan.Seconds.ToString()) second(s), and $($FunctionExecutionTimespan.Milliseconds.ToString()) millisecond(s)"
                      Write-Verbose -Message $LogMessage
                    
                    $LogMessage = "Function `'$($CmdletName)`' is completed."
                    Write-Verbose -Message $LogMessage
                }
              Catch
                {
                    $ErrorHandlingDefinition.Invoke()
                }
          }
    }
#endregion