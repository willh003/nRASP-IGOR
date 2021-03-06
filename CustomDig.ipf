#Ifdef ARrtGlobals
#pragma rtGlobals=1        // Use modern global access method.
#else
#pragma rtGlobals=3        // Use strict wave reference mode
#endif 
#include ":AsylumResearch:Code3D:Initialization"
#include ":AsylumResearch:Code3D:MotorControl"
#include ":AsylumResearch:Code3D:Environ"

Override Function/S LithoDriveDAC(TipParms)
        Struct ARTipHolderParms &TipParms


        return "$HeightLoop.Setpoint"
End //

Menu "Macros" // Put panel in Macros menu
	"nanoRASP Panel", NanoRASP_Panel()
End

Function NanoRASP_Panel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(12,65,461,249) as "NanoRASP Panel"
	ModifyPanel cbRGB=(65534,65534,65534)
	SetDrawLayer UserBack
	DFREF dfr = GetPackageDFREF()
	//DrawPICT 320,110,0.543379,0.477941,g998_png
	Button bLoad,pos={55,142},size={100,20},proc=LoadExcelButton,title="Load Excel Data"
	SetVariable vmax,pos={287,12},size={120,18},title="vmax",font="Arial"
	SetVariable vmax,value= dfr:VMAX
	SetVariable vsp,pos={164,12},size={120,18},title="vsp"
	SetVariable vsp,help={"Setpoint voltage (applied when difference=0)"}
	SetVariable vsp,font="Arial"
	SetVariable vsp,value=dfr:VSP
	SetVariable vthreshold,pos={36,14},size={120,18},title="vthreshold",font="Arial"
	SetVariable vthreshold,value= dfr:VTHRESHOLD
	SetVariable kval,pos={291,46},size={137,18},title="kval",font="Arial"
	SetVariable kval,value= dfr:KVAL
	SetVariable dfchannel,pos={29,48},size={130,18},title="deflection channel"
	SetVariable dfchannel,font="Arial"
	SetVariable dfchannel,value= dfr:DFCHANNEL
	SetVariable htchannel,pos={169,47},size={113,18},title="height channel"
	SetVariable htchannel,font="Arial"
	SetVariable htchannel,value= dfr:HTCHANNEL
	SetVariable xslope,pos={12,79},size={141,18},title="surface x slope"
	SetVariable xslope,font="Arial"
	SetVariable xslope,value=dfr:XSLOPE
	SetVariable yslope,pos={158,78},size={137,18},title="surface y slope"
	SetVariable yslope,font="Arial"
	SetVariable yslope,value=dfr:YSLOPE
	SetVariable offset,pos={303,78},size={133,18},title="surface offset"
	SetVariable offset,font="Arial"
	SetVariable offset,value=dfr:OFFSET
	SetVariable img_num,pos={26,108},size={120,18},font="Arial"
	SetVariable img_num,value=dfr:img_num
	SetVariable digmax,size={120,18},font="Arial"
	SetVariable digmax,value=dfr:DIGMAX
	CheckBox IncludeDef,pos={157,110},size={147,14},title="Check to include deflection"
	CheckBox IncludeDef,value= 0
	Button bExp,pos={166,142},size={100,20},proc=ResetExpButton,title="Reset Experiment",help={"Reset the experiment"}
End

Function GetInfoPanel() // Checks whether to include deflection
	ControlInfo/W=TestPanel IncludeDef
	If(V_Value==0)
		NVAR KVAL = root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals':KVAL
		KVAL = 0
	endif
End

Function ResetExpButton(ba) : ButtonControl // Handles Reset Experiment queries
	STRUCT WMButtonAction &ba
	switch(ba.eventCode)
		case 2: // Mouse up
			if (CmpStr(ba.ctrlName,"bExp") == 0)
				ResetExp()
			endif
		break
	endswitch
	return 0
End

Function LoadExcelButton(ba) : ButtonControl // Handles Load Excel sheet queries
	STRUCT WMButtonAction &ba
	switch(ba.eventCode)
		case 2: // Mouse up
			if (CmpStr(ba.ctrlName,"bLoad") == 0)
				FlipExcel("","","","A1","IV256")
			endif
		break
	endswitch
	return 0
End

