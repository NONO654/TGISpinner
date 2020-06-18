tcl;

eval {
   set sHost [info host]
   if { $sHost == "MOSTERMAN2K" } {
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

   set sPath "$sSpinnerPath/SpinnerPropertyData.xls"
   set sFile "Schema Type\tSchema Name\tProperty Name\tProperty Value\tTo Schema Type\tTo Schema Name\n"
   set sMxVersion [join [lrange [split [mql version] .] 0 1] .]   
   set lsType [list vault store program group role attribute type relationship format policy command inquiry menu]
   if {$sMxVersion > 10.5} {lappend lsType channel portal}
   if {$sMxVersion >= 10.6} {lappend lsType page interface expression}

   foreach sType $lsType {
      set lsName [split [mql list $sType $sFilter] \n ]

      foreach sName $lsName {
         set bPass TRUE
         set sModDate [mql print $sType $sName select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
         
         if {$sOrigNameFilter != ""} {
            set sOrigName [mql print $sType $sName select property\[original name\].value dump]
            if {[string match $sOrigNameFilter $sOrigName] == 1} {
               set bPass TRUE
            } else {
               set bPass FALSE
            }
         }
   
         if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print $sType $sName select property\[SpinnerAgent\] dump] != "")} {
   
            set lsPrint [split [mql print $sType $sName select property dump |] |]
      
            foreach sPrint $lsPrint {
               set sToType ""
               set sToName ""
               set sPropertyValue ""
               if {[string first " value " $sPrint] > -1} {
                  regsub " value " $sPrint "|" slsPrint
                  set lslsPrint [split $slsPrint |]
                  set sPropertyValue [lindex $lslsPrint 1]
                  set sPrint [lindex $lslsPrint 0]
               }
               if {[string first " to " $sPrint] > -1} {
                  regsub " to " $sPrint "|" slsPrint
                  set lslsPrint [split $slsPrint |]
                  set sPropertyName [lindex $lslsPrint 0]
                  set slsToTypeName [lindex $lslsPrint 1]
                  regsub " " $slsToTypeName "|" slsToTypeName
                  set lslsToTypeName [split $slsToTypeName |]
                  set sToType [lindex $lslsToTypeName 0]
                  set sToName [lindex $lslsToTypeName 1]
               } else {
                  set sPropertyName [string trim $sPrint]
               }

               if {$sType != "policy" || [string first "state_" $sPropertyName] != 0} {
#                  if {$sPropertyName != "" && $sPropertyName != "original name" && $sPropertyName != "installed date" && $sPropertyName != "installer" && $sPropertyName != "version" && $sPropertyName != "application"&& $sPropertyName != "SpinnerAgent"} {
                     append sFile "$sType\t$sName\t$sPropertyName\t$sPropertyValue\t$sToType\t$sToName\n"
#                  }
               }
            }
         }
      }
   }

   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Property data loaded in file $sPath"
}
