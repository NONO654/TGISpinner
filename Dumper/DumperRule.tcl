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
   set sTypeReplace "rule "
   set sMxVersion [string range [mql version] 0 2]

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "rule"} {
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

   set sPath "$sSpinnerPath/SpinnerRuleData.xls"
   if {$sMxVersion < 9.0} {
      set lsRule [split [mql list rule] \n]
   } else {
      set lsRule [split [mql list rule $sFilter] \n]
   }
   set sFile "Rule Name\tRegistry Name\tDescription\tPrograms (use \"|\" delim)\tAttributes (use \"|\" delim)\tRelationships (use \"|\" delim)\tForms (use \"|\" delim)\tAccess (use \"|\" delim)\tHidden (boolean)\tIcon File\n"
   foreach sRule $lsRule {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print rule $sRule select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print rule $sRule select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print rule $sRule select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print rule $sRule select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sRule)} sMsg
         regsub -all " " $sRule "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sRule
         }
         set sDescription [mql print rule $sRule select description dump]
         set bHidden [mql print rule $sRule select hidden dump]
         
         set lsAccess ""
         set slsAccess ""
         set lsAccessTemp [split [mql print rule $sRule select access] \n]
         foreach sAccessTemp $lsAccessTemp {
            set sAccessTemp [string trim $sAccessTemp]
            if {[string first "access\[" $sAccessTemp] > -1} {
               set iFirst [expr [string first "access\[" $sAccessTemp] + 7]
               set iSecond [expr [string first "\] =" $sAccessTemp] -1]
               lappend lsAccess [string range $sAccessTemp $iFirst $iSecond]
            }
         }
         set slsAccess [join $lsAccess " | "]
         
         set slsProgram ""
         set slsAttribute ""
         set slsForm "" 
         set slsRelationship ""
         set lsPrint [split [mql print rule $sRule] \n]                            
         foreach sPrint $lsPrint {
            set sPrint [string trim $sPrint]
            foreach sReference [list program attribute form "Relationship Type"] {
               if {[string first $sReference $sPrint] == 0} {
                  regsub "$sReference\: " $sPrint "" slsReference
                  regsub -all ", " $slsReference " | " slsReference
                  switch $sReference {
                     program {
                        set slsProgram $slsReference
                     } attribute {
                        set slsAttribute $slsReference
                     } form {
                        set slsForm $slsReference
                     } "Relationship Type" {
                        set slsRelationship $slsReference
                     }
                  }
               }
            }
         }
         
         append sFile "$sName\t$sOrigName\t$sDescription\t$slsProgram\t$slsAttribute\t$slsRelationship\t$slsForm\t$slsAccess\t$bHidden\n"
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Rule data loaded in file $sPath"
}
