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

################################################################################
#                   Business Objects
################################################################################
#*******************************************************************************
# Procedure:   pGet_BOAdmin
#
# Description: print details about the admin type and create spreadsheets
#
# Returns:     None.
#*******************************************************************************
   proc pGet_BOAdmin { sList } {
   
      global sDumpSchemaDirObjects
      
      foreach sList1 $sList {
      
# skip if abstract
         set sAbst [mql print type "$sList1"]
         set i [ regsub "abstract true" $sAbst "abstract true" sCheck ]
         
         if {$i > 0} {
            set sFlag "true"
         } else {
            set sFlag "false"
         }
         	
         if {"$sFlag" == "false" } {
            set sValue1 "$sList1"
            set sValue2 [join $sValue1 _]
            set fname "bo_$sValue2"
            puts "Start backup of Business Object $sList1 ..."
            set p_filename "$sDumpSchemaDirObjects/$fname\.xls"
            set p_file [open $p_filename w+]
            		
#puts $sFName
            		
#
# WRITE HEADER INFO INTO OUTPUT FILE.
#
            set sAttr1  [ mql print type "$sList1" select attribute dump \t ]
            		
            set lBos "Type\tName\tRev\t\t\tPolicy\tState\tVault\tOwner\tdescription\t$sAttr1"
            puts $p_file "$lBos"
            	
            set sCmd "mql temp query bus \"$sList1\" * * select \
            name grant policy current vault owner description attribute.value dump \\t"
            
            if { [ catch { eval $sCmd } sOutstr ] == 0 } {
               puts $p_file "$sOutstr"
               
               file mkdir "$sDumpSchemaDirObjects/Files"
               set lsOutstr [split $sOutstr \n]
               foreach slsOutstr $lsOutstr {
                  set lslsOutstr [split $slsOutstr \t]
                  set sBOType [lindex $lslsOutstr 0]
                  set sBOName [lindex $lslsOutstr 1]
                  set sBORev [lindex $lslsOutstr 2]
                  set lsFile [split [mql print bus "$sBOType" "$sBOName" "$sBORev" select format.file.name dump |] |]
                  set lsFormat [split [mql print bus "$sBOType" "$sBOName" "$sBORev" select format.file.format dump |] |]
                  foreach sFile $lsFile sFormat $lsFormat {
                     mql checkout bus "$sBOType" "$sBOName" "$sBORev" file $sFile "$sDumpSchemaDirObjects/Files"
                     file rename -force "$sDumpSchemaDirObjects/Files/$sFile" "$sDumpSchemaDirObjects/Files/$sBOType~~$sBOName~~$sBORev~~$sFormat~~$sFile"
                  }
               }
            }     
         }
      }
   }
   
