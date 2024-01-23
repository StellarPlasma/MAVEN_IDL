PRO MAVEN_DATA_TPLOT, TRANGE=TRANGE, DATA_DIR=DATA_DIR,  KEY_PARAM=KEY_PARAM, CREATEALL=CREATEALL,$
                                    SPICE=SPICE, MAG=MAG, SWEA=SWEA, SWIA=SWIA, NGIMS=NGIMS, LANPW=LANPW, LPW_LIST=LPW_LIST, $
                                    STATIC=STATIC, DEN=DEN, IVEL=IVEL, APID=APID, TEMP=TEMP, T_SMOOTH=T_SMOOTH, TS_LEVEL=TS_LEVEL, $
                                    SAVE=SAVE, RESTORE=RESTORE, FILENAME=FILENAME, NO_SERVER = NO_SERVER, $
                                    NO_DELETE=NO_DELETE, PLOT=PLOT, _EXTRA=_EXTRA

;+
; PURPOSE:
;   Download maven data and generate tplot variables (tvars) 
; CALLING SEQUENCE:
;   1.Fetch MAVEN data from "d:/data" and generate MAG & SWEA associated tvars:
;       MAVEN_DATA_TPLOT, TRANGE = ['2015-01-01/00:00:00', '2015-01-01/00:30:00'], data_dir='d:/data', /mag, /swea
;   2.Generate MAG KP tvars:  
;       MAVEN_DATA_TPLOT, TRANGE = ['2015-01-01/00:00:00', '2015-01-01/00:30:00'], /key_param, /mag
;   3.Read STATIC data and calculate density and ions velocities:
;       MAVEN_DATA_TPLOT, TRANGE = ['2015-01-01/00:00:00', '2015-01-01/00:30:00'], /static, /den, /ivel
;   4. Read MAG non-KP data:
;       MAVEN_DATA_TPLOT, TRANGE = ['2015-01-01/00:00:00', '2015-01-01/00:30:00'], /mag
; INPUT:
;   TRANGE: time range to search & load data, and to generate tvars
;   [DATA_DIR]: optional, user-defined data directory. 
;               If not set, the default data directory defined in root_data_dir.pro will be used.
;   [FILENAME]: optional, used with the 'save' keyword to save tplot vars to local storage with the specified filename.
;               if not defined, tvars will be saved with the default filename.
; KEYWORDS:
;   Key_Param: MAVEN key parameter data
;        additional keywords from MVN_KP_TPLOT_SC are also accepted
;   SPICE: S/C's location data
;   MAG: MAVEN magnetometer data
;   SWEI: MAVEN Solar Wind Electron Analyzer data
;   SWAI: MAVEN Solar Wind Ion Analyzer data
;   STATIC: MAVEN SuperThermal and Thermal Ion Composition data
;         sub_keywords (can only be used when "/static" is set): 
;                  DEN -- ion density
;                  IVEL-- generate ion bulk velocity and vector velocity tplot variables
;                  APID-- apid used for loading data to calculate velocity, can either be 'd0' or 'cf'
;                         default apid is 'd0', high-resolution data 'd1' or 'cf' may introduce unexpected data disturbances
;                  TEMP-- load temperature data
;                  TEMP_SMOOTH and TS_LEVEL -- apply smooth to temperature data to provide continuous temperature outputs with function "tsmooth2.pro"
;                                              as a reference, ts_level is 30 in "mvn_sta_l0_crib.pro"
;   LPW： MAVEN Langmuir Probe and Waves data
;         sub_keywords (can only be used when "/kpw" is set): 
;                   LPW_LIST: LPW data products list given in "mvn_lpw_load_l2.pro"
;   SAVE: Save tplot vars to local storage, with user-defined filename or with default filename
;   NO_DELETE: Don't delete old tplot vars, this is used to keep multiple tplot vars. Default is off. **USE IT CAREFULLY**
;   NO_SERVER: Don't check for remote files' updates on the server, temporarily use only the local data. This will speed up the 
;              searching and processing of data files, especially on poor web-connection conditions.
;              Please make sure that you have all the needed data downloaded already.
; OUTPUTS: tplot variables according to the keywords provided
; 
;
; CREATED BY: YDYE@MUST， 20190812
; LAST UPDATE: 20240123
; -  

