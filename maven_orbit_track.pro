FUNCTION zip_index, data, clip_range
  index = where(data LE clip_range[1] AND data GE clip_range[0] )
  return, index
END

PRO MAVEN_ORBIT_TRACK, TRANGE=TRANGE, LONG_RANGE=LONG_RANGE, LAT_RANGE=LAT_RANGE, ALT_RANGE=ALT_RANGE, SZA_RANGE=SZA_RANGE,$
                       T_MIN=T_MIN, DEN_FLAG=DEN_FLAG, D_LEVEL=D_LEVEL,CHECK_SPICE=CHECK_SPICE,DATA_DIR=DATA_DIR, FILENAME=FILENAME
;+
;PURPOSE:
;  Search and/or plot MAVEN ground tracks on Mars' geographical map
;CALLING SEQUENCE:
;  
;INPUT: 
;  TRANGE: time span
;  LONG_RANGE: longtitude range under Mars' geographical map
;  LAT_RANGE: latitude range under Mars' geographical map
;  ALT_RANGE: altitude range, measured from Mars surface, in kilomete.
;  SZA_RANGE: solar zenith angle range
;  T_MIN: the time threshold of a valid orbit track to record
;  DEN_FLAG: whether to check ion density variation or not
;  D_LEVEL: the density increase/decrease magnitude
;  CHECK_SPICE: the ion spice to use as the tracking spice
;  DATA_DIR: MAVEN data directory
;  FILEMANE: saved text filename for tracked orbits
;
;CREATED BY: YDYE@MUST 20201111
;-

 del_data, '*'
 init_crib_colors

 IF exist(TRANGE) THEN BEGIN
    trange = time_double(trange)
    min_orb_num = floor(mvn_orbit_num(time=trange[0]))
    max_orb_num = ceil(mvn_orbit_num(time=trange[1]))
 ENDIF ELSE BEGIN   
    min_orb_num=40
    max_orb_num=floor(mvn_orbit_num(time=systime(1)- double(3600.*24.*360.))) ;maximum orbit number of one year before the current time
   ; start form orbit number 5 ('2014-09-27/21:37:11') to the maximum
 ENDELSE

 ; judgement---> orbnum -> sza -> alt -> lat -> long
 FOR i =min_orb_num,  max_orb_num DO BEGIN
 
   del_data, '*'
 ;==================MAVEN Ascending Orbit=======================
    t0=mvn_orbit_num(orbnum=i) ; time baseline
    t_beg = t0 + start_t_offset
    t1=my_mvn_orbit_num(apo_orbnum=i)
    t_end = t1 + end_t_offset
    trange = [t_beg, t_end]
     print, 'Now checking: ', time_string(trange)
    maven_data_tplot, trange = trange, /spice, /NO_SERVER
    tvars = ['alt', 'lon', 'lat', 'sza']
    time_clip, tvars, trange[0], trange[1], /replace
    
    get_data, 'alt', t_alt, d_alt
    get_data, 'lon', t_lon, d_lon
    get_data, 'lat', t_lat, d_lat
    get_data, 'sza', t_sza, d_sza
        
    s1 = zip_index(d_alt, alt_range)
    IF s1[0] EQ -1 THEN GOTO, decend_orbit
    
    s2 = zip_index(d_lon, long_range)
    IF s2[0] EQ -1 THEN GOTO, decend_orbit
    
    s3 = zip_index(d_lat, lat_range)
    IF s3[0] EQ -1 THEN GOTO, decend_orbit

    s4 = zip_index(d_sza, sza_range)
    IF s4[0] EQ -1 THEN GOTO, decend_orbit
    
    s0 = intersect(s1, s2)
    IF MAX(FINITE(s0, /nan)) THEN GOTO, decend_orbit
    s0 = intersect(s0, s3)
    IF MAX(FINITE(s0, /nan)) THEN GOTO, decend_orbit
    s0 = intersect(s0, s4)
    IF MAX(FINITE(s0, /nan)) THEN GOTO, decend_orbit
    
    final_t_start = t_sza[s0[0]]
    final_t_end   = t_sza[s0[-1]]
    delta_t = final_t_end - final_t_start
    final_trange =time_string( [final_t_start, final_t_end])
    
    IF delta_t LT t_min THEN GOTO, decend_orbit ;remove too-short time period. Threshold set to 120 seconds.
    
    maven_data_tplot, trange = final_trange,  data_dir=data_dir, /static, /den, /NO_SERVER, /no_delete
    IF den_flag THEN BEGIN
        get_data, check_spice, t, d, dtype=dtype
        IF  dtype EQ 0 THEN GOTO, decend_orbit
        IF max(d) LE 0.1 THEN GOTO, decend_orbit ; no O2+, suggesting MAVEN not in the ionosphere
        ii = where(d LE 0.1) ; remove 0 values to prevent infinity error
        IF (size(ii, /n_elements) NE  size(d, /n_elements)) AND (min(ii) NE -1) THEN remove, ii, d
        IF alog10(max(d)) -  alog10(min(d)) LE d_level THEN GOTO, decend_orbit
    ENDIF
    
    final_trange =time_string( [final_t_start, final_t_end])
    maven_data_tplot, trange = final_trange,  data_dir=data_dir, /swea, /mag, /NO_SERVER, /no_delete
    get_data,'mvn_B_1sec_maven_mso',data=d,dlimits=dl
    cotrans_set_coord,dl,'MSO' ; any string is OK, or minvar_matrix_make will give error on 'data_att'
    store_data,'mvn_B_1sec_maven_mso',data=d,dlimits=dl
    tplot_rename, 'mvn_B_1sec_maven_mso', 'b_mso'
    get_data,'b_mso', dtype=dtype
    IF dtype EQ 0 THEN CONTINUE
    tvectot, 'b_mso', tot='b_tot'
    split_vec, 'b_mso'
    join_vec,['b_tot', 'b_mso_x', 'b_mso_y', 'b_mso_z'], 'b_tot'
    maven_data_tplot,  trange=final_trange, data_dir=data_dir, /key_param, /swia, /NO_SERVER, /no_delete
    join_vec,['v_mso_x','v_mso_y','v_mso_z'],'v_mso'
    tvectot,'v_mso',tot='v_tot'
    mvn_mag_zenith_angle, b_mso='b_mso', p_mso='p_mso'
    openw, lun, filename, /get_lun, /append
    printf, lun, final_trange[0], final_trange[1], delta_t,$
                    tplot_consult('alt', final_t_start), tplot_consult('alt', final_t_end), $
                    tplot_consult('lon', final_t_start), tplot_consult('lon', final_t_end), $
                    tplot_consult('lat', final_t_start), tplot_consult('lat', final_t_end), $
                    tplot_consult('sza', final_t_start), tplot_consult('sza', final_t_end), $
                    format = '(A19, 2X, A19, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4)'         
    close, lun
    free_lun, LUN
    t_filename = time_string(final_t_start, tformat='YYYYMMDD_hh') 
    popen, t_filename ,xsize=8,ysize=10,units='inches'
    tplot_options, 'region',[0.1,0.1,0.95,0.95]
    tplot_options, 'charsize', 0.7
    tplot_options, 'tickinterval',2*60
    tplot_options, 'ygap', 0.2
    options,'b_tot', colors=['x', 'r', 'g', 'b']
    options,'b_tot', labels=textoidl(['|B|','B_X','B_Y','B_Z'])
    options,'b_tot', labflag = -1
    options,'b_tot', ytitle= 'Magnetic Field', ysubtitle ='!c [nT]'
     join_vec,['den_h+','den_o+','den_o2+','den_co2+'],'den_ion'
    options,'den_ion','ytitle',textoidl('Ion Density !c!c[cm^{-3}]')
    options,'den_ion', ylog=1
    options, 'lon', ytitle = 'Longitude', ysubtitle = '!c [Degree]'
    options, 'lon', yrange = [0, 360]
    options, 'lat', ytitle = 'Latitude', ysubtitle = '!c [Degree]'
    options, 'lat', yrange=[-90, 90]
    options, 'alt', ytitle = 'Altitude', ysubtitle ='!c [km]'
    options, 'sza', ytitle = 'SZA', ysubtitle = '!c [Degree]'
    options, 'mag_zenith_angle', ytitle = 'MZA', ysubtitle = '!c [Degree]'
    options, 'v_tot', ytitle = textoidl('V_{SWIA}'), ysubtitle ='!c [km/s]'
    options, 'eflux_mass', yrange=[1, 64], ytitle = 'Mass !c!c[amu]'
    options, [ 'b_tot', 'v_tot', 'mag_zenith_angle', 'alt', 'lon', 'lat', 'sza', 'den_ion', 'eflux_E', 'eflux_mass'], panel_size = 0.4
    species_labels=textoidl(['H^+','O^+','O_{2}^+','CO_{2}^+'])
    get_Data, 'den_ion', dtype=dtype
    IF dtype NE 0 THEN multispices_tplot_options, ['den_ion'], species_labels,  -1
    
    tplot_options, 'tickinterval',5*60
    tplot_options, 'xminor', 2
    tplot, ['b_tot', 'v_tot', 'mag_zenith_angle', 'alt', 'lon', 'lat', 'sza', 'den_ion', 'eflux_E', 'eflux_mass']
    timebar, 0.0, /databar, varname= 'b_tot', linestyle=1
    timebar, 90., /databar, varname= 'mag_zenith_angle', linestyle=1
    pclose
