tcl;

eval {

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
            }

            close $p_file
        }
    }
}

#############################################################################
#  Relationships
#############################################################################

################################################################################
#
#   Parameters :
#   Return     :
#
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
		set p_file [open $p_filename w+]
		
        set sQuery [ split [ mql temp query bus "$sType" * * select id dump | ] \n ] 

	
		#
		# WRITE HEADER INFO INTO OUTPUT FILE.
		#
		set sAttr1  [ mql print relationship "$sRel" select attribute dump \t ]
		
        if { "$sAttr1" == "" } {
            set lBos "FromType\tFromName\tFromRev\tToType\tToName\tToRev\tDirection\tRelationship"
        } else {
            set lBos "FromType\tFromName\tFromRev\tToType\tToName\tToRev\tDirection\tRelationship\t$sAttr1"
        }        	

        puts $p_file "$lBos"
	
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
		            if { "$sToDir" == "to" } {
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
						
		            if { "$sToDir" == "to" } {
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
    
    set thelist [ list "Business Unit" "Company" "eService Number Generator" "eService Object Generator" "eService Trigger Program Parameters" "Person" "Route" "Route Task User" "Route Template" "Financial Benefit Category" "Financial Cost Category" "Issue Category" "Issue Classification" "Region" "Specification Office" "Specification Section" "Specification Template Holder"]
    pGet_BOAdmin $thelist

    set thelist [ list "Business Unit,Organization Region" "eService Object Generator,eService Number Generator" "eService Object Generator,eService Additional Object" "Company,Employee" "Company,Employee Representative" "Company,Organization Representative" "Company,Member" "Company,Company Financial Categories" "Business Unit,Organization Representative" "Company,Division" "Company,Company Department" "Company,Route Templates" "Company,Design Responsibility" "Business Unit,Design Responsibility" "Route,Route Node" "Route Template,Route Node" "Financial Benefit Category,Financial Sub Categories" "Financial Cost Category,Financial Sub Categories" "Issue Category,Issue Category Classification" "Specification Office,Supported Organization"]
    pGet_BOAdminRel $thelist
    

}
