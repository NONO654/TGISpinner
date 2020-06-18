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

# Main
    set lAccessModes(1) [ list Read Modify Delete Checkout Checkin Schedule Lock \
        Unlock Execute Freeze Thaw Create Revise Promote Demote Grant Enable \
        Disable Override ChangeName ChangeType ChangeOwner ChangePolicy Revoke \
        ChangeVault FromConnect ToConnect FromDisconnect ToDisconnect \
        ViewForm Modifyform Show ]
        
    set lAccessModes(2) [ list Attribute Type Relationship "Format" Person Group Role \
        Association Policy Program Wizard Report Form Rule Property Site Store Vault \
        server Location Process "Menu" Inquiry Table Portal ]

    set sPositive Y
    set sNegative "-"
    set sPersonAccAdm(1) [list "Person\t[join $lAccessModes(1) \t]"]
    set sPersonAccAdm(2) [list "Person\t[join $lAccessModes(2) \t]"]
    set sFile(1) "SpinnerPersonAccessData.xls"
    set sFile(2) "SpinnerPersonAdminData.xls"

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
    file mkdir "$sSpinnerPath/Person"
 
    if {[mql get env GLOBALFILTER] != ""} {
       set sFilterQuery [mql get env GLOBALFILTER]
    } elseif {$sFilterQuery == ""} {
       set sFilterQuery "*"
    }
    set lsPerson [split [mql list person $sFilterQuery] \n]

    foreach sPerson $lsPerson {
    	set lsPrint [split [mql print person $sPerson] \n]
        foreach i $lsPrint {
            set i [ string trim $i ]
            regsub " " $i ":" i
            set lsi [split $i :] 
            if { [lindex $lsi 0] == "access"} {
                set lsRights(1) [split [lindex $lsi 1] ,]
                set lsRights(2) [split [mql print person $sPerson select admin dump] ,]
                for {set j 1} {$j < 3} {incr j} {
                    if { [lindex $lsRights($j) 0] == "all" } {
                        set sNegativeValue $sPositive
                    } else {
                        set sNegativeValue $sNegative
                    }
                    set sFormat ""
                    foreach sMode $lAccessModes($j) {
                        set sMode [string tolower $sMode]
                        if { [ lsearch $lsRights($j) $sMode ] == -1 } {
                            append sFormat "\t$sNegativeValue"
                        } else {
                            append sFormat "\t$sPositive"
                        }
                    }
                    lappend lsPersonAccAdm($j) "$sPerson$sFormat"
                }
                break
            }
        }
    }
    set lsPersonAccAdm(1) [concat $sPersonAccAdm(1) [lsort $lsPersonAccAdm(1)]]
    set lsPersonAccAdm(2) [concat $sPersonAccAdm(2) [lsort $lsPersonAccAdm(2)]]
    pfile_write "$sSpinnerPath/Person/$sFile(1)" [join $lsPersonAccAdm(1) \n]
    pfile_write "$sSpinnerPath/Person/$sFile(2)" [join $lsPersonAccAdm(2) \n]
    puts "Person Access data loaded in directory: $sSpinnerPath/Person"
}