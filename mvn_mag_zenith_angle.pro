PRO MVN_MAG_ZENITH_ANGLE, B_MSO=B_MSO, P_MSO=P_MSO, TRANGE=TRANGE, DATA_DIR=DATA_DIR, NO_SERVER=NO_SERVER
  ;+
  ; PURPOSE:
  ;   Calculate the angle between the magnetic field direction and the local radial direction
  ; CALLING SEQUENCE:
  ;   MVN_MAG_ZENITH_ANGLE, B_MSO=B_MSO, P_MSO=P_MSO
  ; INPUT:
  ;   Two tplot variables: MAG for magnetic field, and P_MSO for MAVEN's MSO coordinate
  ;   [DATA_DIR]: optional, user-defined data directory. If not set, then use default data directory defined in root_data_dir.pro
  ;   [trange]: optionaL, used for stand-alone running
  ; KEYWORDS:
  ;   NO_SERVER: USED FOR MAVEN_DATA_TPLOT. Don't check for remote files' updates on the server, 
  ;              temporarily use only the local data. This will speed up the searching and 
  ;              processing of data files, especially on poor web-connection conditions.
  ;              Please be sure that you have all needed data downloaded already.
  ; OUTPUTS: 
  ;   A tplot variable "mag_zenith_angle" stored the calculate result
  ; CREATED BY: YDYE@MUST， 20210121
  ; MODIFICATIONS: 
  ;-

  IF exist(trange) THEN BEGIN
    maven_data_tplot, trange=trange, /spice, /mag
  ENDIF
  get_data, p_mso, t_p, d_p
  mza = t_p
  FOR i=0, size(t_p, /n_elements)-1 DO BEGIN
    b = tplot_consult(b_mso, t_p[i])
    mza[i] = angle_between_two_vectors(b, transpose(d_p[i, *])) * !RADEG
  ENDFOR
  
  store_data, 'mag_zenith_angle', data = {X: t_p, Y: mza}
END