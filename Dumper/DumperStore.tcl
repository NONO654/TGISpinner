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
   set sTypeReplace "store "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "store"} {
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

   set sPath(captured) "$sSpinnerPath/store_captured.xls"
   set sPath(ingested) "$sSpinnerPath/store_ingested.xls"
   set sPath(tracked) "$sSpinnerPath/store_tracked.xls"
   set sFile(captured) "name\tRegistry Name\tdescription\ttype\tfilename\tpermission\tprotocol\tport\thost\tpath\tuser\tpassword\tlocation\tfcs\thidden\tmultipledirectories\tlock\ticon\n"
   set sFile(ingested) "name\tRegistry Name\tdescription\ttype\ttablespace\tindexspace\thidden\tlock\ticon\n"
   set sFile(tracked) "name\tRegistry Name\tdescription\ttype\thidden\tlock\ticon\n"
   set lsItem(captured) [list sDescription sFilename sMultiDir sLock sPermission sProtocol sUser sHost sPort sStorePath sSearch sFcs sHidden]
   set lsItem(ingested) [list sDescription sLock sHidden sTablespace sIndexspace]
   set lsItem(tracked) [list sDescription sLock sHidden]
   set lsPrintItem(captured) [list description filename multipledirectories locked permission protocol user host port path "search url" "fcs url" hidden]
   set lsPrintItem(ingested) [list description locked hidden "data tablespace" "index tablespace"]
   set lsPrintItem(tracked) [list description locked hidden]
   set sMxVersion [string range [mql version] 0 2]

   set lsStore [split [mql list store $sFilter] \n]
   foreach sStore $lsStore {
      set bPass TRUE
      if {$sMxVersion > 8.9} {
         set sModDate [mql print store $sStore select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
      }
      
      if {$sOrigNameFilter != ""} {
         set sOrigName [mql print store $sStore select property\[original name\].value dump]
         if {[string match $sOrigNameFilter $sOrigName] == 1} {
            set bPass TRUE
         } else {
            set bPass FALSE
         }
      }

      if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print store $sStore select property\[SpinnerAgent\] dump] != "")} {
         foreach sItem [list sDescription sFilename sLock sPermission sProtocol sUser sPassword sHost sPort sStorePath sSearch sFcs sMultiDir sHidden sTablespace sIndexspace] {
            eval "set $sItem \"\""
         }
         
         set sName [mql print store $sStore select name dump]
         set sOrigName ""
         catch {set sOrigName $aSymbolic($sStore)} sMsg
         regsub -all " " $sStore "" sOrigNameTest
         if {$sOrigNameTest == $sOrigName} {
            set sOrigName $sStore
         }
         set sType [mql print store $sStore select type dump]
         if {$sType == "captured"} {set slsLocation [mql print store $sStore select location dump " | "]}
         
         set lsPrint [split [mql print store $sStore] \n]
         foreach sPrintItem $lsPrintItem($sType) sItem $lsItem($sType) {
            set iList [lsearch -regexp $lsPrint $sPrintItem]
            if {$iList >= 0} {
               set sResult [string trim [lindex $lsPrint $iList]]
               if {$sPrintItem != "hidden" && $sPrintItem != "multipledirectories" && $sPrintItem != "locked"} {
                  regsub $sPrintItem $sResult "" sResult
                  set sResult [string trim $sResult]
               }
               eval {set $sItem $sResult}
            }
         }
      }
      switch $sType {
         captured {
            append sFile(captured) "$sName\t$sOrigName\t$sDescription\t$sType\t$sFilename\t$sPermission\t$sProtocol\t$sPort\t$sHost\t$sStorePath\t$sUser\t\t$slsLocation\t$sFcs\t$sHidden\t$sMultiDir\t$sLock\n"
         } ingested {
            append sFile(ingested) "$sName\t$sOrigName\t$sDescription\t$sType\t$sTablespace\t$sIndexspace\t$sHidden\t$sLock\n"
         } tracked {
            append sFile(tracked) "$sName\t$sOrigName\t$sDescription\t$sType\t$sHidden\t$sLock\n"
         }
      }
   }
   foreach sType [list captured ingested tracked] {
      set iFile [open $sPath($sType) w]
      puts $iFile $sFile($sType)
      close $iFile
   }
   puts "Store data loaded in files:\n   $sPath(captured)\n   $sPath(ingested)\n   $sPath(tracked)"
}
