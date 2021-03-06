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
   set sTypeReplace "association "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "association"} {
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

   set sPath "$sSpinnerPath/SpinnerAssociationData.xls"
   set sFile "Name\tRegistry Name\tDescription\tDefinition (use format \"<USER> | and / or | <USER>\" ...)\tHidden (boolean)\tIcon File\n"
   set lsAssociation [split [mql list association] \n]
   set sMxVersion [string range [mql version] 0 2]
   
   foreach sAssociation $lsAssociation {
      set sDescription ""
      set sDefinition ""
      set sModified ""
      set sHidden ""
      set sOrigName ""
      set sSpinnerAgent ""
      set lsPrint [split [mql print association $sAssociation] \n]

      foreach sPrint $lsPrint {
         set sPrint [string trim $sPrint]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sAssociation)} sMsg
         regsub -all " " $sAssociation "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sAssociation
         }
         if {[string first "description" $sPrint] == 0} {
            regsub "description" $sPrint "" sDescription
            set sDescription [string trim $sDescription]
         } elseif {[string first "modified" $sPrint] == 0} {
            regsub "modified" $sPrint "" sModified
            set sModified [string trim $sModified]
         } elseif {[string first "property SpinnerAgent" $sPrint] == 0} {
            regsub "property SpinnerAgent" $sPrint "" sSpinnerAgent
            set sSpinnerAgent [string trim $sSpinnerAgent]
         } elseif {[string first "definition" $sPrint] == 0} {
            regsub "definition" $sPrint "" sDefinition
            regsub -all "\"" $sDefinition "" sDefinition
            regsub -all "&&" $sDefinition "| and |" sDefinition
            regsub -all "\\\|\\\|" $sDefinition "| or |" sDefinition
            set sDefinition [string trim $sDefinition]
         } elseif {$sPrint == "hidden"} {
            set sHidden true
         } elseif {$sPrint == "nothidden"} {
            set sHidden false
         }
      }

      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [clock scan [clock format [clock scan $sModified] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || $sSpinnerAgent != "")} {
         append sFile "$sAssociation\t$sOrigName\t$sDescription\t$sDefinition\t$sHidden\n"
      }
   }

   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Association data loaded in file $sPath"
}
