proc pContinue {lsList} {
   set bFirst TRUE
   set slsList ""
   set lslsList ""
   foreach sList $lsList {
      if {$bFirst} {
         set slsList $sList
         set bFirst FALSE
      } else {
         append slsList " | $sList"
         if {[string length $slsList] > 6400} {
            lappend lslsList $slsList
            set slsList ""
            set bFirst TRUE
         }
      }
   }
   if {$slsList != ""} {
      lappend lslsList $slsList
   }
   return $lslsList
}