// CreatePackageData(), GetPackageDFREF() allow this to be ported to any computer without other setup (so just copy/paste code to dads computer)
// Handles folder creation for global variables
Function/DF CreatePackageData() // Called only from GetPackageDFREF
	// Create the package data folder
	NewDataFolder/O root:packages:MFP3D:XPT:Cypher:GlobalVars
	NewDataFolder/O root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals'
	// Create a data folder reference variable
	DFREF dfr = root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals'
	// Create and initialize globals
	Variable/G dfr:DIGMAX= 10
	Variable/G dfr:VTHRESHOLD = 4
	Variable/G dfr:VMAX = 15
	Variable/G dfr:VSP = 3
	Variable/G dfr:KVAL = .5
	Variable/G dfr:DFCHANNEL = 1
	Variable/G dfr:HTCHANNEL = 0
	Variable/G dfr:XSLOPE = .005
	Variable/G dfr:YSLOPE = .005
	Variable/G dfr:OFFSET = .01
	Variable/G dfr:img_num = 0
	Variable/G dfr:should_we_finish = 0
	return dfr
End

Function/DF GetPackageDFREF()
	DFREF dfr = root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals'
	if (DataFolderRefStatus(dfr) != 1) // Data folder does not exist?
		DFREF dfr = CreatePackageData() // Create package data folder
	endif
	return dfr
End

Function/WAVE GetForce(trgt) // Returns lith_force wave to be inputted through SendInNewLithoImage
	WAVE trgt
	Redimension/N=(-1,-1) trgt // Take away all layers from target except first. Not necessary but prevents bugs
	GetInfoPanel() // Check if deflection should be included

	// Globals
	DFREF dfr = root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals' // THIS STAYS -- path of global variables is constant (created in funcs above)
	NVAR DIGMAX = dfr:DIGMAX
	NVAR VTHRESHOLD = dfr:VTHRESHOLD
	NVAR VMAX = dfr:VMAX
	NVAR VSP = dfr:VSP
	NVAR KVAL = dfr:KVAL
	NVAR DFCHANNEL = dfr:DFCHANNEL
	NVAR HTCHANNEL = dfr:HTCHANNEL
	NVAR XSLOPE = dfr:XSLOPE
	NVAR YSLOPE = dfr:YSLOPE
	NVAR OFFSET = dfr:OFFSET
	
	// Make local waves for math ops
	Make/O/N = (256, 256) lith_force // RETURNED WAVE
	Make/Free/N = (256,256) mzideal
	Make/Free/N = (256, 256) lith_current_all
	Make/Free/N = (256, 256) lith_ht
	Make/Free/N = (256, 256) lith_defl
	Make/Free/N = (256,256) vdifference
	Make/Free/N = (256, 256) vscaled
	Make/Free/N = (256,256) htscaled
	
	// Load current wave
	String filename = GetFilename() // Filename in format base_namexxxx, where base_name is specified in master panel and xxxx starts at 0000	
	WAVE/T folderwave = root:packages:MFP3D:Main:Strings:'GlobalStrings'
	Duplicate/O/T/R=(18,18)(0,0)  folderwave, indexwave
	String indexstring = indexwave
	NewPath/O folderpath, indexstring  // folderpath is the symbolic path to the data folder specified in the master pannel
	LoadWave/M/O/B="C=256, N=current1;"/P=folderpath, filename //This should be final call for loading the file
	
	// Copy loaded wave to 'current'
	Duplicate/O/WAVE $filename, $"lith_current_all" // $ is necessary because of how IGOR loops/duplicates stuff
	lith_ht[][] = lith_current_all[x][y][HTCHANNEL]
	lith_defl[][] = lith_current_all[x][y][DFCHANNEL]
	//lith_ht += 540e-09 // Adjust for varying initial heights due to tip approach
	
	// Scale the current wave to a slope. Change middle value to global to set the scale eventually
	WAVE mi = IndexScale("mi", 5, 1)  
	WAVE mj = IndexScale("mj", 5, 0)
	mzideal = mi * XSLOPE + mj * YSLOPE + OFFSET 		// Ideal slope of plane
	htscaled = lith_ht - mzideal  + (KVAL * lith_defl)			// Compare to actual slope to get scaled height 
	Duplicate/Free htscaled, min_htscaled
	Redimension/N=(65536) min_htscaled
	Variable minoffset = WaveMin(min_htscaled) 			// Minimum necessary so all heights are above 0
	
	// Math
	Variable vslope =  (10 ^ 9) * (VMAX - VTHRESHOLD) / DIGMAX 
	vdifference = htscaled - trgt - minoffset
	vscaled = (vdifference * vslope) + VTHRESHOLD
	lith_force = ( (vdifference > 0) * (vscaled < VMAX) * ( vscaled ) ) + ( VMAX * (vscaled > VMAX) ) + ( (vdifference < 0) * VSP )
	//		If pos difference && not too big, this stays			If diff too big, this stays		If diff neg, this stays (adds offset)
		
	KillWaves $filename	// Prevent clutter with global waves and 100s of imgs
	return lith_force 
