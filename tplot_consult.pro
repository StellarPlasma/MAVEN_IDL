FUNCTION TPLOT_CONSULT, TVAR, T
; A small function to return data of a tplot variable at a certain time point
; Written by ydye@MUST
get_data, tvar, ts, data
nd = size(data)
t=time_double(t)
tindex = find_nearest_neighbor(ts,t)
index = where(ts EQ tindex)
IF nd[0] EQ 1 THEN BEGIN
  result=data[index]
ENDIF ELSE BEGIN
  result=fltarr(nd[2])
  FOR i=0, nd[2]-1 DO result[i]=data[index, i]
ENDELSE
return, result
END