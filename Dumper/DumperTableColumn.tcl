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

   set sMxVersion [string range [mql version] 0 2]
   set sPath "$sSpinnerPath/SpinnerTableColumnData.xls"
   set lsTable [split [mql list table system] \n]
   set sFile "Table Name\tColumn Name\tColumn Label\tCol Description\tExpression Type (bus or \"\" / rel)\tExpression\tHref\tSetting Names (use \"|\" delim)\tSetting Values (use \"|\" delim)\tUsers (use \"|\" delim)\tAlt\tRange\tUpdate\tSortType (alpha / numeric / other / none or \"\")\n"
   foreach sTable $lsTable {
      set bPass TRUE
      set sModDate [mql print table $sTable system select modified dump]
      set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
      if {$sModDateMin != "" && $sModDate < $sModDateMin} {
         set bPass FALSE
      } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
         set bPass FALSE
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print table $sTable system select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print table $sTable system select property\[SpinnerAgent\] dump] != "")} {
         set lsColumn [split [mql print table $sTable system select column dump |] |]
         foreach sColumn $lsColumn {
            set sName $sColumn
            for {set i 0} {$i < [string length $sName]} {incr i} {
               if {[string range $sName $i $i] == " "} {
                  regsub " " $sName "<SPACE>" sName
               } else {
                  break
               }
            }
            set sLabel [mql print table $sTable system select column\[$sColumn\].label dump]
            set sDescription [mql print table $sTable system select column\[$sColumn\].description dump]
            set sExpressionType [mql print table $sTable system select column\[$sColumn\].expressiontype dump]
            set sExpression [mql print table $sTable system select column\[$sColumn\].expression dump]
            set sHref [mql print table $sTable system select column\[$sColumn\].href dump]
            set sAlt [mql print table $sTable system select column\[$sColumn\].alt dump]
            set sRange [mql print table $sTable system select column\[$sColumn\].range dump]
            set sUpdate [mql print table $sTable system select column\[$sColumn\].update dump]
            set slsSettingName [mql print table $sTable system select column\[$sColumn\].setting dump " | "]
            set slsSettingValue [mql print table $sTable system select column\[$sColumn\].setting.value dump " | "]
            if {$sMxVersion >= 9.6} {
               set slsUser [mql print table $sTable system select column\[$sColumn\].user dump " | "]
               set sAlt [mql print table $sTable system select column\[$sColumn\].alt dump]
               set sRange [mql print table $sTable system select column\[$sColumn\].range dump]
               set sUpdate [mql print table $sTable system select column\[$sColumn\].update dump]
               set sSortType "none"
               set lsPrint [split [mql print table $sTable system] \n]
               set bTrip "FALSE"
               foreach sPrint $lsPrint {
                  set sPrint [string trim $sPrint]
                  if {[string range $sPrint 0 3] == "name" && [string first $sColumn $sPrint] > 3} {
                     set bTrip TRUE
                  } elseif {$bTrip && [string range $sPrint 0 3] == "name"} {
                     break
                  } elseif {$bTrip} {
                     if {[string range $sPrint 0 7] == "sorttype"} {
                        regsub "sorttype" $sPrint "" sPrint
                        set sSortType [string trim $sPrint]
                        break
                     }
                  } 
               }
            } else {
               set slsUser ""
               set sAlt ""
               set sRange ""
               set sUpdate ""
               set sSortType ""
            }
            set sTableName $sTable
            for {set i 0} {$i < [string length $sTableName]} {incr i} {
               if {[string range $sTableName $i $i] == " "} {
                  regsub " " $sTableName "<SPACE>" sTableName
               } else {
                  break
               }
            }
            append sFile "$sTableName\t$sName\t$sLabel\t$sDescription\t$sExpressionType\t$sExpression\t$sHref\t$slsSettingName\t$slsSettingValue\t$slsUser\t$sAlt\t$sRange\t$sUpdate\t$sSortType\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Table Column data loaded in file $sPath"
}