; Preparations
IF ~keyword_set(no_delete) THEN BEGIN
del_data, '*' ; delete old tplot variables in the memory
ENDIF

; Provide time range for search and download data
t_beg = trange[0]
t_end = trange[1]
timespan, trange

IF keyword_set(no_server) THEN BEGIN
  mvn_spice_load, /no_download ; load all spice kernels for coordinates transformation
ENDIF ELSE BEGIN
  mvn_spice_load, /download
ENDELSE
; Set data directory path, which will be passed to "ROOT_DATA_DIR" keyword. 'data_dir' should be a string
IF keyword_set(data_dir) THEN BEGIN
  mvn_spice_load, /no_download
  setenv,'ROOT_DATA_DIR='+data_dir
ENDIF

; Save tplot variables to local disk
IF ~keyword_set(filename) THEN BEGIN
  tdate=time_string(time_double(t_beg),tformat='YYYYMMDD_hh') 
  file_path = 'C:\Users\ydye\OneDrive\Lab\Cross_IDL\tplot_data\maven\'
  filename = file_path + tdate + '_maven_data_tplot'
ENDIF

; Restore saved tplot variables
IF keyword_set(restore) THEN BEGIN
   tplot_restore, filenames = filename+'.tplot'
   return
ENDIF

IF keyword_set(no_server) THEN BEGIN
   help,/structure, mvn_file_source(no_server=1,/set)
   print, 'Data source has been changed to local-only'
ENDIF

;=========================================Key Parameters=========================================
IF keyword_set(key_param) THEN BEGIN
  ; ***When first use, please run "mvn_kp_download_files, /only_update_prefs" first to set ROOT_DATA_DIR***
  ; Load MAVEN kp (Key Parameter)data.
  ; KP data can be devided into IUVS data and In-situ data.
  ; In-situ data include LPW, NGIMS, MAG, SEP, STATIC, SWEA, SWIA Data,
  ;         Spacecraft ‘ephemeris’ and orientation, Time oriented data: 4/8 second cadence.
  ; IUVS data include Periapse Limb Scans, Apoapse Imaging, Coronal Scans,
  ;         Stellar Occultation Observation Modes, Observation oriented data.
  ; KP files are stored daily and need to be downloaded by day
  
  IF keyword_set(no_server) THEN BEGIN
    trange = time_string(trange)
    my_mvn_kp_read, trange, insitu, /exclude_template_files
  ENDIF ELSE BEGIN
    trange = time_string(trange)
    mvn_kp_read, trange, insitu, /new_files;, /exclude_template_files ;use "new_files" keyword to download new/missing data
  ENDELSE
  
  mvn_kp_tplot_sc, insitu, euv=euv, lpw=lpw, static=static, swea=swea, swia=swia, mag=mag, sep=sep, $
                   ngims=ngims, spice=spice, createall=createall, _EXTRA=_EXTRA
  ; Rename original tplot variables for clear recognitions
  ; To check all tplot variable in the system memory, use "tplot_names"
  IF keyword_set(spice) OR keyword_set(createall) THEN BEGIN
      tplot_rename, 'MVN_KP_SPACECRAFT:MSO_X', 'p_mso_x'
      tplot_rename, 'MVN_KP_SPACECRAFT:MSO_Y', 'p_mso_y'
      tplot_rename, 'MVN_KP_SPACECRAFT:MSO_Z', 'p_mso_z'
      join_vec, ['p_mso_x', 'p_mso_y', 'p_mso_z'], 'p_mso'
    
      radius=3397.0
      calc, '"p_mso_r" = "p_mso"/radius' ; change unit to per radius of Mars
    
      tplot_rename, 'MVN_KP_SPACECRAFT:SZA', 'sza'
      tplot_rename, 'MVN_KP_SPACECRAFT:SUB_SC_LONGITUDE', 'lon'
      tplot_rename, 'MVN_KP_SPACECRAFT:SUB_SC_LATITUDE', 'lat'
      tplot_rename, 'MVN_KP_SPACECRAFT:ALTITUDE', 'alt'
  ENDIF
  
  IF keyword_set(swia) OR keyword_set(createall) THEN BEGIN 
      tplot_rename, 'MVN_KP_SWIA:HPLUS_FLOW_VELOCITY_MSO_X', 'v_mso_x'
      tplot_rename, 'MVN_KP_SWIA:HPLUS_FLOW_VELOCITY_MSO_Y', 'v_mso_y'
      tplot_rename, 'MVN_KP_SWIA:HPLUS_FLOW_VELOCITY_MSO_Z', 'v_mso_z'
      join_vec, ['v_mso_x','v_mso_y','v_mso_z'],'v_mso'
      tvectot,'v_mso',tot='v_tot'
      
      tplot_rename, 'MVN_KP_SWIA:HPLUS_TEMPERATURE', 'h+_temp'
      tplot_rename, 'MVN_KP_SWIA:HPLUS_DENSITY', 'den_h+_swia_kp'
  ENDIF
  
  ; Save KP tvars
  IF keyword_set(save) THEN BEGIN
    ; Todo:*****needs further updates to automatically define file names*****
    tvars = tnames()
    tplot_save, tvars, filename = filename
  ENDIF
  
  RETURN

