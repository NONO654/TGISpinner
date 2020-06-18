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
   set sTypeReplace "att "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "attribute"} {
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

   set sPath "$sSpinnerPath/SpinnerAttributeData.xls"
   set lsAttribute [split [mql list attribute $sFilter] \n]
   set sFile "Attribute Name\tRegistry Name\tType\tDescription\tDefault\tRanges (use \"|\" delim)\tMultiline (boolean)\tHidden (boolean)\tDimension\tIcon File\n"
   set sMxVersion [join [lrange [split [mql version] .] 0 1] .]
   foreach sAttribute $lsAttribute {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print attribute $sAttribute select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print attribute $sAttribute select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print attribute $sAttribute select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print attribute $sAttribute select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sAttribute)} sMsg
         regsub -all " " $sAttribute "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sAttribute
         }
         set sDescription [mql print attribute $sAttribute select description dump]
         set sType [mql print attribute $sAttribute select type dump]
         set sDefault [mql print attribute $sAttribute select default dump]
         if {$sDefault == "True" || $sDefault == "true" || $sDefault == "False" || $sDefault == "false"} {
            set sDefault "'$sDefault"
         }
         set bMultiline [mql print attribute $sAttribute select multiline dump]
         set bHidden [mql print attribute $sAttribute select hidden dump]
         set slsRange [mql print attribute $sAttribute select range dump " | "]
         if {$sMxVersion >= 10.8} {
            set sDimension [mql print attribute $sAttribute select dimension dump]
            append sFile "$sName\t$sOrigName\t$sType\t$sDescription\t$sDefault\t $slsRange\t$bMultiline\t$bHidden\t$sDimension\n"
         } else {
            append sFile "$sName\t$sOrigName\t$sType\t$sDescription\t$sDefault\t $slsRange\t$bMultiline\t$bHidden\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Attribute data loaded in file $sPath"
}
