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
   }

   set sPath "$sSpinnerPath/SpinnerPolicyStateSignatureData.xls"
   set sFile "Policy Name\tState Name\tSignature Name\tUsers for Approve (use \"|\" delim)\tUsers for Reject (use \"|\" delim)\tUsers for Ignore (use \"|\" delim)\tBranch State\tFilter\n"
   set sMxVersion [string range [mql version] 0 2]
   set lsPolicy [split [mql list policy $sFilter] \n]
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
            set lsSignature [split [mql print policy $sPolicy select state\[$sState\].signature dump |] |]
            foreach sSignature $lsSignature {
               set slsApprove [mql print policy $sPolicy select state\[$sState\].signature\[$sSignature\].approve dump " | "]
               set slsReject [mql print policy $sPolicy select state\[$sState\].signature\[$sSignature\].reject dump " | "]
               set slsIgnore [mql print policy $sPolicy select state\[$sState\].signature\[$sSignature\].ignore dump " | "]
   
               set sBranch ""
               set sFilter ""
               set sCatchStringOne "state $sState"
               set sCatchStringTwo ""
               set bPass false
               set bTrip1 false
               set bTrip2 false
               
               set lsPrint [split [mql print policy $sPolicy] \n]
   
               foreach sPrint $lsPrint {
                  set sPrint [string trim $sPrint]
               
                  if {$sCatchStringTwo == ""} {
                     if {[string first $sCatchStringOne $sPrint] == 0} {
                        set sCatchStringTwo "state"
                     }
                  } elseif {[string first $sCatchStringTwo $sPrint] == 0} {
                     break
                  }
                  
                  if {$sCatchStringTwo != ""} {
               
                     if {[string first "signature $sSignature" $sPrint] == 0} {
                        set bPass true
                     } elseif {$bPass == "true"} {
               
                        if {[string first "branch" $sPrint] == 0} {
                           set bTrip1 "true"
                           regsub "branch " $sPrint "" sBranch
                           set sBranch [string trim $sBranch]
                        }
                        
                        if {[string first "filter" $sPrint] == 0} {
                           set bTrip2 "true"
                           regsub "filter " $sPrint "" sFilter
                           set sFilter [string trim $sFilter]
                        }
                        
                        if {$bTrip1 == "true" && $bTrip2 == "true"} {
                           break
                        }
                     }
                  }
               }
               append sFile "$sPolicy\t$sState\t$sSignature\t$slsApprove\t$slsReject\t$slsIgnore\t$sBranch\t$sFilter\n"
            }
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Policy State Signature data loaded in file $sPath"
}