;============================================================


;==================MAVEN Dscending Orbit=======================
    decend_orbit: print, 'No case found in ascending orbit, now check decending orbit...'
    t0=my_mvn_orbit_num(apo_orbnum=i); time baseline
    t_beg = t0 + start_t_offset
    t1=mvn_orbit_num(orbnum=(i+1))
    t_end = t1 + end_t_offset
    trange = [t_beg, t_end]
    print, 'Now checking: ', time_string(trange)
    maven_data_tplot, trange = trange, /spice, /NO_SERVER
    tvars = ['alt', 'lon', 'lat', 'sza']
    time_clip, tvars, trange[0], trange[1], /replace
    
    get_data, 'alt', t_alt, d_alt
    get_data, 'lon', t_lon, d_lon
    get_data, 'lat', t_lat, d_lat
    get_data, 'sza', t_sza, d_sza
    
    s1 = zip_index(d_alt, alt_range)
    IF s1[0] EQ -1 THEN CONTINUE
    
    s2 = zip_index(d_lon, long_range)
    IF s2[0] EQ -1 THEN CONTINUE
    
    s3 = zip_index(d_lat, lat_range)
    IF s3[0] EQ -1 THEN CONTINUE
    
    s4 = zip_index(d_sza, sza_range)
    IF s4[0] EQ -1 THEN CONTINUE
    
    s0 = intersect(s1, s2)
    IF MAX(FINITE(s0, /nan)) THEN CONTINUE
    s0 = intersect(s0, s3)
    IF MAX(FINITE(s0, /nan)) THEN CONTINUE
    s0 = intersect(s0, s4)
    IF MAX(FINITE(s0, /nan)) THEN CONTINUE
    
    final_t_start = t_sza[s0[0]]
    final_t_end   = t_sza[s0[-1]]
    delta_t = final_t_end - final_t_start
    final_trange =time_string( [final_t_start, final_t_end])
    
    IF delta_t LT t_min THEN CONTINUE
    
    maven_data_tplot, trange = final_trange,  data_dir=data_dir, /static, /den, /NO_SERVER, /no_delete
    IF den_flag THEN BEGIN
        get_data, check_spice, t, d, dtype=dtype
        IF  dtype EQ 0 THEN CONTINUE
        IF max(d) LE 0.1 THEN CONTINUE
        ii = where(d LE 0.1) ; remove 0 values to prevent infinity error
        IF  (size(ii, /n_elements) NE  size(d, /n_elements)) AND (min(ii) NE -1) THEN remove, ii, d
        IF alog10(max(d)) -  alog10(min(d)) LE d_level THEN CONTINUE
    ENDIF
    
    final_trange =time_string( [final_t_start, final_t_end])
    maven_data_tplot, trange = final_trange,  data_dir=data_dir, /swea, /mag, /NO_SERVER, /no_delete
    get_data,'mvn_B_1sec_maven_mso',data=d,dlimits=dl
    cotrans_set_coord,dl,'MSO' ; any string is OK, or minvar_matrix_make will give error on 'data_att'
    store_data,'mvn_B_1sec_maven_mso',data=d,dlimits=dl
    tplot_rename, 'mvn_B_1sec_maven_mso', 'b_mso'
    get_data,'b_mso', dtype=dtype
    IF dtype EQ 0 THEN CONTINUE
    tvectot, 'b_mso', tot='b_tot'
    split_vec, 'b_mso'
    join_vec,['b_tot', 'b_mso_x', 'b_mso_y', 'b_mso_z'], 'b_tot'
    maven_data_tplot,  trange=final_trange, data_dir=data_dir, /key_param, /swia, /NO_SERVER, /no_delete
    join_vec,['v_mso_x','v_mso_y','v_mso_z'],'v_mso'
    tvectot,'v_mso',tot='v_tot'
    mvn_mag_zenith_angle, b_mso='b_mso', p_mso='p_mso'
    openw, lun, filename, /get_lun, /append
    printf, lun, final_trange[0], final_trange[1], delta_t,$
      tplot_consult('alt', final_t_start), tplot_consult('alt', final_t_end), $
      tplot_consult('lon', final_t_start), tplot_consult('lon', final_t_end), $
      tplot_consult('lat', final_t_start), tplot_consult('lat', final_t_end), $
      tplot_consult('sza', final_t_start), tplot_consult('sza', final_t_end), $
      format = '(A19, 2X, A19, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4, 2X, F10.4)'
    close, lun
    free_lun, LUN
    t_filename = time_string(final_t_start, tformat='YYYYMMDD_hh') 
    popen, t_filename ,xsize=8,ysize=10,units='inches'
    tplot_options, 'region',[0.1,0.1,0.95,0.95]
    tplot_options, 'charsize', 0.7
    tplot_options, 'tickinterval',2*60
    tplot_options, 'ygap', 0.2
    options,'b_tot', colors=['x', 'r', 'g', 'b']
    options,'b_tot', labels=textoidl(['|B|','B_X','B_Y','B_Z'])
    options,'b_tot', labflag = -1
    options,'b_tot', ytitle= 'Magnetic Field', ysubtitle ='!c [nT]'
     join_vec,['den_h+','den_o+','den_o2+','den_co2+'],'den_ion'
    options,'den_ion','ytitle',textoidl('Ion Density !c!c[cm^{-3}]')
    options,'den_ion', ylog=1
    options, 'lon', ytitle = 'Longitude', ysubtitle = '!c [Degree]'
    options, 'lon', yrange = [0, 360]
    options, 'lat', ytitle = 'Latitude', ysubtitle = '!c [Degree]'
    options, 'lat', yrange=[-90, 90]
    options, 'alt', ytitle = 'Altitude', ysubtitle ='!c [km]'
    options, 'sza', ytitle = 'SZA', ysubtitle = '!c [Degree]'
    options, 'mag_zenith_angle', ytitle = 'MZA', ysubtitle = '!c [Degree]'
    options, 'v_tot', ytitle = textoidl('V_{SWIA}'), ysubtitle ='!c [km/s]'
    options, 'eflux_mass', yrange=[1, 64], ytitle = 'Mass !c!c[amu]'
    options,  ['b_tot', 'v_tot', 'mag_zenith_angle', 'alt', 'lon', 'lat', 'sza', 'den_ion', 'eflux_E', 'eflux_mass'], panel_size = 0.4
    species_labels=textoidl(['H^+','O^+','O_{2}^+','CO_{2}^+'])
    get_Data, 'den_ion', dtype=dtype
    IF dtype NE 0 THEN multispices_tplot_options, ['den_ion'], species_labels,  -1
    
    tplot_options, 'tickinterval',5*60
    tplot_options, 'xminor', 2
    tplot, ['b_tot', 'v_tot', 'mag_zenith_angle', 'alt', 'lon', 'lat', 'sza', 'den_ion', 'eflux_E', 'eflux_mass']
    timebar, 0.0, /databar, varname= 'b_tot', linestyle=1
    timebar, 90., /databar, varname= 'mag_zenith_angle', linestyle=1
    pclose
 ENDFOR

END