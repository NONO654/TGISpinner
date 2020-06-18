tcl;

eval {

#***********************************************************************
# User Defined Settings (globals from SpinnerDumper.tcl take precedence!)
#***********************************************************************

   set sFilter               "*";   #  default "*" - name filter
   set sOrigNameFilter       "";    #  default "" - original name property filter
   set bSpinnerAgentFilter   FALSE; #  default FALSE - filters schema modified by SpinnerAgent if TRUE
   set sGreaterThanEqualDate "";    #  default "" - date range min value formatted mm/dd/yyyy
   set sLessThanEqualDate    "";    #  default "" - date range max value formatted mm/dd/yyyy
#   set sGreaterThanEqualDate [clock format [clock seconds] -format "%m/%d/%Y"]; dynamic setting for current day
#   set sLessThanEqualDate    [clock format [clock seconds] -format "%m/%d/%Y"]; dynamic setting for current day
   
# End User Defined Settings
#*********************************************************************** 

#  Set up array for symbolic name mapping
#
   set lsPropertyName ""
   catch {set lsPropertyName [split [mql print program eServiceSchemaVariableMapping.tcl select property.name dump |] |]} sMsg
   set sTypeReplace "command "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "command"} {
         set sPropertyTo [mql print program eServiceSchemaVariableMapping.tcl select property\[$sPropertyName\].to dump]
         regsub $sTypeReplace $sPropertyTo "" sPropertyTo
         regsub "_" $sPropertyName "|" sSymbolicName
         set sSymbolicName [lindex [split $sSymbolicName |] 1]
         array set aSymbolic [list $sPropertyTo $sSymbolicName]
      }
   }

   if {[mql get env GLOBALFILTER] != ""} {
      set sFilter [mql get env GLOBALFILTER]
   } elseif {$sFilter == ""} {
      set sFilter "*"
   }
   
   if {[mql get env SPINNERFILTER] != ""} {
      set bSpinnerAgentFilter [mql get env SPINNERFILTER]
   }
   
   if {[mql get env ORIGNAMEFILTER] != ""} {
      set sOrigNameFilter [mql get env ORIGNAMEFILTER]
   }
   
   set sModDateMin [mql get env MODDATEMIN]
   set sModDateMax [mql get env MODDATEMAX]
   if {$sModDateMin == "" && $sModDateMax == ""} {
      if {$sGreaterThanEqualDate != ""} {
         set sModDateMin [clock scan $sGreaterThanEqualDate]
      }
      if {$sLessThanEqualDate != ""} {
         set sModDateMax [clock scan $sLessThanEqualDate]
      }
   }
   
   set sSpinnerPath [mql get env SPINNERPATH]
   if {$sSpinnerPath == ""} {
      set sOS [string tolower $tcl_platform(os)];
      set sSuffix [clock format [clock seconds] -format "%Y%m%d"]
      
      if { [string tolower [string range $sOS 0 5]] == "window" } {
         set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix/Business";
      } else {
         set sSpinnerPath "/tmp/SpinnerAgent$sSuffix/Business";
      }
      file mkdir $sSpinnerPath
   }

   set sPath "$sSpinnerPath/SpinnerCommandData.xls"
   set lsCommand [split [mql list command $sFilter] \n]
   set sFile "Name\tRegistry Name\tDescription\tLabel\tHref\tAlt\tSetting Name (use \"|\" delim)\tSetting Value (use \"|\" delim)\tUsers (use \"|\" delim)\tHidden (boolean)\tCode\tIcon File\n"
   foreach sCommand $lsCommand {
      set bPass TRUE
      set sModDate [mql print command $sCommand select modified dump]
      set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
      if {$sModDateMin != "" && $sModDate < $sModDateMin} {
         set bPass FALSE
      } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
         set bPass FALSE
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print command $sCommand select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print command $sCommand select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print command $sCommand select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sCommand)} sMsg
         regsub -all " " $sCommand "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sCommand
         }
         set sDescription [mql print command $sCommand select description dump]
         set sLabel [mql print command $sCommand select label dump]
         set sHref [mql print command $sCommand select href dump]
         set sAlt [mql print command $sCommand select alt dump]
         set sHidden [mql print command $sCommand select hidden dump]
         set sCode [mql print command $sCommand select code dump]
         set slsSettingName [mql print command $sCommand select setting.name dump " | "]
         set slsSettingValue [mql print command $sCommand select setting.value dump " | "]
         set slsUser [mql print command $sCommand select user dump " | "]
         append sFile "$sName\t$sOrigName\t$sDescription\t$sLabel\t$sHref\t$sAlt\t$slsSettingName\t$slsSettingValue\t$slsUser\t$sHidden\t$sCode\n"
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Command data loaded in file $sPath"
}
