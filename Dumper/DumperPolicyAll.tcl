tcl;

eval {
   if {[info host] == "MOSTERMAN2K" } {
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

   set sFilterQuery               "*";   #  default "*" - name filter
   set bSpinnerAgentFilter   FALSE; #  default FALSE - filters schema modified by SpinnerAgent if TRUE
   set sGreaterThanEqualDate "";    #  default "" - date range min value formatted mm/dd/yyyy
   set sLessThanEqualDate    "";    #  default "" - date range max value formatted mm/dd/yyyy
#   set sGreaterThanEqualDate [clock format [clock seconds] -format "%m/%d/%Y"]; dynamic setting for current day
   
# End User Defined Settings
#*********************************************************************** 

#************************************************************************
# Procedure:   pfile_write
#
# Description: Procedure to write a variable to file.
#
# Parameters:  The filename to write to,
#              The data variable.
#
# Returns:     Nothing
#************************************************************************

proc pfile_write { filename data } {
  return  [catch {
    set fileid [open $filename "w+"]
    puts $fileid $data
    close $fileid
  }]
}
#End pfile_write

#************************************************************************
# Procedure:   pFormatSpinner
#
# Description: Procedure to format data for spinner file.
#
# Parameters:  The data to format.
#
# Returns:     Nothing
#************************************************************************

    proc pFormatSpinner { lData sHead } {
    
        global lAccessModes
        global sPositive
        global sNegative
     
        set sDelimit "\t"
        set sFormat ""
    
        if { [ llength $lData ] == 0 } {
            append sFormat "No Data"
            return $sFormat
        }
    
        append sFormat "State"
        append sFormat "${sDelimit}User"
    
        # construct the access headers
        foreach sMode $lAccessModes {
            append sFormat "$sDelimit$sMode"
        }
        append sFormat "${sDelimit}Filter"
        append sFormat "\n"
    
        foreach line $lData {
            if { $line == "" } {
                continue
            }
            set sPolicyDetails [ lindex $line 0 ]
            set sPolicyData [ lindex $line 1 ]
            set sFilter [ lindex $sPolicyData 1 ]
            set sLeft [ split [ lindex $line 0 ] , ]
            set sOwner [ lindex $sLeft 2 ]
            set sLeft [ split [ lindex $sLeft 0 ] | ]
            set sPolicy [ lindex $sLeft 0 ]
            set sState [ lindex $sLeft 2 ]
            set sRights [ lindex $sPolicyData 0 ]
    
            append sFormat "$sState"
            append sFormat "$sDelimit$sOwner"
    
            if { $sRights == "all" } {
                set sNegativeValue $sPositive
            } else {
                set sNegativeValue $sNegative
            }
            foreach sMode $lAccessModes {
                set sMode [string tolower $sMode]
                if { [ lsearch $sRights $sMode ] == -1 } {
                    append sFormat "$sDelimit$sNegativeValue"
                } else {
                    append sFormat "$sDelimit$sPositive"
                }
            }
            append sFormat "$sDelimit$sFilter"
            append sFormat "\n"
    
        }
        return $sFormat
    }
#End pFormatSpinner

#  Main

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
      set lsFilterQuery [split [mql get env GLOBALFILTER] ,]
   } elseif {[mql get env 1] != ""} {
      set lsFilterQuery [split [mql get env 1] ,]
   } else {
      set lsFilterQuery [list "*"]
   }
   
   if {[mql get env SPINNERFILTER] != ""} {
      set bSpinnerAgentFilter [mql get env SPINNERFILTER]
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
      file mkdir "$sSpinnerPath/Policy"
      file mkdir "$sSpinnerPath/Objects"
   }

   set sPath "$sSpinnerPath/SpinnerPolicyData.xls"
   set sStatePath "$sSpinnerPath/SpinnerPolicyStateData.xls"
   set sSignaturePath "$sSpinnerPath/SpinnerPolicySignatureData.xls"
   set sTriggerPath "$sSpinnerPath/SpinnerPolicyTriggerData.xls"
   set sPropertyPath "$sSpinnerPath/SpinnerPolicyPropertyData.xls"
   set lsPolicy ""
   foreach sFilterQuery $lsFilterQuery {
      set sFilterQuery [string trim $sFilterQuery]
      set lsPolicy [concat $lsPolicy [split [mql list policy $sFilterQuery] \n]]
   }
   set sFile "Name\tRegistry Name\tDescription\tRev Sequence (use 'continue' for '...')\tStore\tHidden (boolean)\tTypes (use \"|\" delim)\tFormats (use \"|\" delim)\tDefault Format\tLocking (boolean)\tState Names (in order-use \"|\" delim)\tState Registry Names (in order-use \"|\" delim)\n"
   set sStateFile "Policy Name\tState Name\tRevision (boolean)\tVersion (boolean)\tPromote (boolean)\tCheckout History (boolean)\tUsers for Access (use \"|\" delim)\tNotify Users (use \"|\" delim)\tNotify Message\tRoute User\tRoute Message\tSignatures (use \"|\" delim)\tIcon File\n"
   set sSignatureFile "Policy Name\tState Name\tSignature Name\tUsers for Approve (use \"|\" delim)\tUsers for Reject (use \"|\" delim)\tUsers for Ignore (use \"|\" delim)\tBranch State\tFilter\n"
   set sTriggerFile "Schema Type\tSchema Name\tState (for Policy)\tTrigger Event\tTrigger Type (check / override / action)\tProgram\tInput\n"
   set sPropertyFile "Schema Type\tSchema Name\tProperty Name\tProperty Value\tTo Schema Type\tTo Schema Name\n"
   set sMxVersion [string range [mql version] 0 2]
   set lAccessModes [ list Read Modify Delete Checkout Checkin Schedule Lock \
       Unlock Execute Freeze Thaw Create Revise Promote Demote Grant Enable \
       Disable Override ChangeName ChangeType ChangeOwner ChangePolicy Revoke \
       ChangeVault FromConnect ToConnect FromDisconnect ToDisconnect \
       ViewForm Modifyform Show ]
       
   set sPositive Y
   set sNegative "-"

   foreach sPolicy $lsPolicy {
      set bPass TRUE
      set sStateOrder 0
      set sModDate [mql print policy $sPolicy select modified dump]
      set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
      if {$sModDateMin != "" && $sModDate < $sModDateMin} {
         set bPass FALSE
      } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
         set bPass FALSE
      }
      
      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print policy $sPolicy select property\[SpinnerAgent\] dump] != "")} {

         set slsType [mql print policy $sPolicy select type dump " | "]
         set slsFormat [mql print policy $sPolicy select format dump " | "]
         set slsState [mql print policy $sPolicy select state dump " | "]
         
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

# State File Info
            set sRevisionable [string tolower [mql print policy $sPolicy select state\[$sState\].revisionable dump]]
            set sVersion [string tolower [mql print policy $sPolicy select state\[$sState\].versionable dump]]
            set sPromote [string tolower [mql print policy $sPolicy select state\[$sState\].autopromote dump]]
            set sCheckout [string tolower [mql print policy $sPolicy select state\[$sState\].checkouthistory dump]]
            set sNotifyMsg [mql print policy $sPolicy select state\[$sState\].notify dump]
            set sRouteMsg [mql print policy $sPolicy select state\[$sState\].route dump]
            set slsSignature [mql print policy $sPolicy select state\[$sState\].signature dump " | "]

# Signature File Info
            set lsSignature [split $slsSignature |]
            foreach sSignature $lsSignature {
               set sSignature [string trim $sSignature]
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
               append sSignatureFile "$sPolicy\t$sState\t$sSignature\t$slsApprove\t$slsReject\t$slsIgnore\t$sBranch\t$sFilter\n"
            }
# End Signature File Info
                        
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
            append sStateFile "$sPolicy\t$sState\t$sRevisionable\t$sVersion\t$sPromote\t$sCheckout\t$slsAccess\t$slsNotify\t$sNotifyMsg\t$sRoute\t$sRouteMsg\t$slsSignature\n"

# State Access Info
            set sOwner [ split [ string trim [ mql print policy $sPolicy select state\[$sState\].owneraccess dump | ] ] , ]
            set data($sPolicy|$sStateOrder|$sState,0,Owner) [ list $sOwner "" ]
            set sPublic [ split [ string trim [ mql print policy $sPolicy select state\[$sState\].publicaccess dump | ] ] , ]
            set data($sPolicy|$sStateOrder|$sState,0,Public) [ list $sPublic "" ]
            set sUsers [ split [ mql print policy $sPolicy select state\[$sState\] dump ] \n ]
            foreach i $sUsers {
                set i [ string trim $i ]
                if { $i != "" } {
                    set sLine [ split $i : ]
                    set sUs [ split [ lindex $sLine 0 ] ]
                    set sRights [ split [ string trim [ lindex $sLine 1 ] ] , ]
                    set sName [ lindex $sUs 0 ]
                    set sOwner [ lrange $sUs 1 end ]
                    if { $sName == "user" } {
                        set sExpression [ mql print policy "$sPolicy" select state\[$sState\].filter\[$sOwner\] dump ]
                        set data($sPolicy|$sStateOrder|$sState,1,$sOwner) [ list $sRights $sExpression ]
                    }
                }
            }
            incr sStateOrder
# End State Access Info

         }
