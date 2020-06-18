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

   set sPath "$sSpinnerPath/SpinnerWebFormFieldData.xls"
   set lsForm [split [mql list form] \n]
   set sFile "WebForm Name\tField Name\tField Label\tField Description\tExpression Type (bus or \"\" / rel)\tExpression\tHref\tSetting Names (use \"|\" delim)\tSetting Values (use \"|\" delim)\tUsers (use \"|\" delim)\tAlt\tRange\tUpdate\tField Order\n"
   foreach sForm $lsForm {
      if {[mql print form $sForm select web dump] == "TRUE"} {
         set bPass TRUE
         set sModDate [mql print form $sForm select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
         
         if {$sOrigNameFilter != ""} {
            set sOrigName [mql print form $sForm select property\[original name\].value dump]
            if {[string match $sOrigNameFilter $sOrigName] == 1} {
               set bPass TRUE
            } else {
               set bPass FALSE
            }
         }
   
         if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print form $sForm select property\[SpinnerAgent\] dump] != "")} {
#            set lsField [split [mql print form $sForm select field dump |] |]
#            set iFieldNo 1
            set lsField [split [mql print form $sForm] \n]
            set bField FALSE
            set iCounter 1
            foreach sField $lsField {
#               set sName $sField
#               set sLabel [mql print form $sForm select field\[$sField\].label dump]
#               set sDescription [mql print form $sForm select field\[$sField\].description dump]
#               set sExpressionType [mql print form $sForm select field\[$sField\].expressiontype dump]
#               set sExpression [mql print form $sForm select field\[$sField\].expression dump]
#               set sHref [mql print form $sForm select field\[$sField\].href dump]
#               set sAlt [mql print form $sForm select field\[$sField\].alt dump]
#               set sRange [mql print form $sForm select field\[$sField\].range dump]
#               set sUpdate [mql print form $sForm select field\[$sField\].update dump]
#               set slsSettingName [mql print form $sForm select field\[$sField\].setting dump " | "]
#               set slsSettingValue [mql print form $sForm select field\[$sField\].setting.value dump " | "]
#               set slsUser [mql print form $sForm select field\[$sField\].user dump " | "]
#               append sFile "$sForm\t$sName\t$sLabel\t$sDescription\t$sExpressionType\t$sExpression\t$sHref\t$slsSettingName\t$slsSettingValue\t$slsUser\t$sAlt\t$sRange\t$sUpdate\t$iFieldNo\n"
#               incr iFieldNo
#
# Mod to allow |'s in WebForm Fields
               set sField [string trim $sField]
               if {[string range $sField 0 5] == "field#"} {
                  set bField TRUE
                  set sName ""
                  set sLabel ""
                  set sDescription ""
                  set sExpressionType ""
                  set sExpression ""
                  set sHref ""
                  set sAlt ""
                  set sRange ""
                  set sUpdate ""
                  set lsSettingName ""
                  set lsSettingValue ""
                  set lsUser ""
                  set iFieldOrder $iCounter
                  incr iCounter
                  set iSelect [string first "select" $sField]
                  if {$iSelect >= 0} {
                     set sExpression [string range $sField [expr $iSelect + 7] end]
                  }
               } elseif {$bField} {
                  if {$sField == ""} {
                     set slsSettingName [join $lsSettingName " | "]
                     set slsSettingValue [join $lsSettingValue " | "]
                     set slsUser [join $lsUser " | "]
                     set sFormName $sForm
                     for {set i 0} {$i < [string length $sFormName]} {incr i} {
                        if {[string range $sFormName $i $i] == " "} {
                           regsub " " $sFormName "<SPACE>" sFormName
                        } else {
                           break
                        }
                     }
                     append sFile "$sFormName\t$sName\t$sLabel\t$sDescription\t$sExpressionType\t$sExpression\t$sHref\t$slsSettingName\t$slsSettingValue\t$slsUser\t$sAlt\t$sRange\t$sUpdate\t$iFieldOrder\n"
                  } else {
                     regsub " " $sField "^" sFieldTemp
                     set lsFieldTemp [split $sFieldTemp ^]
                     set sChoice [lindex $lsFieldTemp 0]
                     set sValue [lindex $lsFieldTemp 1]
                     if {$sChoice == "name"} {
                        regsub "        " $sValue "" sValue
                        for {set i 0} {$i < [string length $sValue]} {incr i} {
                           if {[string range $sValue $i $i] == " "} {
                              regsub " " $sValue "<SPACE>" sValue
                           } else {
                              break
                           }
                        }
                     } else {
                        set sValue [string trim $sValue]
                     }
                     switch $sChoice {
                        expressiontype {
                           set sExpressionType $sValue
                        } name {
                           set sName $sValue
                        } label {
                           set sLabel $sValue
                        } href {
                           set sHref $sValue
                        } alt {
                           set sAlt $sValue
                        } range {
                           set sRange $sValue
                        } update {
                           set sUpdate $sValue
                        } description {
                           set sDescription $sValue
                        } user {
                           lappend lsUser $sValue
                        } setting {
                           regsub " value " $sValue "^" sValue
                           set lsValue [split $sValue ^]
                           lappend lsSettingName [lindex $lsValue 0]
                           lappend lsSettingValue [lindex $lsValue 1]
                        }
                     }
                  }
               }
# End Mod
            }
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "WebForm Field data loaded in file $sPath"
}
