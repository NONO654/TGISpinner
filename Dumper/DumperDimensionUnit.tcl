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

   set sMxVersion [string range [mql version] 0 2]
   set sPath "$sSpinnerPath/SpinnerDimensionUnitData.xls"
   set lsDimension [split [mql list dimension] \n]
   set sFile "Dimension Name\tUnit Name\tUnit Label\tUnit Description\tMultiplier (real)\tOffset (real)\tSetting Names (use \"|\" delim)\tSetting Values (use \"|\" delim)\tSystemName (use \"|\" delim)\tSystemUnit (use \"|\" delim)\tDefault (boolean)\n"
   foreach sDimension $lsDimension {
      set bPass TRUE
      set sModDate [mql print dimension $sDimension select modified dump]
      set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
      if {$sModDateMin != "" && $sModDate < $sModDateMin} {
         set bPass FALSE
      } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
         set bPass FALSE
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print dimension $sDimension select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print dimension $sDimension select property\[SpinnerAgent\] dump] != "")} {
         set lsUnit [split [mql print dimension $sDimension select unit dump |] |]
         foreach sUnit $lsUnit {
            set sName $sUnit
            set sLabel [mql print dimension $sDimension select unit\[$sUnit\].label dump]
            set sDescription [mql print dimension $sDimension select unit\[$sUnit\].description dump]
            set sMultiplier [mql print dimension $sDimension select unit\[$sUnit\].multiplier dump]
            set sOffset [mql print dimension $sDimension select unit\[$sUnit\].offset dump]
            set slsSettingName [mql print dimension $sDimension select unit\[$sUnit\].setting dump " | "]
            set slsSettingValue [mql print dimension $sDimension select unit\[$sUnit\].setting.value dump " | "]
            set sDefault [mql print dimension $sDimension select unit\[$sUnit\].default dump]
            set lsSysName [list ]
            set lsSysUnit [list ]
            set lsPrint [split [mql print dimension "$sDimension"] \n]
            set bTrip "FALSE"
            foreach sPrint $lsPrint {
               set sPrint [string trim $sPrint]
               if {[string range $sPrint 0 3] == "unit" && [string first $sUnit $sPrint] > 3} {
                  set bTrip TRUE
               } elseif {$bTrip && [string range $sPrint 0 3] == "unit"} {
                  break
               } elseif {$bTrip} {
                  if {[string range $sPrint 0 5] == "system"} {
                     regsub "system" $sPrint "" sPrint
                     regsub " to unit " $sPrint "\|" sPrint
                     set lsSysNameUnit [split $sPrint "|"]
                     lappend lsSysName [string trim [lindex $lsSysNameUnit 0]]
                     lappend lsSysUnit [string trim [lindex $lsSysNameUnit 1]]
                  }
               }
            }
            set slsSysName [join $lsSysName " | "]
            set slsSysUnit [join $lsSysUnit " | "]
            append sFile "$sDimension\t$sName\t$sLabel\t$sDescription\t$sMultiplier\t$sOffset\t$slsSettingName\t$slsSettingValue\t$slsSysName\t$slsSysUnit\t$sDefault\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Dimension Unit data loaded in file $sPath"
}
