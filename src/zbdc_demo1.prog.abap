*&---------------------------------------------------------------------*
*& Report ZBDC_DEMO1
*&---------------------------------------------------------------------*
*& Prueba de ZCL_BDC: abre una clase en SE24 en modo visualización.
*& Solo consulta, no modifica datos. Los mensajes quedan en ZCL_LOG.
*&---------------------------------------------------------------------*
report zbdc_demo1.

selection-screen begin of block b01 with frame title text-b01.
parameters:
  p_class type seoclsname obligatory default 'ZCL_BDC'.
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

  " Pantalla inicial del Class Builder: nombre de la clase y botón Visualizar (F7)
  ref_bdc->dynpro( program = 'SAPLSEOD' dynpro = '1000'
        )->field( fnam = 'SEOCLASS-CLSNAME' fval = p_class
        )->okcode( '=WB_DISPLAY' ).

  " Sin pantallas, si la clase existe SE24 pasa a visualizarla y, como no hay
  " más datos BDC, termina con el mensaje 00 344: eso indica que se abrió.
  " Con todas las pantallas el usuario sigue en SE24 y sale con F3.
  if p_all = abap_false.
    ref_bdc->set_ok_msg( id = '00' no = '344' ).
  endif.

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
