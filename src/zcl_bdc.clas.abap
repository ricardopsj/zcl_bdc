class zcl_bdc definition
  public
  create public .

  public section.

    constants:
      begin of c
        , begin of dismode
          , all     type ctu_mode value 'A' " Visualizar todas las pantallas
          , error   type ctu_mode value 'E' " Visualizar solo errores
          , nothing type ctu_mode value 'N' " Fondo, sin pantallas
          , debug   type ctu_mode value 'P' " Fondo, con depuración posible
        , end of dismode
        , begin of updmode
          , sync  type ctu_update value 'S' " Síncrono
          , async type ctu_update value 'A' " Asíncrono
          , local type ctu_update value 'L' " Local
        , end of updmode
      , end of c .

    data s_params type ctu_params read-only .
    data tcode type tcode read-only .
    data subrc type sysubrc read-only .
    data ref_log type ref to zcl_log read-only .

    methods constructor
      importing
        !tcode    type tcode
        !dismode  type ctu_mode default c-dismode-nothing
        !updmode  type ctu_update default c-updmode-sync
        !cattmode type ctu_catt default ' '
        !defsize  type ctu_defsze default 'X'
        !racommit type ctu_rafc default ' '
        !nobinpt  type ctu_nobim default ' '
        !nobiend  type ctu_noben default ' '
        !ref_log  type ref to zcl_log optional .
    methods dynpro
      importing
        !program      type clike
        !dynpro       type clike
      returning
        value(ref_me) type ref to zcl_bdc .
    methods field
      importing
        !fnam         type clike
        !fval         type any
        !conv         type abap_bool default abap_true
        !waers        type any optional
        !maxlen       type i optional
      returning
        value(ref_me) type ref to zcl_bdc .
    methods okcode
      importing
        !fcode        type clike
      returning
        value(ref_me) type ref to zcl_bdc .
    methods cursor
      importing
        !fnam         type clike
      returning
        value(ref_me) type ref to zcl_bdc .
    methods call
      returning
        value(ok) type abap_bool .
    methods has_msg
      importing
        !msgid        type msgid optional
        !msgno        type msgno optional
        !msgty        type msgty optional
      returning
        value(has_it) type abap_bool .
    methods has_error
      returning
        value(has_it) type abap_bool .
    methods set_ok_msg
      importing
        !msgid type msgid
        !msgno type msgno
        !msgty type msgty default 'S' .
    methods set_log
      importing
        !ref_log type ref to zcl_log .
    methods get_bdcdata
      returning
        value(t_bdcdata) type tab_bdcdata .
    methods get_messages
      returning
        value(t_msg) type tab_bdcmsgcoll .
    methods refresh .
  protected section.

    data t_bdcdata type tab_bdcdata .
    data t_msg type tab_bdcmsgcoll .
    data:
      begin of s_ok_msg
        , msgid type msgid
        , msgno type msgno
        , msgty type msgty
        , end of s_ok_msg .

    methods add_log
      importing
        !msgid type clike
        !msgno type clike
        !msgty type clike
        !msgv1 type clike optional
        !msgv2 type clike optional
        !msgv3 type clike optional
        !msgv4 type clike optional .
  private section.
ENDCLASS.