ENDIF
;============================================================================================

;======================================Orbit Infomations=====================================
IF keyword_set(spice) THEN BEGIN
; Load MAVEN S/C location data
; MAVEN's orbit: 75 deg inclination, 4.5 h period, periapsis altitude 140-170 km
  
  my_maven_orbit_tplot, /loadonly
  scale = 3397.0 ; Mars' radius in km, used to scale S/C position
  spice_position_to_tplot,'MAVEN','MARS',frame='MSO',res=4d,scale=scale,name=n1 
  ; Time resolution is set to be 4 sec. Change "res" to set other resolutions 
  
  tplot_rename, 'MAVEN_POS_(MARS-MSO)', 'p_mso'
  split_vec, 'p_mso'
ENDIF
;===========================================================================================

;=========================================MAVEN/MAG=========================================
IF keyword_set(mag) THEN BEGIN
; Load maven/mag (magnetometer) data
  mvn_mag_load, trange=trange
  mvn_mag_geom
  get_data,'mvn_B_1sec_maven_mso',data=d,dlimits=dl
  cotrans_set_coord, dl, 'MSO' ; any string is OK, or minvar_matrix_make will give error on 'data_att' when apply MVA
  store_data,'mvn_B_1sec_maven_mso',data=d,dlimits=dl
  tplot_rename, 'mvn_B_1sec_maven_mso', 'b_mso'
  tvectot, 'b_mso', tot='b_tot'
  split_vec, 'b_mso'
ENDIF
;===========================================================================================

;=========================================MAVEN/SWEA========================================
IF keyword_set(swea) THEN BEGIN
; Load maven/swea (Solar Wind Electron Analyzer) data
; todo: introduce mvn_swe_load_l2 keywords
  mvn_swe_load_l2, trange, /all ; keyword "spec" is for spectrum data
  mvn_swe_sciplot, /loadonly, /sc_pot, /sun
  tplot_rename, 'swe_a4', 'eflux_E' ; electron's flux
ENDIF

;===========================================================================================

;=========================================MAVEN/SWIA========================================
IF keyword_set(swia) THEN BEGIN
; Load maven/swia (Solar Wind Ion Analyzer) data
; For more info, check mvn_swia_crib.pro
  mvn_swia_load_l2_data, trange=trange, /loadall, /tplot, /eflux,  _extra=_extra
  tplot_rename, 'mvn_swis_en_eflux', 'eflux_i'
