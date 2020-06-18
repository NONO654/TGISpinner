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
   set sTypeReplace "lattice "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "vault"} {
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
   
   set sSpinnerPath [mql get env SPINNERPATHSYS]
   if {$sSpinnerPath == ""} {
      set sOS [string tolower $tcl_platform(os)];
      set sSuffix [clock format [clock seconds] -format "%Y%m%d"]
      
      if { [string tolower [string range $sOS 0 5]] == "window" } {
         set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix/System";
      } else {
         set sSpinnerPath "/tmp/SpinnerAgent$sSuffix/System";
      }
      file mkdir $sSpinnerPath
   }
   set sMapPath "$sSpinnerPath/Map"
   file mkdir $sMapPath

   set sPath(local) "$sSpinnerPath/vault_local.xls"
   set sPath(remote) "$sSpinnerPath/vault_remote.xls"
   set sPath(foreign) "$sSpinnerPath/vault_foreign.xls"
   set sFile(local) "name\tRegistry Name\tdescription\ttablespace\tindexspace\thidden\ticon\n"
   set sFile(remote) "name\tRegistry Name\tdescription\tserver\thidden\ticon\n"
   set sFile(foreign) "name\tRegistry Name\tdescription\ttablespace\tindexspace\tinterface\tfile\tmap\thidden\ticon\n"
   set sMxVersion [string range [mql version] 0 2]

   set lsVault [split [mql list vault $sFilter] \n]
   foreach sVault $lsVault {
      if {[catch {set sName [mql print vault $sVault select name dump]} sMsg] != 0} {
         puts "ERROR: Problem with retrieving info on vault '$sVault' - Error Msg:\n$sMsg"
         continue
      }
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print vault $sVault select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print vault $sVault select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print vault $sVault select property\[SpinnerAgent\] dump] != "")} {
         foreach sItem [list sDescription sTablespace sIndexspace sInterface sMapFile sHidden sServer] {
            eval "set $sItem \"\""
         }
         
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sVault)} sMsg
         regsub -all " " $sVault "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sVault
         }

         set sDescription [mql print vault $sVault select description dump]
         set sHidden [mql print vault $sVault select hidden dump]
         set sInterface [mql print vault $sVault select interface dump]
         set sMap [mql print vault $sVault select map dump]
         set sServer [mql print vault $sVault select server dump]
         
         if {$sServer != ""} {
            set sType remote
         } elseif {$sInterface != "" || $sMap != ""} {
            set sType foreign
            if {$sMap != ""} {
               set sMapFile "./System/Map/$sName\.map"
               set sFilePath "$sMapPath/$sName\.map"
               set iMapFile [open $sFilePath w]
               puts $iMapFile $sMap
               close $iMapFile
            }
         } else {
            set sType local
         }
         
         if {$sType != "remote"} {
            set lsPrint [split [mql print vault $sVault] \n]
            foreach sItem [list "data tablespace" "index tablespace"] sSpace [list sTablespace sIndexspace] {
               set iList [lsearch -regexp $lsPrint $sItem]
               if {$iList >= 0} {
                  set sResult [string trim [lindex $lsPrint $iList]]
                  regsub $sItem $sResult "" sResult
                  set sResult [string trim $sResult]
                  eval {set $sSpace $sResult}
               }
            }
         }
      }
      switch $sType {
         local {
            append sFile(local) "$sName\t$sOrigName\t$sDescription\t$sTablespace\t$sIndexspace\t$sHidden\n"
         } remote {
            append sFile(remote) "$sName\t$sOrigName\t$sDescription\t$sServer\t$sHidden\n"
         } foreign {
            append sFile(foreign) "$sName\t$sOrigName\t$sDescription\t$sTablespace\t$sIndexspace\t$sInterface\t$sMapFile\t\t$sHidden\n"
         }
      }
   }
   foreach sType [list foreign local remote] {
      set iFile [open $sPath($sType) w]
      puts $iFile $sFile($sType)
      close $iFile
   }
   puts "Vault data loaded in files:\n   $sPath(foreign)\n   $sPath(local)\n   $sPath(remote)"
}