# End State File Info
   
         set sPolicyName [mql print policy $sPolicy select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sPolicy)} sMsg
         regsub -all " " $sPolicy "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sPolicy
         }
         set sRevSequence [mql print policy $sPolicy select revision dump]
         regsub -all "\134.\134.\134." $sRevSequence "continue" sRevSequence
         set bHidden [mql print policy $sPolicy select hidden dump]
         set bLocking [mql print policy $sPolicy select islockingenforced dump]
         
         set sStore [mql print policy $sPolicy select store dump]
         set sDefaultFormat [mql print policy $sPolicy select defaultformat dump]
         set sDescription [mql print policy $sPolicy select description dump]
         
         append sFile "$sPolicyName\t$sOrigName\t$sDescription\t$sRevSequence\t$sStore\t$bHidden\t$slsType\t$slsFormat\t$sDefaultFormat\t$bLocking\t$slsState\t$slsStateOrig\n"
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Policy data loaded in file $sPath"

   set iFile [open $sStatePath w]
   puts $iFile $sStateFile
   close $iFile
   puts "Policy State data loaded in file $sStatePath"

   set iFile [open $sSignaturePath w]
   puts $iFile $sSignatureFile
   close $iFile
   puts "Policy State Signature data loaded in file $sSignaturePath"
   
   set lsSpin ""
   foreach sP $lsPolicy {
      set pu [ lsort -dictionary [ array name data "$sP|*|*,*,*" ] ]
      foreach i $pu {
         lappend lsSpin [ list $i $data($i) ]
      }
      set sPolicySpin [ pFormatSpinner $lsSpin $sP ]
      pfile_write "$sSpinnerPath/Policy/$sP.xls" $sPolicySpin
      set lsSpin ""
   }
   puts "Policy State Access data loaded in directory $sSpinnerPath/Policy"

