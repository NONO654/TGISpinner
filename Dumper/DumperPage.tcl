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
   set sTypeReplace "page "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "page"} {
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

   set sPath "$sSpinnerPath/SpinnerPageData.xls"
   set sPageFileDir "$sSpinnerPath/PageFiles"
   file mkdir $sPageFileDir
   set lsPage [split [mql list page $sFilter] \n]
   set sFile "Page Name\tRegistry Name\tDescription\tMime Type\tHidden (boolean)\tIcon File\n"
   set sMxVersion [string range [mql version] 0 3]

   foreach sPage $lsPage {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print page $sPage select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print page $sPage select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print page $sPage select property\[SpinnerAgent\] dump] != "")} {
         set sName [mql print page $sPage select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sPage)} sMsg
         regsub -all " " $sPage "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sPage
         }

         set sDescription [mql print page $sPage select description dump]
         set sMimeType [mql print page $sPage select mime dump]
         set bHidden [mql print page $sPage select hidden dump]

         append sFile "$sName\t$sOrigName\t$sDescription\t$sMimeType\t$bHidden\n"
         regsub -all "/" $sPage "SLASH" sPageFile 
         mql print page $sPage select content dump output "$sPageFileDir/$sPageFile"
   
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Page data loaded in file $sPath\nPage files loaded in directory $sPageFileDir"
}