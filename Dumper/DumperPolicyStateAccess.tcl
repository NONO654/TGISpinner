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

    set sFilterQuery               "*";   #  default "*" - name filter
   
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

    proc pFormatSpinner { lData sHead sType } {
    
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

# Main
    set sMxVersion [join [lrange [split [mql version] .] 0 1] .]
    set lAccessModes [ list Read Modify Delete Checkout Checkin Schedule Lock \
        Unlock Execute Freeze Thaw Create Revise Promote Demote Grant Enable \
        Disable Override ChangeName ChangeType ChangeOwner ChangePolicy Revoke \
        ChangeVault FromConnect ToConnect FromDisconnect ToDisconnect \
        ViewForm Modifyform Show ]
        
    set sPositive Y
    set sNegative "-"

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
    file mkdir "$sSpinnerPath/Policy"
 
    if {[mql get env GLOBALFILTER] != ""} {
       set sFilterQuery [mql get env GLOBALFILTER]
    } elseif {$sFilterQuery == ""} {
       set sFilterQuery "*"
    }
    set lPolicy [split [mql list policy $sFilterQuery] \n]

    foreach sPol $lPolicy {
        set sStates [ split [ mql print policy $sPol select state dump | ] | ]
        set bAllstate FALSE
        if {$sMxVersion >= 10.8} {set bAllstate [ mql print policy $sPol select allstate dump ]}
        if {$bAllstate && $sStates != [list ]} {lappend sStates "allstate"}
        set sStOrder 0
        foreach sSt $sStates {
            if {$sSt == "allstate"} {
                set sOwner [ split [ string trim [ mql print policy $sPol select allstate.owneraccess dump | ] ] , ]
                set data($sPol|$sStOrder|$sSt,0,Owner) [ list $sOwner "" ]
                set sPublic [ split [ string trim [ mql print policy $sPol select allstate.publicaccess dump | ] ] , ]
                set data($sPol|$sStOrder|$sSt,0,Public) [ list $sPublic "" ]
                set sUsers [ split [ mql print policy $sPol select allstate.access ] \n ]
            } else {
                set sOwner [ split [ string trim [ mql print policy $sPol select state\[$sSt\].owneraccess dump | ] ] , ]
                set data($sPol|$sStOrder|$sSt,0,Owner) [ list $sOwner "" ]
                set sPublic [ split [ string trim [ mql print policy $sPol select state\[$sSt\].publicaccess dump | ] ] , ]
                set data($sPol|$sStOrder|$sSt,0,Public) [ list $sPublic "" ]
                set sUsers [ split [ mql print policy $sPol select state\[$sSt\].access ] \n ]
            }
            foreach i $sUsers {
                set i [ string trim $i ]
                if {[string first "policy" $i] == 0} {continue}
                if { $i != "" } {
                    set sLine [ lindex [ split $i "." ] 1 ]
                    set sLine [ split $sLine "=" ]
                    set sRights [ split [ string trim [ lindex $sLine 1 ] ] , ]
                    if { $sRights == "all" } {
#                        set sRights $lAccessModes
                    } elseif { $sRights == "none" } {
                        set sRights ""
                    }
                    set sUs [string trim [ lindex $sLine 0 ] ]
                    if {[string first "access\[" $sUs] > -1} {
                        regsub "access\134\[" $sUs "|" sUs
                        set sUs [lindex [split $sUs |] 1]
                        regsub "\134\]" $sUs "" sOwner
                        if {$sSt == "allstate"} {
                            set sExpression [ mql print policy "$sPol" select allstate.filter\[$sOwner\] dump ]
                        } else {
                            set sExpression [ mql print policy "$sPol" select state\[$sSt\].filter\[$sOwner\] dump ]
                        }
                        set data($sPol|$sStOrder|$sSt,1,$sOwner) [ list $sRights $sExpression ]
                    }
                }
            }
            incr sStOrder
        }
    }
 
    set sSpin ""
    foreach sP $lPolicy {
        set pu [ lsort -dictionary [ array name data "$sP|*|*,*,*" ] ]
        foreach i $pu {
            lappend sSpin [ list $i $data($i) ]
        }
        set sPolicySpin [ pFormatSpinner $sSpin $sP Policy ]
        pfile_write "$sSpinnerPath/Policy/$sP.xls" $sPolicySpin
        set sSpin ""
    }
    puts "Policy State Access data loaded in directory: $sSpinnerPath/Policy"
}