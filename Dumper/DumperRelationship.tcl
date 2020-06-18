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
   set sTypeReplace "relationship "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "relationship"} {
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

   set sPath "$sSpinnerPath/SpinnerRelationshipData.xls"
   set sMxVersion [join [lrange [split [mql version] .] 0 1] .]
   set lsRelationship [split [mql list relationship $sFilter] \n]
   if {$sMxVersion >= 10.8} {
      set sFile "Name\tRegistry Name\tDescription\tAttributes (use \"|\" delim)\tSparse (boolean)\tHidden (boolean)\tPreventDuplicates (boolean)\tFrom Types (use \"|\" delim)\tFrom Rels (use \"|\" delim)\tFrom Revision (none or \"\"/ float / replicate)\tFrom Clone (none or \"\" / float / replicate)\tFrom Cardinality (one / many or \"\")\tFrom Propagate Modify (boolean)\tTo Types (use \"|\" delim)\tTo Rels (use \"|\" delim)\tTo Revision (none or \"\" / float / replicate)\tTo Clone (none or \"\" / float / replicate)\tTo Cardinality (one / many or \"\")\tTo Propagate Modify (boolean)\tFrom Propagate Connect (boolean)\tTo Propagate Connect (boolean)\tIcon File\n"
   } else {
      set sFile "Name\tRegistry Name\tDescription\tAttributes (use \"|\" delim)\tSparse (boolean)\tHidden (boolean)\tPreventDuplicates (boolean)\tFrom Types (use \"|\" delim)\tFrom Meaning\tFrom Revision (none or \"\"/ float / replicate)\tFrom Clone (none or \"\" / float / replicate)\tFrom Cardinality (one / many or \"\")\tFrom Propagate Modify (boolean)\tTo Types (use \"|\" delim)\tTo Meaning\tTo Revision (none or \"\" / float / replicate)\tTo Clone (none or \"\" / float / replicate)\tTo Cardinality (one / many or \"\")\tTo Propagate Modify (boolean)\tFrom Propagate Connect (boolean)\tTo Propagate Connect (boolean)\tIcon File\n"
   }
   foreach sRelationship $lsRelationship {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print relationship $sRelationship select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print relationship $sRelationship select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print relationship $sRelationship select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print relationship $sRelationship select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sRelationship)} sMsg
         regsub -all " " $sRelationship "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sRelationship
         }
         set sDescription [mql print relationship $sRelationship select description dump]
         set bSparse [mql print relationship $sRelationship select sparse dump]
         set bHidden [mql print relationship $sRelationship select hidden dump]
         set bPreventDuplicate [mql print relationship $sRelationship select preventduplicates dump]
         set sFromMeaning [mql print relationship $sRelationship select frommeaning dump]
         set sFromRevision [mql print relationship $sRelationship select fromreviseaction dump]
         set sFromClone [mql print relationship $sRelationship select fromcloneaction dump]
         set sFromCardinality [mql print relationship $sRelationship select fromcardinality dump]
         set sToMeaning [mql print relationship $sRelationship select tomeaning dump]
         set sToRevision [mql print relationship $sRelationship select toreviseaction dump]
         set sToClone [mql print relationship $sRelationship select tocloneaction dump]
         set sToCardinality [mql print relationship $sRelationship select tocardinality dump]
         set slsFromType [mql print relationship $sRelationship select fromtype dump " | "]
         set slsToType [mql print relationship $sRelationship select totype dump " | "]
         if {$sMxVersion >= 10.8} {
            set slsFromRel [mql print relationship $sRelationship select fromrel dump " | "]
            set slsToRel [mql print relationship $sRelationship select torel dump " | "]
         }
         

         if {$sMxVersion < 10.5} {
            set bFromPropConnect ""
            set bToPropConnect ""
            if {$slsFromType == ""} {
               set lsPrint [split [mql print relationship $sRelationship] \n]
               set bTrip FALSE
               foreach sPrint $lsPrint {
                  set sPrint [string trim $sPrint]
                  if {$bTrip} {
                     if {$sPrint == "to"} {
                        break
                     } elseif {$sPrint == "type all"} {
                        set slsFromType all
                     }
                  } elseif {$sPrint == "from"} {
                     set bTrip TRUE
                  }
               }
            }
            if {$slsToType == ""} {
               set lsPrint [split [mql print relationship $sRelationship] \n]
               set bTrip FALSE
               foreach sPrint $lsPrint {
                  set sPrint [string trim $sPrint]
                  if {$bTrip} {
                     if {$sPrint == "type all"} {
                        set slsToType all
                     }
                  } elseif {$sPrint == "to"} {
                     set bTrip TRUE
                  }
               }
            }
      
            set lsRel [split [mql print rel $sRelationship] \n]
            set iCounter 0
            foreach sRel $lsRel {
               set sRel [string trim $sRel]
               if {[string first "propagate modify" $sRel] == 0} {
                  incr iCounter
                  set lslsRel [split $sRel " "]
                  if {$iCounter == 1} {
                     set bFromPropModify [lindex $lslsRel 2]
                  } else {
                     set bToPropModify [lindex $lslsRel 2]
                  }
               }
               if {$iCounter > 1} {
                  break
               }
            }
         } else {
            set bFromPropModify [mql print relationship $sRelationship select frompropagatemodify dump]
            set bToPropModify [mql print relationship $sRelationship select topropagatemodify dump]
            set bFromPropConnect [mql print relationship $sRelationship select frompropagateconnection dump]
            set bToPropConnect [mql print relationship $sRelationship select topropagateconnection dump]
         }

         set slsAttribute [mql print relationship $sRelationship select attribute dump " | "]
         if {$sMxVersion >= 10.8} {
            append sFile "$sName\t$sOrigName\t$sDescription\t$slsAttribute\t$bSparse\t$bHidden\t$bPreventDuplicate\t$slsFromType\t$slsFromRel\t$sFromRevision\t$sFromClone\t$sFromCardinality\t$bFromPropModify\t$slsToType\t$slsToRel\t$sToRevision\t$sToClone\t$sToCardinality\t$bToPropModify\t$bFromPropConnect\t$bToPropConnect\n"
         } else {
            append sFile "$sName\t$sOrigName\t$sDescription\t$slsAttribute\t$bSparse\t$bHidden\t$bPreventDuplicate\t$slsFromType\t$sFromMeaning\t$sFromRevision\t$sFromClone\t$sFromCardinality\t$bFromPropModify\t$slsToType\t$sToMeaning\t$sToRevision\t$sToClone\t$sToCardinality\t$bToPropModify\t$bFromPropConnect\t$bToPropConnect\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Relationship data loaded in file $sPath"
}