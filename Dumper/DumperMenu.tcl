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
   set sTypeReplace "menu "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "menu"} {
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

   set sPath "$sSpinnerPath/SpinnerMenuData.xls"
   set lsMenu [split [mql list menu $sFilter] \n]
   set sFile "Name\tRegistry Name\tDescription\tLabel\tHref\tAlt\tSetting Name (use '|' delim)\tSetting Value (use '|' delim)\tCommand/Menu Names (in order-use '|' delim)\t(not used)\tHidden (boolean)\tIcon File\n"
   foreach sMenu $lsMenu {
      set bPass TRUE
      set sModDate [mql print menu $sMenu select modified dump]
      set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
      if {$sModDateMin != "" && $sModDate < $sModDateMin} {
         set bPass FALSE
      } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
         set bPass FALSE
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print menu $sMenu select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print menu $sMenu select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print menu $sMenu select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sMenu)} sMsg
         regsub -all " " $sMenu "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sMenu
         }
         set sDescription [mql print menu $sMenu select description dump]
         set sLabel [mql print menu $sMenu select label dump]
         set sHref [mql print menu $sMenu select href dump]
         set sAlt [mql print menu $sMenu select alt dump]
         set sHidden [mql print menu $sMenu select hidden dump]
         set slsSettingName [mql print menu $sMenu select setting.name dump " | "]
         set slsSettingValue [mql print menu $sMenu select setting.value dump " | "]
         set lsPrint [split [mql print menu $sMenu] \n]
         set slsCmdMenu [mql print menu $sMenu select child dump " | "]
         append sFile "$sName\t$sOrigName\t$sDescription\t$sLabel\t$sHref\t$sAlt\t$slsSettingName\t$slsSettingValue\t$slsCmdMenu\t\t$sHidden\n"
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Menu data loaded in file $sPath"
}