End 	// GetForce()

Function InitCustomScan() 
	// Sends wave from GetForce(), initializes scan
	// Input this into ImageScanFinish User Callback, then call it from the command line to start experiment
	// TODO: setscale x to value from Scan Size in master pannel, figure out how to do y with width:height
	WAVE trgt
	WAVE lith_force = GetForce(trgt)
	
	//SetScale/I x 0, 5,"um", lith_force
	//SetScale/I y 0, 5,"um", lith_force
	//Display 
		//AppendImage lith_force
		//ModifyImage lith_force ctab = {*,*, Grays256, 1} 
		
	NVAR should_we_finish = root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals':should_we_finish // find a time to set this to true
	if (should_we_finish==200)
		ARCheckFunc("ARUserCallbackMasterCheck_1", 0)
	else
		SendInNewLithoImage(lith_force)
		should_we_finish += 1
		print("Image # " + num2str(should_we_finish))
		InitVelocityScan("VelocityDoDownScanButton_3")
	endif 
End		//InitCustomScan()

Function ResetExp()
	DFREF dfr = root:Packages:MFP3D:GlobalVars:'My Globals'
	NVAR should_we_finish = dfr:should_we_finish
	should_we_finish = 0
End

Function/T GetFilename() // Returns name of current image file for access by GetForce()
// TODO: get format_num from master pannel instead of img_num. Base Name + last 4 digits, same format as AFM files will be
	NVAR img_num = root:packages:MFP3D:XPT:Cypher:GlobalVars:'My Globals':img_num
	SVAR base_name = root:packages:MFP3D:Main:Variables:BaseName // base_name from Base Name in Master Panel
	String format_num
	sprintf format_num "%04d", img_num // Formats to 0000 digits
	String filename = base_name + format_num // func that makes a higher number at the end each time
	Printf "filename: %s\r", filename
	img_num += 1
	return filename
End

Function FlipExcel(pathName, fileName, worksheetName, startCell, endCell) // Do this only once before starting scan to load excel wave into experiment
	// Common Function Call: FlipExcel("G:Igor Custom Procs:Hsquared:Code", "new Comparison AFM", "nmTarget", "A1", "IV256")
    	String pathName                     // Name of Igor symbolic path or "" to get dialog
    	String fileName                         // Name of file to load or "" to get dialog
    	String worksheetName
    	String startCell                            // e.g., "B1"
    	String endCell                          // e.g., "J100"
    	String finalWave = "trgt"			// Name of the wave that will contain the info in igor memory
    	if ((strlen(pathName)==0) || (strlen(fileName)==0))
        	// Display dialog looking for file.
        	Variable refNum
        	String filters = "Excel Files (*.xls,*.xlsx,*.xlsm):.xls,.xlsx,.xlsm;"
        	filters += "All Files:.*;"
        	Open/D/R/P=$pathName /F=filters refNum as fileName
        	fileName = S_fileName               // S_fileName is set by Open/D
        	if (strlen(fileName) == 0)          // User cancelled?
            		return -2
        	endif
    	endif

    // Load row 1 into numeric waves
    	XLLoadWave/S=worksheetName/R=($startCell,$endCell)/COLT="N"/O/V=0/K=0/Q fileName
    	if (V_flag == 0)
        	return -1           // User cancelled
    	endif

    	String names = S_waveNames          // S_waveNames is created by XLLoadWave
    	//String nameOut = UniqueName(finalWave, 1, 0)
    	Concatenate/KILL/O names, $finalWave    // Create matrix and kill 1D waves
   	MatrixTranspose $finalWave
	Reverse/DIM=1/P $finalWave
    	Printf "Created numeric matrix wave %s containing cells %s to %s in worksheet \"%s\"\r", finalWave, startCell, endCell, worksheetName

    	return 0            // Success
End

Function/WAVE IndexScale(name, range, direction) //set direction 0 for y, 1 for x
	String name
	Variable range
	Variable direction
	
	Make/O/N=(256,256) $name
	WAVE waveref = $name
	
	Variable i
	Variable j
	if (direction == 0)
		for(i=0; i < 256; i+=1)
			for(j=0; j < 256; j+=1)
				waveref[i][j] = (i / 256) * range * 10^-6
			endfor
		endfor
	else 
		for(i=0; i < 256; i+=1)
			for(j=0; j < 256; j+=1)
				waveref[j][i] = (i / 256) * range * 10^-6
			endfor
		endfor
	endif
	
	return waveref
End


StartMeUp()


