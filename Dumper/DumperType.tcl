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
   set sTypeReplace "type "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "type"} {
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

   set sPath "$sSpinnerPath/SpinnerTypeData.xls"
   set sMxVersion [string range [mql version] 0 2]
   set lsType [split [mql list type $sFilter] \n]
   set sFile "Name\tRegistry Name\tParent Type\tAbstract (boolean)\tDescription\tAttributes (use \"|\" delim)\tMethods (use \"|\" delim)\tHidden (boolean)\tSparse (boolean)\tIcon File\n"
   foreach sType $lsType {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print type $sType select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print type $sType select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print type $sType select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print type $sType select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sType)} sMsg
         regsub -all " " $sType "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sType
         }
         set sDescription [mql print type $sType select description dump]
         set sHidden [mql print type $sType select hidden dump]
         set bSparse [mql print type $sType select sparse dump]
         set slsAttribute [mql print type $sType select immediateattribute dump " | "]
         set sDerived [mql print type $sType select derived dump]

         if {$sDerived != ""} {
            set lsMethod [split [mql print type $sType select method dump |] |]
            set lsMethodDerived [split [mql print type $sDerived select method dump |] |]
            set lsMethodDerivative ""
            foreach sMethod $lsMethod {
               if {[lsearch $lsMethodDerived $sMethod] < 0} {
                  lappend lsMethodDerivative $sMethod
               }
            }
            set slsMethod ""
            if {[llength $lsMethodDerivative] > 1} {
               set slsMethod [join $lsMethodDerivative " | "]
            }
	    # Modified for the Incident 318282 by Venkatesh - Start
	    if {[llength $lsMethodDerivative] == 1} {
	    # make sure output file doesn't include curly
	    # brackets around programs whose name contain spaces
	       set slsMethod [lindex $lsMethodDerivative 0]
	    }
	    # Modified for the Incident 318282 by Venkatesh - End

         } else {
            set slsMethod [mql print type $sType select method dump " | "]
         }

         set lsTypeData [split [mql print type $sType] \n]
         set bAbstract false
         foreach sTypeData $lsTypeData {
            set sTypeData [string trim $sTypeData]
            if {[string range $sTypeData 0 7] == "abstract"} {
               regsub "abstract " $sTypeData "" bAbstract
               break
            }
         }
         append sFile "$sName\t$sOrigName\t$sDerived\t$bAbstract\t$sDescription\t$slsAttribute\t$slsMethod\t$sHidden\t$bSparse\n"
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Type data loaded in file $sPath"
}
