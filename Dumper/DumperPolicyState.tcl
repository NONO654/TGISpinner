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

   set sPath "$sSpinnerPath/SpinnerPolicyStateData.xls"
   set sMxVersion [string range [mql version] 0 2]
   set lsPolicy [split [mql list policy $sFilter] \n]
   set sFile "Policy Name\tState Name\tRevision (boolean)\tVersion (boolean)\tPromote (boolean)\tCheckout History (boolean)\tUsers for Access (use \"|\" delim)\tNotify Users (use \"|\" delim)\tNotify Message\tRoute User\tRoute Message\tSignatures (use \"|\" delim)\tIcon File\n"
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
         set lsState [split [mql print policy $sPolicy select state dump |] |]
         foreach sState $lsState {
            set sRevision [string tolower [mql print policy $sPolicy select state\[$sState\].revisionable dump]]
            set sVersion [string tolower [mql print policy $sPolicy select state\[$sState\].versionable dump]]
            set sPromote [string tolower [mql print policy $sPolicy select state\[$sState\].autopromote dump]]
            set sCheckout [string tolower [mql print policy $sPolicy select state\[$sState\].checkouthistory dump]]
            set sNotifyMsg [mql print policy $sPolicy select state\[$sState\].notify dump]
            set sRouteMsg [mql print policy $sPolicy select state\[$sState\].route dump]
            set slsSignature [mql print policy $sPolicy select state\[$sState\].signature dump " | "]
            
            set lsAccess ""
            set slsAccess ""
            set lsAccessTemp [split [mql print policy $sPolicy select state\[$sState\].access] \n]
            foreach sAccessTemp $lsAccessTemp {
               set sAccessTemp [string trim $sAccessTemp]
               if {[string first "\].access\[" $sAccessTemp] > -1} {
                  set iFirst [expr [string first "access\[" $sAccessTemp] + 7]
                  set iSecond [expr [string first "\] =" $sAccessTemp] -1]
                  lappend lsAccess [string range $sAccessTemp $iFirst $iSecond]
               }
            }
            set slsAccess [join $lsAccess " | "]
         
            set slsNotify ""
            set lsNotifyTemp [split [mql print policy $sPolicy] \n]
            set bTrip "FALSE"
            foreach sNotifyTemp $lsNotifyTemp {
               set sNotifyTemp [string trim $sNotifyTemp]
               if {$sNotifyTemp == "state $sState"} {
                  set bTrip TRUE
               } elseif {$bTrip == "TRUE" && [string range $sNotifyTemp 0 4] == "state"} {
                  break
               } elseif {$bTrip == "TRUE"} {
                  if {[string range $sNotifyTemp 0 5] == "notify"} {
                     regsub "notify " $sNotifyTemp "" sNotifyTemp
                     regsub -all "'" $sNotifyTemp "" sNotifyTemp
                     if {$sNotifyMsg != "" } {regsub " $sNotifyMsg" $sNotifyTemp "" sNotifyTemp}
                     set sNotifyTemp [string trim $sNotifyTemp]
                     regsub -all "," $sNotifyTemp " | " slsNotify
                     break
                  }
               } 
            }
            
            set sRoute ""
            set lsRouteTemp [split [mql print policy $sPolicy] \n]
            set bTrip "FALSE"
            foreach sRouteTemp $lsRouteTemp {
               set sRouteTemp [string trim $sRouteTemp]
               if {$sRouteTemp == "state $sState"} {
                  set bTrip TRUE
               } elseif {$bTrip == "TRUE" && [string range $sRouteTemp 0 4] == "state"} {
                  break
               } elseif {$bTrip == "TRUE"} {
                  if {[string range $sRouteTemp 0 4] == "route"} {
                     regsub "route " $sRouteTemp "" sRouteTemp
                     regsub -all "'" $sRouteTemp "" sRouteTemp
                     if {$sRouteMsg != ""} {regsub " $sRouteMsg" $sRouteTemp "" sRouteTemp}
                     set sRoute [string trim $sRouteTemp]
                     break
                  }
               }
            }
         append sFile "$sPolicy\t$sState\t$sRevision\t$sVersion\t$sPromote\t$sCheckout\t$slsAccess\t$slsNotify\t$sNotifyMsg\t$sRoute\t$sRouteMsg\t$slsSignature\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Policy State data loaded in file $sPath"
}
