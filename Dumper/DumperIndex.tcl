tcl;

eval {
   if {[info host] == "mostermant43" } {
      source "c:/Program Files/TclPro1.3/win32-ix86/bin/prodebug.tcl"
      set cmd "debugger_eval"
      set xxx [debugger_init]
   } else {
      set cmd "eval"
   }
}
$cmd {

#***********************************************************************
# User Defined Settings (globals from SpinnerDumper.tcl take precedence!)
#***********************************************************************

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
   set sTypeReplace "index "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "index"} {
         set sPropertyTo [mql print program eServiceSchemaVariableMapping.tcl select property\[$sPropertyName\].to dump]
         regsub $sTypeReplace $sPropertyTo "" sPropertyTo
         regsub "_" $sPropertyName "|" sSymbolicName
         set sSymbolicName [lindex [split $sSymbolicName |] 1]
         array set aSymbolic [list $sPropertyTo $sSymbolicName]
      }
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
         set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix/System";
      } else {
         set sSpinnerPath "/tmp/SpinnerAgent$sSuffix/System";
      }
      file mkdir $sSpinnerPath
   }

   set sPath "$sSpinnerPath/index.xls"
   set sFile "name\tRegistry Name\tdescription\tattribute\tenable\tunique\thidden\ticon\n"
   set sMxVersion [string range [mql version] 0 2]

   set lsIndex [split [mql list index] \n]
   foreach sIndex $lsIndex {
      if {[catch {set sName [mql print index $sIndex select name dump]} sMsg] != 0} {
         puts "ERROR: Problem with retrieving info on index '$sIndex' - Error Msg:\n$sMsg"
         continue
      }
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print index $sIndex select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print index $sIndex select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print index $sIndex select property\[SpinnerAgent\] dump] != "")} {
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sIndex)} sMsg
         regsub -all " " $sIndex "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sIndex
         }
                  
         set sDescription [mql print index $sIndex select description dump]
         set slsAttribute [mql print index $sIndex select attribute dump " | "]
         set sEnable [mql print index $sIndex select enabled dump]
         set sUnique [mql print index $sIndex select unique dump]
         set sHidden [mql print index $sIndex select hidden dump]
      }
      append sFile "$sName\t$sOrigName\t$sDescription\t$slsAttribute\t$sEnable\t$sUnique\t$sHidden\n"
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Index data loaded in file $sPath"
}
