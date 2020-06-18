tcl;

eval {
   if {[info host] == "mostermant43" } {
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
   set sTypeReplace "program "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "program"} {
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

   set sPath "$sSpinnerPath/SpinnerProgramData.xls"
   set sSourceFileDir "$sSpinnerPath/SourceFiles"
   file mkdir $sSourceFileDir
   set lsProgram [split [mql list program $sFilter] \n]
   set sFile "Program Name\tRegistry Name\tDescription\tType (java / mql or \"\" / external)\tExecute (immediate or \"\" / deferred)\tNeeds Bus Obj (boolean)\tDownloadable (boolean)\tPiped (boolean)\tPooled (boolean)\tHidden (boolean)\tUser\tIcon File\n"
#   set sFile "Program Name\tRegistry Name\tDescription\tType (java / mql or \"\" / external)\tExecute (immediate or \"\" / deferred)\tNeeds Bus Obj (boolean)\tDownloadable (boolean)\tPiped (boolean)\tPooled (boolean)\tHidden (boolean)\tUse Interface (boolean)\tMethod (boolean)\tFunction (boolean)\tClassname\tIcon File\n"
   set sMxVersion [string range [mql version] 0 3]

   foreach sProgram $lsProgram {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print program $sProgram select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print program $sProgram select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print program $sProgram select property\[SpinnerAgent\] dump] != "")} {
         if {[mql print program $sProgram select iswizardprogram dump] != "TRUE"} {
            set sName [mql print program $sProgram select name dump]
            set sOrigName ""
            catch {set sOrigName $aSymbolic($sProgram)} sMsg
            regsub -all " " $sProgram "" sOrigNameTest
            if {$sOrigNameTest == $sOrigName} {
               set sOrigName $sProgram
            }
            set sDescription [mql print program $sProgram select description dump]
   
            if {$sMxVersion > 8.9 && [mql print program $sProgram select isjavaprogram dump] == "TRUE"} {
               set sProgType java
            } elseif {[mql print program $sProgram select ismqlprogram dump] == "TRUE"} {
               set sProgType mql
            } else {
               set sProgType external
            }
            
            set sExecute [mql print program $sProgram select execute dump]
            set bNeedBusObj [mql print program $sProgram select doesneedcontext dump]
            set bDownload [mql print program $sProgram select downloadable dump]
#            set bUseInterface "UseIF"
#            set bMethod "METHOD"
#            set bFunction "FUNCTION"
#            set sClassname "CLASSNAME"
            set sUser ""
            if {$sMxVersion >= 10.5} {
               set sUser [mql print program $sProgram select user dump]
#               set bUseInterface [mql print program $sProgram select doesuseinterface dump]
#               set bMethod [mql print program $sProgram select isamethod dump]
#               set bFunction [mql print program $sProgram select isafunction dump]
#               set sClassname [mql print program $sProgram select classname dump]
            }
            set lsProgram [split [mql print program $sProgram] \n]
   
            set bPooled FALSE
            set bPiped FALSE
   
            foreach sProg $lsProgram {
               set sProg [string trim $sProg]
               if {[string first "code" $sProg] == 0} {
                  break
               } elseif {$sProg == "pooled"} {
                  set bPooled TRUE
               } elseif {$sProg == "pipe"} {
                  set bPiped TRUE
               }
            }
   
            set bHidden [mql print program $sProgram select hidden dump]
            append sFile "$sName\t$sOrigName\t$sDescription\t$sProgType\t$sExecute\t$bNeedBusObj\t$bDownload\t$bPiped\t$bPooled\t$bHidden\t$sUser\n"
#            append sFile "$sName\t$sOrigName\t$sDescription\t$sProgType\t$sExecute\t$bNeedBusObj\t$bDownload\t$bPiped\t$bPooled\t$bHidden\t$bUseInterface\t$bMethod\t$bFunction\t$sClassname\n"
            regsub -all "/" $sProgram "SLASH" sProgramFile 
            regsub -all ":" $sProgramFile "COLON" sProgramFile
            regsub -all "\134\174" $sProgramFile "PYPE" sProgramFile
            regsub -all ">" $sProgramFile "GTHAN" sProgramFile
            regsub -all "<" $sProgramFile "LTHAN" sProgramFile

            mql print program $sProgram select code dump output "$sSourceFileDir/$sProgramFile"
   
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "Program data loaded in file $sPath\nSource files loaded in directory $sSourceFileDir"
}