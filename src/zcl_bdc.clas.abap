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

    types tt_bdcdata type standard table of bdcdata with default key .
    types tt_bdcmsgcoll type standard table of bdcmsgcoll with default key .

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
        !id           type msgid optional
        !no           type msgno optional
        !ty           type msgty optional
      returning
        value(has_it) type abap_bool .
    methods has_error
      returning
        value(has_it) type abap_bool .
    methods set_ok_msg
      importing
        !id type msgid
        !no type msgno
        !ty type msgty default 'S' .
    methods set_log
      importing
        !ref_log type ref to zcl_log .
    methods get_bdcdata
      returning
        value(t_bdcdata) type tt_bdcdata .
    methods get_messages
      returning
        value(t_msg) type tt_bdcmsgcoll .
    methods refresh .
  protected section.

    data t_bdcdata type tt_bdcdata .
    data t_msg type tt_bdcmsgcoll .
    data:
      begin of s_ok_msg
        , id type msgid
        , no type msgno
        , ty type msgty
        , end of s_ok_msg .

    methods add_log
      importing
        !id type clike
        !no type clike
        !ty type clike
        !v1 type clike optional
        !v2 type clike optional
        !v3 type clike optional
        !v4 type clike optional .
  private section.
ENDCLASS.



CLASS ZCL_BDC IMPLEMENTATION.


  method add_log.
    if ref_log is bound.
      ref_log->add_msg( msgid = id
                        msgno = no
                        msgty = ty
                        msgv1 = v1
                        msgv2 = v2
                        msgv3 = v3
                        msgv4 = v4 ).
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
        add_log( id = 'ZCL_BDC' no = '003' ty = 'E' v1 = tcode ). " Sin autorización para la transacción &1
        return.
    endtry.
    clear t_bdcdata.

    loop at t_msg reference into data(ref_msg).
      add_log( id = ref_msg->msgid
               no = ref_msg->msgnr
               ty = ref_msg->msgtyp
               v1 = ref_msg->msgv1
               v2 = ref_msg->msgv2
               v3 = ref_msg->msgv3
               v4 = ref_msg->msgv4 ).
    endloop.

    if s_ok_msg is not initial.
      " Con mensaje de éxito definido, solo cuenta que haya aparecido: muchas
      " transacciones terminan con SY-SUBRC 1001 aunque hayan grabado.
      ok = has_msg( id = s_ok_msg-id no = s_ok_msg-no ty = s_ok_msg-ty ).
      if ok = abap_false.
        add_log( id = 'ZCL_BDC' no = '001' ty = 'E' " No se obtuvo el mensaje esperado &1 &2 en la transacción &3
                 v1 = s_ok_msg-id v2 = s_ok_msg-no v3 = tcode ).
      endif.
    else.
      ok = xsdbool( subrc = 0 and has_error( ) = abap_false ).
      if ok = abap_false and has_error( ) = abap_false.
        add_log( id = 'ZCL_BDC' no = '002' ty = 'E' " La transacción &1 terminó con código de retorno &2
                 v1 = tcode v2 = |{ subrc }| ).
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
    data(fval_ext) = cond string( when fval is not initial then |{ fval }| ).
    if conv = abap_true and fval is not initial.
      try.
          fval_ext = zcl_ce=>output_string( input = fval waers = waers ).
        catch zcx_ce_t100.
          " Sin conversión posible se envía el valor tal cual
      endtry.
    endif.
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
      if ( id is not supplied or ref_msg->msgid  = id )
     and ( no is not supplied or ref_msg->msgnr  = no )
     and ( ty is not supplied or ref_msg->msgtyp = ty ).
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
    s_ok_msg-id = id.
    s_ok_msg-no = no.
    s_ok_msg-ty = ty.
  endmethod.
ENDCLASS.