#############################################################################
#  Relationships
#############################################################################

   proc pGet_BOAdminRel { sList } {
   
      global sDumpSchemaDirRelationships
      
      foreach sList1 $sList {
      
# skip if abstract
         set sSplitRel [split $sList1 ,]
         set sType     [ string trim [ lindex "$sSplitRel" 0 ] ]
         set sRel      [ string trim [ lindex "$sSplitRel" 1 ] ]
         	
         set sValue1 "$sRel"
         set sValue2 [join $sValue1 _]
         set fname "rel_$sValue2"
         puts "Start backup of Business Object Relation $sRel ..."
         set p_filename "$sDumpSchemaDirRelationships/$fname\.xls"
         set bHeader TRUE
         if {[catch {set sTest $aFile($p_filename)} sMsg] == 0} {
            set p_file [open $p_filename a+]
            set bHeader FALSE
         } else {
            set p_file [open $p_filename w]
            set aFile($p_filename) $p_filename
         }
         set sQuery [ split [ mql temp query bus "$sType" * * select id dump | ] \n ] 
         
         
#
# WRITE HEADER INFO INTO OUTPUT FILE.
#
         if {$bHeader} {
         set sAttr1  [ mql print relationship "$sRel" select attribute dump \t ]
         	
         if { "$sAttr1" == "" } {
            set lBos "FromType\tFromName\tFromRev\tToType\tToName\tToRev\tDirection\tRelationship"
         } else {
            set lBos "FromType\tFromName\tFromRev\tToType\tToName\tToRev\tDirection\tRelationship\t$sAttr1"
         }        	
         
         puts $p_file "$lBos"
         }
         
         foreach sValue $sQuery { 
            regsub -all "\{" $sValue "" sValue1
            regsub -all "\}" $sValue1 "" sType1
            
            set lsLine          [split "$sType1" "|" ] 
            set sFromType       [ string trim [ lindex "$lsLine" 0 ] ]
            set sFromName       [ string trim [ lindex "$lsLine" 1 ] ]
            set sFromRev        [ string trim [ lindex "$lsLine" 2 ] ]
            
            if { "$sAttr1" == "" } {
            set sExpand  [ split [ mql expand bus "$sFromType" "$sFromName" "$sFromRev" relationship "$sRel" dump |  ] \n ]
            
            foreach sExpand1 $sExpand { 
               regsub -all "\{" $sExpand1 "" sExpand2
               regsub -all "\}" $sExpand2 "" sExpand1
               set lsLine2       [split "$sExpand1" "|" ] 
               set sToDir        [ string trim [ lindex "$lsLine2" 2 ] ]
               set sToType       [ string trim [ lindex "$lsLine2" 3 ] ]
               set sToName       [ string trim [ lindex "$lsLine2" 4 ] ]
               set sToRev        [ string trim [ lindex "$lsLine2" 5 ] ]
               if { "$sToDir" != "from" || $sFromType != $sToType  } {
               set lBos "$sFromType\t$sFromName\t$sFromRev\t$sToType\t$sToName\t$sToRev\t$sToDir\t$sRel"
               puts $p_file "$lBos"
            }
         }
                } else {
            set sExpand  [ split [ mql expand bus "$sFromType" "$sFromName" "$sFromRev" relationship "$sRel" select relationship attribute.value dump | ] \n ]
            
            foreach sExpand1 $sExpand { 
            regsub -all "\{" $sExpand1 "" sExpand2
            regsub -all "\}" $sExpand2 "" sExpand1
            set lsLine2       [split "$sExpand1" "|" ] 
            set sToDir        [ string trim [ lindex "$lsLine2" 2 ] ]
            set sToType       [ string trim [ lindex "$lsLine2" 3 ] ]
            set sToName       [ string trim [ lindex "$lsLine2" 4 ] ]
            set sToRev        [ string trim [ lindex "$lsLine2" 5 ] ]
            set A1            [ lrange  "$lsLine2" 6 end ]
            set A3            ""
            				
            foreach A2 $A1 {
               append A3 "\t$A2"
            }
            					
            if { "$sToDir" != "from" || $sFromType != $sToType  } {
               set lBos "$sFromType\t$sFromName\t$sFromRev\t$sToType\t$sToName\t$sToRev\t$sToDir\t$sRel$A3"
               puts $p_file "$lBos"
            }
            }
            }
         }
         close $p_file
      }
   }
   # end of procedures
   set sSpinnerPath [mql get env SPINNERPATHBO]
   
   if {$sSpinnerPath == ""} {
   set sOS [string tolower $tcl_platform(os)];
   set sSuffix [clock format [clock seconds] -format "%Y%m%d"]
   
   if { [string tolower [string range $sOS 0 5]] == "window" } {
   set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix";
   } else {
   set sSpinnerPath "/tmp/SpinnerAgent$sSuffix";
   }
   file mkdir $sSpinnerPath
   }
   
   set sDumpSchemaDirObjects [ file join $sSpinnerPath Objects ]
   file mkdir $sDumpSchemaDirObjects
   set sDumpSchemaDirRelationships [ file join $sSpinnerPath Relationships ]
   file mkdir $sDumpSchemaDirRelationships
   
   set thelist [ list "Company" "Business Unit" "Department" "Region" "Specification Office" "Specification Section" "Specification Template Holder" "Line Sheet" "Grade Template" "Design" "Person" "Part"]
   pGet_BOAdmin $thelist
   
   set thelist [ list "Company,Division" "Company,Organization Specification Office" "Region,Organization Region" "Business Unit,Business Unit Owns" "Business Unit,Member" "Business Unit,Employee" "Department,Company Department" "Region,Region Owns" "Line Sheet,BOS" "Line Sheet,Originating Specification Template" "Design,Originating Specification Template" "Grade Template,Originating Specification Template" "Specification Section,Specification Section" "Specification Office,Assigned To Specification Office" "Specification Template Holder,Specification Template" "Part,Part Specification"]
   pGet_BOAdminRel $thelist
   
   puts "Objects loaded in directory: '$sDumpSchemaDirObjects'\nRelationships loaded in directory: '$sDumpSchemaDirRelationships'"
}