ENDIF
;===========================================================================================

;=======================================MAVEN/STATIC========================================
IF keyword_set(static) THEN BEGIN
; Load maven/static (SuperThermal and Thermal Ion Composition)data
  
; Usually, loading STATIC APIDs 'c0','c6','ca' and 'd0' is enough
; Most useful science data products are C0, C6, C8, CA, CC, CE, D0, and D4
; CC, CE, D0, and D2 are high dimensional survey data products
; Notes for tplot names: E is for Energy, M is for Mass, D is for Deflection, A is for Anode. For example, 32E means this variable contains 32 energy channels 
; For reference, check "MAVEN SupraThermal and Thermal Ion Compostion (STATIC) Instrument." Space Science Reviews 195(1-4): 199-256.
;If you want to save common blocks in the sta_load procedure, using my_mvn_sta_l2_load instead
  
  IF keyword_set(den) THEN BEGIN
      ; Use get_4dt to fetch multi-ion's density. 
      ; It is worth noting that the CO2+ density measurements are polluted by the O2+, please colsult the instrument team for data validation.
      ; Check data avaliablity
      mvn_sta_l2_load, sta_apid='c6', /tplot_vars_create; if no apid keyword set, then load all apids
      mvn_scpot
      ;mvn_multi_ions_spectrum
      tplot_rename, 'mvn_sta_c6_M', 'eflux_mass'
      get_data, 'eflux_mass', dtype = dtype
      IF  dtype EQ 0 THEN BEGIN
          PRINT, 'No STATIC C6 data for '+tdate+' being loaded, now return...'
        return
      ENDIF

      get_4dt,'n_4d','mvn_sta_get_c6',MASS=[0.5,1.68],m_int=1,name='den_h+'
      get_4dt,'n_4d','mvn_sta_get_c6',MASS=[12,20],m_int=16,name='den_o+'
      get_4dt,'n_4d','mvn_sta_get_c6',MASS=[24,40],m_int=32,name='den_o2+'
      get_4dt,'n_4d','mvn_sta_get_c6',MASS=[40,48],m_int=44,name='den_co2+_polluted'
  ENDIF
  
  IF keyword_set(ivel) THEN BEGIN
;    mvn_sta_ion_vel, trange=trange, apid=apid, _EXTRA=_EXTRA
    mvn_spice_load, /no_download
    mvn_sta_l2_load, sta_apid=apid, /tplot_vars_create
    mvn_scpot
    
    cols = get_colors()
    icols = [cols.blue,cols.green,cols.red]
    species = ['h+','o+','o2+','co2+']
    
    m_arr = fltarr(3,4)
    m_arr[*,0] = [0.5,1,1.68] ; H+
    m_arr[*,1] = [12,16,20]   ; O+
    m_arr[*,2] = [24,32,40]   ; O2+
    m_arr[*,3] = [40,44,48]   ; CO2+
    
    e_arr = fltarr(2,4)
    e_arr[*,0] = [0.,30000.]  ; H+
    e_arr[*,1] = [0., 3000.]  ; O+
    e_arr[*,2] = [0., 3000.]  ; O2+
    e_arr[*,3] = [0., 3000.]  ; CO2+
    
    v_names = 'vel3d_' + species 
    v_bulk_names = 'velb_' + species
    
    FOR  i=0,3 DO BEGIN
      mass = m_arr[*,i]
      erange = e_arr[*,i]
      
      get_4dt,'v_4d','mvn_sta_get_'+apid, mass=minmax(mass), m_int=mass[1],$
                                      erange=erange, name=v_names[i]+'_static'
      
      get_data , v_names[i]+'_static', t, d
      v_sc = spice_body_vel('MAVEN', 'MARS', utc=t, frame='MAVEN_MSO')
      v_sc = spice_vector_rotate(v_sc, t, 'MAVEN_MSO', 'MAVEN_STATIC')
      dv = spice_vector_rotate(transpose(d)+ v_sc, t, 'MAVEN_STATIC', 'MAVEN_MSO')
      store_data, v_names[i], data={ X:t,Y:transpose(dV)}
      tvectot, v_names[i], tot=v_bulk_names[i]
      options, v_names[i], 'ytitle', (species[i] + ' V_MSO!ckm/s')
      options, v_names[i], 'labels', ['X','Y','Z']
      options, v_names[i], 'colors', ['r', 'g', 'b']
      options, v_names[i], 'labflag', 1
      del_data, v_names[i]+'_static'
    ENDFOR

