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
   set sTypeReplace "format "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "format"} {
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

   set sPath "$sSpinnerPath/SpinnerFormatData.xls"
   set sFile "Format Name\tRegistry Name\tDescription\tVersion\tFile Suffix\tFile Creator\tFile Type\tView Command\tEdit Command\tPrint Command\tMime\tHidden (boolean)\tIcon File\n"
   set lsFormat [split [mql list format $sFilter] \n]
   set sMxVersion [string range [mql version] 0 2]
   foreach sFormat $lsFormat {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print format $sFormat select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print format $sFormat select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print format $sFormat select property\[SpinnerAgent\] dump] != "")} {
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sFormat)} sMsg
         regsub -all " " $sFormat "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sFormat
         }
         set sDescription [mql print format $sFormat select description dump]
         set bHidden [mql print format $sFormat select hidden dump]
         set sVersion [mql print format $sFormat select version dump]
         set sFileSuffix [mql print format $sFormat select filesuffix dump]
         set sViewCommand [mql print format $sFormat select view dump]
         set sEditCommand [mql print format $sFormat select edit dump]
         set sPrintCommand [mql print format $sFormat select print dump]
   
         set sMime ""
         set sFileCreator ""
         set sFileType ""
         set lsPrint ""
         set lsPrint [split [mql print format $sFormat] \n]
         
         foreach sPrint $lsPrint {
            set sPrint [string trim $sPrint]
            
            if {[string first "type" $sPrint] == 0} {
               regsub "type" $sPrint "" sFileType
               set sFileType [string trim $sFileType]
               set sFileCreator $sFileType
            } elseif {[string first "mime" $sPrint] == 0} {
               regsub "mime" $sPrint "" sMime
               set sMime [string trim $sMime]
            }
         }
         append sFile "$sFormat\t$sOrigName\t$sDescription\t$sVersion\t$sFileSuffix\t$sFileCreator\t$sFileType\t$sViewCommand\t$sEditCommand\t$sPrintCommand\t$sMime\t$bHidden\n"
      }
   }

   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Format data loaded in file $sPath"
}
