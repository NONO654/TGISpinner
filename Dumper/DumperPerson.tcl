tcl;

eval {
 
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

#Main
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
 
    if {[mql get env GLOBALFILTER] != ""} {
        set sFilterQuery [mql get env GLOBALFILTER]
    } elseif {$sFilterQuery == ""} {
        set sFilterQuery "*"
    }
    set sDelimit "\t"
    set lPerson [list ]
    set lPersonData [ list name fullname comment address phone fax email vault site type assign_role assign_group e_mail iconmail password hidden ]
    lappend lPerson [join $lPersonData $sDelimit]
    set lsPerson [split [mql list person $sFilterQuery] \n]

    foreach sPerson $lsPerson {
        set aData(name) $sPerson
        
        set Content [mql print person $sPerson]

        regsub -all -- {\{} $Content { LEFTBRACE } Content
        regsub -all -- {\}} $Content { RIGHTBRACE } Content

        set Content [lrange [split $Content \n] 1 end]
        set lAssign_Role [list ]
        set lAssign_Group [list ]

        foreach item $Content {
            set item [string trimleft $item]
            set lItem [split $item]
            set item_name [lindex $lItem 0]
            set item_content [lrange $item 1 end]
            set aData($item_name) $item_content
            # Case assign
            if { $item_name == "assign" } {
                set user [lrange $item 2 end]
                set group_role [lindex $lItem 1]
                if {$group_role == "group"} {
                    lappend lAssign_Group $user
                } elseif {$group_role == "role"} {
                    lappend lAssign_Role $user
                }
            # Case lattice
            } elseif { $item_name == "lattice" } {
                set vault [lrange $item 1 end]
                set aData(vault) $vault
            # Case mail
            } elseif { $item_name == "enable" || $item_name == "disable" } {
               set sMail [lindex $lItem 1]
               regsub "email" $sMail "e_mail" sMail
               set aData($sMail) $item_name
            # Case hidden
            } elseif { $item_name == "hidden" || $item_name == "nothidden" } {
               set aData(hidden) $item_name
            # Case password
            } elseif { $item_name == "password" } {
               set aData(password) ""
            }
        }
        if {[llength $lAssign_Role] == 0} {
            set aData(assign_role) ""
        } else {
            set lAssign_Role [lsort -dictionary $lAssign_Role]
            set sAssign_Role [join $lAssign_Role |]
            regsub -all -- {\|} $sAssign_Role { | } sAssign_Role
            set aData(assign_role) $sAssign_Role
        }
        if {[llength $lAssign_Group] == 0} {
            set aData(assign_group) ""
        } else {
            set lAssign_Group [lsort -dictionary $lAssign_Group]
            set sAssign_Group [join $lAssign_Group |]
            regsub -all -- {\|} $sAssign_Group { | } sAssign_Group
            set aData(assign_group) $sAssign_Group
        }

        set lDataEach [list ]
        foreach sPersonData $lPersonData {
            if { [ info exists aData($sPersonData) ] == 1 } {
                lappend lDataEach $aData($sPersonData)
            } else {
                lappend lDataEach ""
            }
        }
        lappend lPerson [join $lDataEach $sDelimit]
    }

    pfile_write "$sSpinnerPath/SpinnerPersonData.xls" [join $lPerson "\n"]
    puts "Person data loaded in file $sSpinnerPath/SpinnerPersonData.xls"
}