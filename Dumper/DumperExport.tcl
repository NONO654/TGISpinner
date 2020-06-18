tcl;

eval {

   set sOS [string tolower $tcl_platform(os)];
   set sSuffix [clock format [clock seconds] -format "%Y%m%d"]
   
   if { [string tolower [string range $sOS 0 5]] == "window" } {
      set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix/Export";
   } else {
      set sSpinnerPath "/tmp/SpinnerAgent$sSuffix/Export";
   }

   set lsPrimitive [list person form wizard]

   foreach sPrimitive $lsPrimitive {
      set sPrimExport $sPrimitive
      if {$sPrimitive == "wizard"} {set sPrimExport program}
      set sPrimitivePath "$sSpinnerPath/$sPrimitive"
      file mkdir $sPrimitivePath
      set lsName [split [mql list $sPrimitive] \n]
      
      foreach sName $lsName {
         set sNameExport $sName
         if {[string first "/" $sName] >= 0} {
            regsub -all "/" $sName "_SLASH_" sNameExport
         }
         mql export $sPrimExport $sName !mail into file "$sPrimitivePath/$sNameExport.exp"
      }
   }
}      