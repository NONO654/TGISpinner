rem script produced by www.top-gun.cn
Set objArgs = WScript.Arguments
Set WshShell = CreateObject("Wscript.Shell")  

bootstrap = "matrix-r.TGICentral"

For I = 0 to objArgs.Count - 1
   jpoNameWithPath = objArgs(I)
   
   jpofileName =  StrReverse(split(StrReverse(jpoNameWithPath),"\",2)(0))
   
   if right(jpofileName,5) = ".java" then
		 Set wExec = WshShell.Exec ("mql -b " &  bootstrap & " -c ""set context user creator;insert prog '" & jpoNameWithPath & "';compile prog " & replace(jpofileName,"_mxJPO.java","") & " force update;""" )
		 
		 wExec.StdOut.ReadAll 
		returnValue = wExec.StdErr.ReadAll
		
		if instr(returnValue,"Compile error")=0 then
			returnValue = "OK"
		end if
			
		msgbox jpofileName + ":" + returnValue
   else
   
		 Set wExec =  WshShell.Exec ("mql -b " &  bootstrap & " -c ""set context user creator;mod prog " & jpofileName & " file '" & jpoNameWithPath & "';compile prog " & replace(jpofileName,".java","") & " force update;""")
		 
		wExec.StdOut.ReadAll 
		returnValue = wExec.StdErr.ReadAll
		
		if instr(returnValue,"Compile error")=0 then
			returnValue = "OK"
		end if
		msgbox jpofileName + ":" + returnValue
		
   end if
   
	
   
   
Next