CLASS ZCL_BDC IMPLEMENTATION.


  method add_log.
    if ref_log is bound.
      ref_log->add_msg( msgid = msgid
                        msgno = msgno
                        msgty = msgty
                        msgv1 = msgv1
                        msgv2 = msgv2
                        msgv3 = msgv3
                        msgv4 = msgv4 ).
    endif.
  endmethod.


  method call.
    clear: t_msg, subrc.

    try.
        call transaction tcode with authority-check
                         using t_bdcdata
                         options from s_params
                         messages into t_msg.
        subrc = sy-subrc.
      catch cx_sy_authorization_error.
        subrc = 4.
        clear t_bdcdata.
        add_log( msgid = 'ZCL_BDC' msgno = '003' msgty = 'E' msgv1 = tcode ). " Sin autorización para la transacción &1
        return.
    endtry.
    clear t_bdcdata.

    loop at t_msg reference into data(ref_msg).
      add_log( msgid = ref_msg->msgid
               msgno = ref_msg->msgnr
               msgty = ref_msg->msgtyp
               msgv1 = ref_msg->msgv1
               msgv2 = ref_msg->msgv2
               msgv3 = ref_msg->msgv3
               msgv4 = ref_msg->msgv4 ).
    endloop.

    if s_ok_msg is not initial.
      " Con mensaje de éxito definido, solo cuenta que haya aparecido: muchas
      " transacciones terminan con SY-SUBRC 1001 aunque hayan grabado.
      ok = has_msg( msgid = s_ok_msg-msgid msgno = s_ok_msg-msgno msgty = s_ok_msg-msgty ).
      if ok = abap_false.
        add_log( msgid = 'ZCL_BDC' msgno = '001' msgty = 'E' " No se obtuvo el mensaje esperado &1 &2 en la transacción &3
                 msgv1 = s_ok_msg-msgid msgv2 = s_ok_msg-msgno msgv3 = tcode ).
      endif.
    else.
      ok = xsdbool( subrc = 0 and has_error( ) = abap_false ).
      if ok = abap_false and has_error( ) = abap_false.
        add_log( msgid = 'ZCL_BDC' msgno = '002' msgty = 'E' " La transacción &1 terminó con código de retorno &2
                 msgv1 = tcode msgv2 = |{ subrc }| ).
      endif.
    endif.
  endmethod.


  method constructor.
    me->tcode = tcode.

    s_params-dismode  = dismode.
    s_params-updmode  = updmode.
    s_params-cattmode = cattmode.
    s_params-defsize  = defsize.
    s_params-racommit = racommit.
    s_params-nobinpt  = nobinpt.
    s_params-nobiend  = nobiend.

    me->ref_log = ref_log.
  endmethod.


  method cursor.
    ref_me = field( fnam = 'BDC_CURSOR' fval = fnam conv = abap_false ).
  endmethod.


  method dynpro.
    append value #( program  = program
                    dynpro   = dynpro
                    dynbegin = abap_true ) to t_bdcdata.
    ref_me = me.
  endmethod.


  method field.
    " Los valores se pasan en formato externo (como los teclearía el usuario)
    data(fval_ext) = cond string( when fval is initial  then ``
                                  when conv = abap_true then zcl_ce=>output_string( input = fval waers = waers )
                                  else                       |{ fval }| ).
    if maxlen > 0 and strlen( fval_ext ) > maxlen.
      fval_ext = substring( val = fval_ext len = maxlen ).
    endif.

    append value #( fnam = fnam
                    fval = fval_ext ) to t_bdcdata.
    ref_me = me.
  endmethod.


  method get_bdcdata.
    t_bdcdata = me->t_bdcdata.
  endmethod.


  method get_messages.
    t_msg = me->t_msg.
  endmethod.


  method has_error.
    has_it = xsdbool( line_exists( t_msg[ msgtyp = 'E' ] ) or line_exists( t_msg[ msgtyp = 'A' ] ) ).
  endmethod.


  method has_msg.
    loop at t_msg reference into data(ref_msg).
      if ( msgid is not supplied or ref_msg->msgid  = msgid )
     and ( msgno is not supplied or ref_msg->msgnr  = msgno )
     and ( msgty is not supplied or ref_msg->msgtyp = msgty ).
        has_it = abap_true.
        return.
      endif.
    endloop.
  endmethod.


  method okcode.
    ref_me = field( fnam = 'BDC_OKCODE' fval = fcode conv = abap_false ).
  endmethod.


  method refresh.
    clear: t_bdcdata, t_msg, subrc.
  endmethod.


  method set_log.
    me->ref_log = ref_log.
  endmethod.


  method set_ok_msg.
    s_ok_msg-msgid = msgid.
    s_ok_msg-msgno = msgno.
    s_ok_msg-msgty = msgty.
  endmethod.
ENDCLASS.
