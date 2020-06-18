tcl;

eval {
   set sHost [info host]
   if { $sHost == "MOSTERMAN2K" } {
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

   set sPath "$sSpinnerPath/SpinnerTriggerData.xls"
   set sFile "Schema Type\tSchema Name\tState (for Policy)\tTrigger Event\tTrigger Type (check / override / action)\tProgram\tInput\n"
   set sMxVersion [string range [mql version] 0 2]
   
   set lsType [list attribute type relationship policy]

   foreach sType $lsType {
      set lsName [split [mql list $sType $sFilter] \n ]

      foreach sName $lsName {
         set bPass TRUE
         if {$sMxVersion > 8.9} {
            set sModDate [mql print $sType $sName select modified dump]
            set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
            if {$sModDateMin != "" && $sModDate < $sModDateMin} {
               set bPass FALSE
            } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
               set bPass FALSE
            }
         }
         
         if {$sOrigNameFilter != ""} {
            set sOrigName [mql print $sType $sName select property\[original name\].value dump]
            if {[string match $sOrigNameFilter $sOrigName] == 1} {
               set bPass TRUE
            } else {
               set bPass FALSE
            }
         }
   
         if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print $sType $sName select property\[SpinnerAgent\] dump] != "")} {
   
            if {$sType == "policy"} {
               set lsState [split [mql print policy $sName select state dump |] |]
               set lsState [lsort -decreasing $lsState]
               set lsCatchTest [list action check trigger]
            } else {
               set lsCatchTest trigger
            }
      
            set sStateName ""
            set sProgram ""
            set sInput ""
            set lsPrint [split [mql print $sType $sName] \n]
      
            foreach sPrint $lsPrint {                         
               set sPrint [string trim $sPrint]
      
               if {$sType == "policy"} {
                  if {[string first "state" $sPrint] == 0} {
                     foreach sState $lsState {
                        if {[string first "state $sState" $sPrint] == 0} {
                           set sStateName $sState
                           break
                        }
                     }
                  }
               }
                           
               set bCatchTest false
               
               foreach sCatchTest $lsCatchTest {
                  if {[string first "$sCatchTest " $sPrint] == 0} {
                     set bCatchTest true
                     break
                  }
               }
               
               if {$bCatchTest == "true"} {
                  regsub "$sCatchTest " $sPrint "" sPrint
                  
                  if {$sCatchTest == "trigger"} {

# Change commented line below below with 2 following it
#                     set lsTrig [split $sPrint ","]
                     regsub -all "\\\)," $sPrint "|" sPrint
                     set lsTrig [split $sPrint "|"]
# End Change - 04/20/2005 MJOsterman

                     foreach sTrig $lsTrig {
                        regsub ":" $sTrig "|" sTrig
                        set lslsTrig [split $sTrig |]
                        set sTrigEventType [string tolower [lindex $lslsTrig 0]]
                        
                        if {$sTrigEventType == "checkincheck"} {
                           set sTrigEvent checkin
                           set sTrigType check
                        } elseif {$sTrigEventType == "checkinaction"} {
                           set sTrigEvent checkin
                           set sTrigType action
                        } elseif {$sTrigEventType == "checkinoverride"} {
                           set sTrigEvent checkin
                           set sTrigType override
                        } elseif {$sTrigEventType == "checkoutcheck"} {
                           set sTrigEvent checkout
                           set sTrigType check
                        } elseif {$sTrigEventType == "checkoutaction"} {
                           set sTrigEvent checkout
                           set sTrigType action
                        } elseif {$sTrigEventType == "checkoutoverride"} {
                           set sTrigEvent checkout
                           set sTrigType override
                        } elseif {[regsub "check" $sTrigEventType "" sTrigEvent] == 1} {
                           set sTrigType "check"
                        } elseif {[regsub "action" $sTrigEventType "" sTrigEvent] == 1} {
                           set sTrigType "action"
                        } elseif {[regsub "override" $sTrigEventType "" sTrigEvent] == 1} {
                           set sTrigType "override"
                        }
                        
                        set slsTrigProg [lindex $lslsTrig 1]
                        regsub "\\(" $slsTrigProg "|" slsTrigProg
                        set lslsTrigProg [split $slsTrigProg |]
                        set sProgram [lindex $lslsTrigProg 0]
                        set sInput [lindex $lslsTrigProg 1]
                        regsub "\\)" $sInput "" sInput
                        append sFile "$sType\t$sName\t$sStateName\t$sTrigEvent\t$sTrigType\t$sProgram\t$sInput\n"
                     }
                  } else {
                     set sTrigType $sCatchTest
                     regsub " input " $sPrint "|" sPrint
                     set lsTrig [split $sPrint |]
                     set sProgram [string trim [lindex $lsTrig 0]]
                     regsub -all "'" $sProgram "" sProgram
                     set sInput [string trim [lindex $lsTrig 1]]
                     regsub -all "'" $sInput "" sInput
                     append sFile "$sType\t$sName\t$sStateName\tevent\t$sTrigType\t$sProgram\t$sInput\n"
                  }
               }
            }
         }
      }
   }

   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Trigger data loaded in file $sPath"
}
