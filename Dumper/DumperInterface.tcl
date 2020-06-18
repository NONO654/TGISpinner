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
   set sInterfaceReplace "interface "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "interface"} {
         set sPropertyTo [mql print program eServiceSchemaVariableMapping.tcl select property\[$sPropertyName\].to dump]
         regsub $sInterfaceReplace $sPropertyTo "" sPropertyTo
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

   set sPath "$sSpinnerPath/SpinnerInterfaceData.xls"
   set sMxVersion [join [lrange [split [mql version] .] 0 1] .]
   set lsInterface [split [mql list interface $sFilter] \n]
   if {$sMxVersion >= 10.8} { 
      set sFile "Name\tRegistry Name\tParents (use \"|\" delim)\tAbstract (boolean)\tDescription\tAttributes (use \"|\" delim)\tTypes (use \"|\" delim)\tHidden (boolean)\tRels (use \"|\" delim)\tIcon File\n"
   } else {
      set sFile "Name\tRegistry Name\tParents (use \"|\" delim)\tAbstract (boolean)\tDescription\tAttributes (use \"|\" delim)\tTypes (use \"|\" delim)\tHidden (boolean)\tIcon File\n"
   }
   
   foreach sInterface $lsInterface {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print interface $sInterface select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print interface $sInterface select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print interface $sInterface select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print interface $sInterface select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sInterface)} sMsg
         regsub -all " " $sInterface "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sInterface
         }
         set sDescription [mql print interface $sInterface select description dump]
         set sHidden [mql print interface $sInterface select hidden dump]
         set slsAttribute [mql print interface $sInterface select attribute dump " | "]
         set slsType [mql print interface $sInterface select type dump " | "]
         set slsDerived [mql print interface $sInterface select derived dump " | "]
         set bAbstract [mql print interface $sInterface select abstract dump]
         if {$sMxVersion >= 10.8} {
            set slsRel [mql print interface $sInterface select relationship dump " | "]
            append sFile "$sName\t$sOrigName\t$slsDerived\t$bAbstract\t$sDescription\t$slsAttribute\t$slsType\t$sHidden\t$slsRel\n"
         } else {
            append sFile "$sName\t$sOrigName\t$slsDerived\t$bAbstract\t$sDescription\t$slsAttribute\t$slsType\t\t$sHidden\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Interface data loaded in file $sPath"
}
