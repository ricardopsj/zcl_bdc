*&---------------------------------------------------------------------*
*& Report ZBDC_DEMO1
*&---------------------------------------------------------------------*
*& Prueba de ZCL_BDC: abre una clase en SE24, visualiza el código de
*& sus primeros métodos y sale de la transacción. Basado en la grabación
*& SHDB ZCL_BDC. Solo consulta, no modifica datos.
*&---------------------------------------------------------------------*
report zbdc_demo1.

selection-screen begin of block b01 with frame title text-b01.
parameters:
  p_class type seoclsname obligatory default 'ZCL_BDC',
  p_meth  type i obligatory default 3,
  p_srce  as checkbox default 'X'.
selection-screen end of block b01.

selection-screen begin of block b02 with frame title text-b02.
parameters:
  p_all    radiobutton group mode default 'X',
  p_error  radiobutton group mode,
  p_nothin radiobutton group mode.
selection-screen end of block b02.

selection-screen begin of block b03 with frame title text-b03.
parameters:
  p_save   as checkbox,
  p_object type balobj_d,
  p_subobj type balsubobj.
selection-screen end of block b03.

at selection-screen.
  if p_save = abap_true and p_object is initial.
    message text-e01 type 'E'. " Para grabar el log indique el objeto (SLG0)
  endif.
  if p_meth not between 1 and 10.
    message text-e02 type 'E'. " Métodos a visualizar: entre 1 y 10
  endif.

start-of-selection.
  data(ref_log) = new zcl_log( ).
  if p_save = abap_true.
    ref_log->set_object( p_object ).
    ref_log->set_subobject( p_subobj ).
  endif.
  ref_log->create( ).

  data(ref_bdc) = new zcl_bdc( tcode   = 'SE24'
                               dismode = cond #( when p_all   = abap_true then zcl_bdc=>c-dismode-all
                                                 when p_error = abap_true then zcl_bdc=>c-dismode-error
                                                 else                          zcl_bdc=>c-dismode-nothing )
                               ref_log = ref_log ).

  " Pantalla inicial del Class Builder: nombre de la clase y Visualizar (F7)
  ref_bdc->dynpro( program = 'SAPLSEOD' dynpro = '1000'
        )->field( fnam = 'SEOCLASS-CLSNAME' fval = p_class
        )->okcode( '=WB_DISPLAY' ).

  " Si SE24 abre el editor basado en fuente, se cambia a basado en formulario
  if p_srce = abap_true.
    ref_bdc->dynpro( program = 'SAPLSEO_CLASS_EDITOR' dynpro = '0400'
          )->okcode( '=OO_TOGGLE_CB_MODE' ).
  endif.

  " Pestaña Métodos: doble clic en cada método y volver con F3.
  " El índice es la línea visible del table control, por eso el máximo de 10.
  do p_meth times.
    ref_bdc->dynpro( program = 'SAPLSEOD' dynpro = '2000'
          )->cursor( |DY_0253-CPDNAME({ sy-index width = 2 align = right pad = '0' })|
          )->okcode( '=OO_PICKUP'
          )->dynpro( program = 'SAPLSEO_CLEDITOR' dynpro = '0200'
          )->okcode( '/EWB_BACK' ).
  enddo.

  " Salir: de la clase (pasando otra vez por el editor basado en fuente) y de SE24
  ref_bdc->dynpro( program = 'SAPLSEOD' dynpro = '2000'
        )->okcode( '=WB_BACK' ).
  if p_srce = abap_true.
    ref_bdc->dynpro( program = 'SAPLSEO_CLASS_EDITOR' dynpro = '0400'
          )->okcode( '/EWB_BACK' ).
  endif.
  ref_bdc->dynpro( program = 'SAPLSEOD' dynpro = '1000'
        )->okcode( '=WB_BACK' ).

  " El recorrido completo sale de SE24, así que basta con SY-SUBRC = 0 y sin errores
  data(ok) = ref_bdc->call( ).

  ref_log->add_msg( msgid = 'ZCL_BDC'
                    msgno = '000'
                    msgty = cond msgty( when ok = abap_true then 'S' else 'E' )
                    msgv1 = cond string( when ok = abap_true then text-m01 else text-m02 )
                    msgv2 = |SY-SUBRC { ref_bdc->subrc }| ).

  if p_save = abap_true.
    ref_log->save( ).
  endif.
  ref_log->display( ).
