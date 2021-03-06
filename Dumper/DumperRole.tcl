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

proc pContinue {lsList} {
   set bFirst TRUE
   set slsList ""
   set lslsList ""
   foreach sList $lsList {
      if {$bFirst} {
         set slsList $sList
         set bFirst FALSE
      } else {
         append slsList " | $sList"
         if {[string length $slsList] > 6400} {
            lappend lslsList $slsList
            set slsList ""
            set bFirst TRUE
         }
      }
   }
   if {$slsList != ""} {
      lappend lslsList $slsList
   }
   return $lslsList
}

#  Set up array for symbolic name mapping
#
   set lsPropertyName ""
   catch {set lsPropertyName [split [mql print program eServiceSchemaVariableMapping.tcl select property.name dump |] |]} sMsg
   set sTypeReplace "role "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "role"} {
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

   set sPath "$sSpinnerPath/SpinnerRoleData.xls"
   set lsRole [split [mql list role $sFilter] \n]
   set sMxVersion [string range [mql version] 0 2]
   set sFile "Role Name\tRegistry Name\tDescription\tParent Roles (use \"|\" delim)\tChild Roles (use \"|\" delim)\tAssignments (use \"|\" delim)\tSite\tHidden (boolean)\tIcon File\n"
   foreach sRole $lsRole {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print role $sRole select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print role $sRole select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print role $sRole select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print role $sRole select name dump]
         set sDescription [mql print role $sRole select description dump]
         set slsParentRole [mql print role $sRole select parent dump " | "]
         set lsChildRole [pContinue [split [mql print role $sRole select child dump |] |] ]
         set iLast [llength $lsChildRole]
         set lsAssignment [pContinue [split [mql print role $sRole select assignment dump |] |] ]
         if {[llength $lsAssignment] > $iLast} {
            set iLast [llength $lsAssignment]
         }
         set bHidden [mql print role $sRole select hidden dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sRole)} sMsg
         regsub -all " " $sRole "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sRole
         }
         set sSite ""
         set lsSiteTemp [split [mql print role $sRole] \n]
         foreach sSiteTemp $lsSiteTemp {
            set sSiteTemp [string trim $sSiteTemp]
            if {[string first "site" $sSiteTemp] == 0} {
               regsub "site " $sSiteTemp "" sSite
               break
            }
         }
         set iCounter 1
         set sMultiline ""
         if {$iLast > 1} {
            set sMultiline " <MULTILINE.1.$iLast>"
         }
         foreach sOnce [list 1] sChildRole $lsChildRole sAssignment $lsAssignment {
            regsub -all "\\\(" $sName "\\\(" sTestName
            regsub -all "\\\)" $sTestName "\\\)" sTestName
            regsub "$sTestName " $sAssignment "" sAssignment
            regsub -all "\\| $sTestName " $sAssignment "\| " sAssignment
            if {[string range $sAssignment 0 0] == "\"" && [string range $sAssignment end end] == "\""} {
               set sAssignment [string range $sAssignment 1 [expr [string length $sAssignment] - 2]]
            }
            if {$iCounter == 1} {
               append sFile "$sName$sMultiline\t$sOrigName\t$sDescription\t$slsParentRole\t$sChildRole\t$sAssignment\t$sSite\t$bHidden\n"
               set bFirst FALSE
            } else {
               set sMultiline " <MULTILINE.$iCounter.$iLast>"
               append sFile "$sName$sMultiline\t\t\t\t$sChildRole\t$sAssignment\n"
            }
            incr iCounter
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Role data loaded in file $sPath"
}