ENDIF
   
  IF keyword_set(temp) THEN BEGIN
    mvn_sta_l2_load, sta_apid='c6'
    ; Use get_4dt and function "t_4d" to fetch multi-ion's temperature,  in units of eV, assumes no s/c charging 
    get_4dt,'tb_4d','mvn_sta_get_c6',MASS=[0.5,1.68],m_int=1,name='temp_h+'
    get_4dt,'tb_4d','mvn_sta_get_c6',MASS=[12,20],m_int=16,name='temp_o+'
    get_4dt,'tb_4d','mvn_sta_get_c6',MASS=[24,40],m_int=32,name='temp_o2+'
    get_4dt,'tb_4d','mvn_sta_get_c6',MASS=[40,48],m_int=44,name='temp_co2+'
    IF keyword_set(t_smooth) THEN BEGIN
      tsmooth2, 'temp_h+', ts_level
      tsmooth2, 'temp_o+', ts_level
      tsmooth2, 'temp_o2+', ts_level
      tsmooth2, 'temp_co2+', ts_level
    ENDIF
  ENDIF
ENDIF
;===========================================================================================

;=======================================MAVEN/NGIMS=======================================
IF keyword_set(ngims) THEN BEGIN
  ; NGIMS is short for Neutral Gas and Ion Mass Spectrometer
  ; NGIMS measures density profile of neutral compositions such as He, N, O, CO, N2, NO, O2, Ar, and CO2
  ; NGIMS also get profiles of *THERMAL* ions O2+, CO2+, NO+, O+, CO+, C+, N2+, NO+, and N+
  ;======================IMPORTANT NOTICE======================
  ;The prime NGIMS science is realized *BELOW 500 km* so above this altitude the instrument 
  ;will generally be in a low power standby mode with filaments and detectors turned off.
  ;=============================================================
  mvn_ngi_load, trange=trange, _extra=_extra
ENDIF
;===========================================================================================

;==================================MAVEN/Langmuir Probe======================================
IF keyword_set(lanpw) THEN BEGIN
  ; Load MAVEN Langmuir Probe and Waves (LPW) L2 elecrton number density and temperature data
  ; This routine will create three tplot variables, namely as follows:
  ; 1. "mvn_lpw_lp_ne_l2" for electron number density
  ; 2. "mvn_lpw_lp_te_l2" for electron temperature
  ; 3. "mvn_lpw_lp_vsc_l2" for spacecraft potential
  ; Default LPW data product is 'lpnt', for other data products, check "mvn_lpw_load_l2.pro" for more details
  IF  ~keyword_set(lpw_list) THEN BEGIN
    lpw_list = ['lpnt']
  ENDIF
  mvn_lpw_load_l2, lpw_list, success=sc1, tplotvars=tvs, /noTPLOT
ENDIF
;===========================================================================================

IF keyword_set(save) THEN BEGIN
; Save tplot variables locally
  tvars = tnames()
  tplot_save, tvars, filename = filename
ENDIF

IF keyword_set(plot) THEN BEGIN
;  maven_tplot_peek
END

IF keyword_set(no_server) THEN BEGIN
  help,/structure, mvn_file_source(/reset) ; reset source settings
  print, 'Data source has been changed back to default, remote-checking applied for the next time'
ENDIF

END