# Trigger Info
   set lsCatchTest [list action check trigger]
   set sAttr1  [ mql print type "eService Trigger Program Parameters" select attribute dump \t ]
   set bParam FALSE
   set lsProgram ""

   foreach sPolicy $lsPolicy {
      set lsState [split [mql print policy $sPolicy select state dump |] |]
      set lsState [lsort -decreasing $lsState]
      set sStateName ""
      set sProgram ""
      set sInput ""
      set lsInput ""
      set lsPrint [split [mql print policy $sPolicy] \n]
   
      foreach sPrint $lsPrint {                         
         set sPrint [string trim $sPrint]
   
         if {[string first "state" $sPrint] == 0} {
            foreach sState $lsState {
               if {[string first "state $sState" $sPrint] == 0} {
                  set sStateName $sState
                  break
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
               set lsTrig [split $sPrint ","]
               foreach sTrig $lsTrig {
                  regsub ":" $sTrig "|" sTrig
                  set lslsTrig [split $sTrig |]
                  set sTrigEventType [string tolower [lindex $lslsTrig 0]]
                  
                  if {[regsub "check" $sTrigEventType "" sTrigEvent] == 1} {
                     set sTrigType "check"
                  } elseif {[regsub "action" $sTrigEventType "" sTrigEvent] == 1} {
                     set sTrigType "action"
                  } elseif {[regsub "override" $sTrigEventType "" sTrigEvent] == 1} {
                     set sTrigType "override"
                  }
                  
                  set slsTrigProg [lindex $lslsTrig 1]
                  regsub "\134(" $slsTrigProg "|" slsTrigProg
                  set lslsTrigProg [split $slsTrigProg |]
                  set sProgram [lindex $lslsTrigProg 0]
                  set sInput [lindex $lslsTrigProg 1]
                  regsub "\134)" $sInput "" sInput
                  if {$sInput != "" && [lsearch $lsInput $sInput] < 0} {lappend lsInput $sInput}
                  append sTriggerFile "policy\t$sPolicy\t$sStateName\t$sTrigEvent\t$sTrigType\t$sProgram\t$sInput\n"
               }
            } else {
               set sTrigType $sCatchTest
               regsub " input " $sPrint "|" sPrint
               set lsTrig [split $sPrint |]
               set sProgram [string trim [lindex $lsTrig 0]]
               regsub -all "'" $sProgram "" sProgram
               set sInput [string trim [lindex $lsTrig 1]]
               regsub -all "'" $sInput "" sInput
               append sTriggerFile "policy\t$sPolicy\t$sStateName\tevent\t$sTrigType\t$sProgram\t$sInput\n"
            }
         }

# Trigger Program Parameter Objects
         if {$lsInput != ""} {
            set fname "bo_$sPolicy\_eServiceTriggerProgramParameters"
            regsub -all "/" $fname "_FWDSLASH_" fname
            set p_filename "$sSpinnerPath/Objects/$fname\.xls"
            set p_file [open $p_filename w]
            set lBos "Type\tName\tRev\tNew Name\tNew Rev\tPolicy\tState\tVault\tOwner\tdescription\t$sAttr1"
            puts $p_file "$lBos"
            foreach sInput $lsInput {
               set s_file [mql temp query bus "eService Trigger Program Parameters" "$sInput" * select name grant policy current vault owner description attribute.value dump \t]
               puts $p_file $s_file
               set lsFile [split $s_file \n]
               foreach sFile $lsFile {
                  set sRev [lindex [split $sFile \t] 2]
                  set sProgram [mql print bus "eService Trigger Program Parameters" "$sInput" "$sRev" select attribute\[eService Program Name\] dump]
                  if {[lsearch $lsProgram $sProgram] < 0} {lappend lsProgram $sProgram}
               }
            }
            close $p_file
            set bParam TRUE
         }
# End Trigger Program Parameter Objects

      }
# End Trigger Info

# Property Info
      set lsPrint [split [mql print policy $sPolicy select property dump |] |]

      foreach sPrint $lsPrint {
         set sToType ""
         set sToName ""
         set sPropertyValue ""
         if {[string first " value " $sPrint] > -1} {
            regsub " value " $sPrint "|" slsPrint
            set lslsPrint [split $slsPrint |]
            set sPropertyValue [lindex $lslsPrint 1]
            set sPrint [lindex $lslsPrint 0]
         }
         if {[string first " to " $sPrint] > -1} {
            regsub " to " $sPrint "|" slsPrint
            set lslsPrint [split $slsPrint |]
            set sPropertyName [lindex $lslsPrint 0]
            set slsToTypeName [lindex $lslsPrint 1]
            regsub " " $slsToTypeName "|" slsToTypeName
            set lslsToTypeName [split $slsToTypeName |]
            set sToType [lindex $lslsToTypeName 0]
            set sToName [lindex $lslsToTypeName 1]
         } else {
            set sPropertyName [string trim $sPrint]
         }

         if {$sPolicy != "policy" || [string first "state_" $sPropertyName] != 0} {
#            if {$sPropertyName != "" && $sPropertyName != "original name" && $sPropertyName != "installed date" && $sPropertyName != "installer" && $sPropertyName != "version" && $sPropertyName != "application"&& $sPropertyName != "SpinnerAgent"} {
               append sPropertyFile "policy\t$sPolicy\t$sPropertyName\t$sPropertyValue\t$sToType\t$sToName\n"
#            }
         }
      }
   } 
# End Property Info

   set iFile [open $sTriggerPath w]
   puts $iFile $sTriggerFile
   close $iFile
   puts "Policy Trigger data loaded in file $sTriggerPath"
   if {$bParam} {puts "Policy Trigger Program Parameter Objects loaded in directory $sSpinnerPath\/Objects"}
   
   set iFile [open $sPropertyPath w]
   puts $iFile $sPropertyFile
   close $iFile
   puts "Policy Property data loaded in file $sPropertyPath"
}
