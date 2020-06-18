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
   set sTypeReplace "policy "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "policy"} {
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

   set sPath "$sSpinnerPath/SpinnerPolicyData.xls"
   set lsPolicy [split [mql list policy $sFilter] \n]
   set sFile "Name\tRegistry Name\tDescription\tRev Sequence (use 'continue' for '...')\tStore\tHidden (boolean)\tTypes (use \"|\" delim)\tFormats (use \"|\" delim)\tDefault Format\tLocking (boolean)\tState Names (in order-use \"|\" delim)\tState Registry Names (in order-use \"|\" delim)\tAllstate (boolean)\tIcon File\n"
   set sMxVersion [join [lrange [split [mql version] .] 0 1] .]
   foreach sPolicy $lsPolicy {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print policy $sPolicy select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print policy $sPolicy select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print policy $sPolicy select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print policy $sPolicy select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sPolicy)} sMsg
         regsub -all " " $sPolicy "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sPolicy
         }
         set sRevSequence [mql print policy $sPolicy select revision dump]
         regsub -all "\\.\\.\\." $sRevSequence "continue" sRevSequence
         set bHidden [mql print policy $sPolicy select hidden dump]
         set bLocking [mql print policy $sPolicy select islockingenforced dump]
         
         set slsType [mql print policy $sPolicy select type dump " | "]
         set slsFormat [mql print policy $sPolicy select format dump " | "]
         set slsState [mql print policy $sPolicy select state dump " | "]
         
         set lsState [split [mql print policy $sPolicy select state dump |] |]
         foreach sState $lsState {
         	  array set aStateOrig [list $sState ""]
         } 
         set lsStateProp [split [mql print policy $sPolicy select property dump |] |]
         foreach sStateProp $lsStateProp {
            if {[string first "state_" $sStateProp] == 0} {
               regsub "state_" $sStateProp "" sStateProp
               regsub "value " $sStateProp "" sStateProp
               regsub " " $sStateProp "|" sStateProp
               set lsStateName [split $sStateProp |]
               set sStateOrig [lindex $lsStateName 0]
               set sStateName [lindex $lsStateName 1]
               array set aStateOrig [list $sStateName $sStateOrig]
            }
         }
   
         set lsState [split $slsState |]
         set slsStateOrig ""
         set bFirstFlag TRUE
         foreach sState $lsState {
            set sState [string trim $sState]
            set sStateOrig ""
            catch {set sStateOrig $aStateOrig($sState)} sMsg
            regsub -all " " $sState "" sStateTest
            if {$sStateTest == $sStateOrig} {
               set sStateOrig $sState
            }
            if {$bFirstFlag == "TRUE"} {
               set slsStateOrig $sStateOrig
               set bFirstFlag FALSE
            } else {
               append slsStateOrig " | $sStateOrig"
            }
         }
   
         set sStore [mql print policy $sPolicy select store dump]
         set sDefaultFormat [mql print policy $sPolicy select defaultformat dump]
         set sDescription [mql print policy $sPolicy select description dump]
         set bAllstate ""
         if {$sMxVersion >= 10.8} {set bAllstate [mql print policy $sPolicy select allstate dump]}
         
         append sFile "$sName\t$sOrigName\t$sDescription\t$sRevSequence\t$sStore\t$bHidden\t$slsType\t$slsFormat\t$sDefaultFormat\t$bLocking\t$slsState\t$slsStateOrig\t$bAllstate\n"
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Policy data loaded in file $sPath"
}
