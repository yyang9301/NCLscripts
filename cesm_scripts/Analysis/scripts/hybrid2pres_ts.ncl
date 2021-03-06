load "$NCARG_ROOT/lib/ncarg/nclex/gsun/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

; Convert the files created by Create_Seas_ts.ncl onto pressure levels
; specified in this file

begin

Direc = getenv("NCL_ARG_1")
nexps = toint(getenv("NCL_ARG_2"))
Experiments = new(nexps,"string")
forCasey=toint(getenv("NCL_forCasey"))
version=getenv("NCL_CESMversion")

; default argument if missing
if ismissing(forCasey) then
    forCasey = 0 
end if

ERAlev=toint(getenv("NCL_ERAlev"))

do ne = 0,nexps-1
        Experiments(ne) = getenv("NCL_ARG_" + tostring(3+ne))
end do

if version .EQ. "122" then
    camversion="cam"
else
    camversion="cam2"
end if

startyr = toint(getenv("NCL_startyr"))
endyr = toint(getenv("NCL_endyr"))

nyears = endyr-startyr+1

dirstr = getenv("NCL_dirstr")

timespans = (/"DJF","MAM","JJA","SON","ANN"/)
dimtimes = dimsizes(timespans)
nts = dimtimes(0)

dimsexps = dimsizes(Experiments)
nexps = dimsexps(0)

if ERAlev .eq. 1 then
    print("ERAlev")
    pnew  = (/1,2,3,5,7, 10,20,30,50,70,100,125,150,175,200,225,250,300 \
         , 350,400,450,500,550,600,650,700,750,775,800,825,850,875,900,925,950,975,1000 /)
else
    pnew  = (/1000,925,850,775,750,600,500,400,300,250,200,150,100, \
            50,30,25,10,7.5,5,3,2,1,0.75,0.5,0.3,0.2, \
            0.1,0.075,0.05,0.03,0.02,0.01,0.0075,0.005,0.0003,0.0002,0.0001 /)
end if

cp = 1.00464e3
Rd = 287.0
kappa = (Rd/cp)

do exps = 0,nexps-1

    do ts = 0,nts - 1

        timespan = timespans(ts)
        Experiment = Experiments(exps)
        Dir = (Direc + Experiment + "/" + dirstr + "/")

        print(Experiment)

        if (forCasey .eq. 1) then
            filename = (Dir + timespan + "UVTWO3_" + tostring(startyr) + "_" + tostring(nyears) + "_ts_" + Experiment + "." + camversion + ".h0.nc")
        else
            filename = (Dir + timespan + tostring(startyr) + "_" + tostring(nyears) + "_ts_" + Experiment + "." + camversion + ".h0.nc")
        end if

        cdf_file = addfile(filename,"r")

        lat = cdf_file->lat
        lon = cdf_file->lon
        P0mb = 0.01*cdf_file->P0
        
        T = cdf_file->T
        PHIS = cdf_file->PHIS
        
        levs = cdf_file->lev
        nlevs = dimsizes(levs)
        print(nlevs)

        if levs(0) .GT. levs(nlevs-1) then
            TBOT = T(:,0,:,:)
        else
            TBOT = T(:,nlevs-1,:,:)
        end if

        hyam = cdf_file->hyam
        hybm = cdf_file->hybm
        PS = cdf_file->PS

        if (forCasey .eq. 1) then
            Wpres = vinth2p_ecmwf(cdf_file->OMEGA,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS)
            O3pres = vinth2p_ecmwf(cdf_file->O3,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS)
            Tpres = vinth2p_ecmwf(cdf_file->T,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TBOT,PHIS)
            Upres = vinth2p_ecmwf(cdf_file->U,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS)
            Vpres = vinth2p_ecmwf(cdf_file->V,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS)
        else

            Tpres = vinth2p_ecmwf(T,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TBOT,PHIS)
            Upres = vinth2p_ecmwf(cdf_file->U,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS) 
            Vpres = vinth2p_ecmwf(cdf_file->V,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS) 
            Z3pres = vinth2p_ecmwf(cdf_file->Z3,hyam,hybm,pnew,PS,1,P0mb,1,True,-1,TBOT,PHIS) 
            Qpres = vinth2p_ecmwf(cdf_file->Q,hyam,hybm,pnew,PS,1,P0mb,1,True,0,TBOT,PHIS) 


            ; Calculate Potential temperature
            TH = Tpres * (conform(Tpres,pnew,1)/1000.0)^(-1.0 * kappa)
            copy_VarCoords(Tpres,TH)
    
        end if


    ;-----------------------------------------------------------------------
    ;Write variables to a new netcdf file, for stat fits in matlab
    ;-----------------------------------------------------------------------
        ; allow large files
        setfileoption("nc","Format","LargeFile")
        
        if (forCasey .eq. 1) then
            filo = timespan + "UVTWO3_" + tostring(startyr) + "_" + tostring(nyears) + "_ts_Xpl_" + Experiment + "." + camversion + ".h0.nc"
        else
            if ERAlev .eq. 1 then
                filo = timespan + tostring(startyr) + "_" + tostring(nyears) + "_ts_ERAIpl_" + Experiment + "." + camversion + ".h0.nc"
            else
                filo = timespan + tostring(startyr) + "_" + tostring(nyears) + "_ts_Xpl_" + Experiment + "." + camversion + ".h0.nc" 
            end if
        end if
        
        system("/bin/rm -f " + Dir + filo)
        fout = addfile(Dir + filo, "c")

        setfileoption(fout,"DefineMode",True)
        setfileoption(fout,"Format","LargeFile")

    ; set attributes of output file
        fAtt = True
        fAtt@creation_date = systemfunc("date")
        fAtt@history = "created by hybrid2pres_ts.ncl" 
        fileattdef(fout,fAtt)

        if (forCasey .eq. 1) then
            fout ->U      = Upres
            fout ->V      = Vpres
            fout ->T      = Tpres
            fout ->OMEGA  = Wpres
            fout ->O3     = O3pres
        else

            fout ->U      = Upres
            fout ->V      = Vpres
            fout ->TH     = TH
            fout ->Z3     = Z3pres
            fout ->Q      = Qpres
        end if

        delete(Experiment)
        delete([/lat,lon,P0mb,T,hyam,hybm,PS,PHIS,levs,TBOT/])
        delete(filename)
        if (forCasey .eq. 1) then
            delete([/Upres,Vpres,Tpres,Wpres,O3pres/])
        else
            delete([/Tpres,Upres,Vpres,Qpres,Z3pres/])
        end if
    end do
end do


end
