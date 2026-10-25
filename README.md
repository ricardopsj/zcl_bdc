# zcl_bdc — Batch input con CALL TRANSACTION

Clase para armar y ejecutar batch input (`CALL TRANSACTION ... USING`) sin manejar a mano la tabla `BDCDATA`. Los mensajes de la transacción quedan en un log de aplicación de [zcl_log](https://github.com/ricardopsj/zcl_log).

```abap
data(ref_log) = new zcl_log( ).
ref_log->set_object( 'ZFI' ).
ref_log->set_subobject( 'CARGA' ).
ref_log->create( ).

data(ref_bdc) = new zcl_bdc( tcode   = 'FB01'
                             ref_log = ref_log ).

ref_bdc->dynpro( program = 'SAPMF05A' dynpro = '0100'
      )->field( fnam = 'BKPF-BLDAT' fval = lv_fecha       " tipo D: se convierte a formato externo
      )->field( fnam = 'BKPF-BLART' fval = 'SA'
      )->field( fnam = 'BKPF-WAERS' fval = lv_moneda
      )->okcode( '/00' ).
" ... más pantallas ...

ref_bdc->set_ok_msg( id = 'F5' no = '312' ).   " Documento &1 se contabilizó en sociedad &2

if ref_bdc->call( ).
  " grabó
endif.

ref_log->save( ).
ref_log->display( ).
```

## Instalación

Importar con [abapGit](https://abapgit.org). Requiere ABAP 7.40 o superior.

Dependencias:

- [zcl_log](https://github.com/ricardopsj/zcl_log): log de aplicación.
- [zcl_ce](https://github.com/ricardopsj/zcl_ce): conversión de valores a formato externo. `zcl_log` ya depende de ella.

## API

| Método | Descripción |
|---|---|
| `constructor( tcode, dismode, updmode, cattmode, defsize, racommit, nobinpt, nobiend, ref_log )` | Transacción y opciones de `CTU_PARAMS`. Por defecto: sin pantallas (`N`), actualización síncrona (`S`), tamaño de pantalla estándar. `ref_log` es opcional |
| `dynpro( program, dynpro )` | Agrega el inicio de una pantalla |
| `field( fnam, fval, conv, waers, maxlen )` | Agrega un campo. Con `conv = abap_true` (por defecto) el valor se pasa a formato externo con `zcl_ce=>output_string`: fechas, importes (con `waers`), cantidades y campos con rutina de conversión quedan como los teclearía el usuario. `maxlen` corta el valor a ese largo. Un valor inicial se envía vacío |
| `okcode( fcode )` | Agrega `BDC_OKCODE` |
| `cursor( fnam )` | Agrega `BDC_CURSOR` |
| `call( ) → ok` | Ejecuta la transacción (`WITH AUTHORITY-CHECK`), pasa todos sus mensajes al log y limpia los datos BDC para la siguiente ejecución |
| `set_ok_msg( id, no, ty )` | Define el mensaje que indica éxito (tipo `S` por defecto) |
| `has_msg( id, no, ty )` | Indica si la última ejecución dio un mensaje con esos datos; los parámetros omitidos no filtran |
| `has_error( )` | Indica si la última ejecución dio mensajes de tipo `E` o `A` |
| `get_messages( )` / `get_bdcdata( )` | Mensajes de la última ejecución / datos BDC pendientes |
| `set_log( ref_log )` | Asigna o cambia el log |
| `refresh( )` | Limpia datos BDC, mensajes y código de retorno. No toca el log |

`dynpro`, `field`, `okcode` y `cursor` devuelven la misma instancia, así que se pueden encadenar.

Atributos de solo lectura: `tcode`, `s_params` (`CTU_PARAMS`), `subrc` (`SY-SUBRC` de la última ejecución) y `ref_log`. Las constantes `c-dismode-*` y `c-updmode-*` nombran los modos.

## Cuándo `call( )` devuelve `abap_true`

- **Con `set_ok_msg`:** si la transacción emitió ese mensaje, sin importar `SY-SUBRC`. Muchas transacciones graban y luego terminan con `SY-SUBRC = 1001` (sin datos para la pantalla siguiente), así que el mensaje de éxito es la señal más confiable. Si no aparece, se agrega al log el error `ZCL_BDC 001`.
- **Sin `set_ok_msg`:** si `SY-SUBRC = 0` y no hubo mensajes de tipo `E` ni `A`. Si falla sin un mensaje de error de la transacción, se agrega `ZCL_BDC 002` con el código de retorno.
- **Sin autorización** para la transacción: devuelve `abap_false`, deja `subrc = 4` y agrega `ZCL_BDC 003`.

## Clase de mensajes `ZCL_BDC`

| N.º | Texto |
|---|---|
| 000 | `&1 &2 &3 &4` |
| 001 | No se obtuvo el mensaje esperado &1 &2 en la transacción &3 |
| 002 | La transacción &1 terminó con código de retorno &2 |
| 003 | Sin autorización para ejecutar la transacción &1 |

## Origen

Inspirada en `ZCL_UTL_BDC`. Cambios principales: usa `zcl_log` en lugar de `ZCL_UTL_MSG`, `zcl_ce` en lugar de `ZUTL_CONVERSION_EXIT_OUTPUT`, tipos estándar `TAB_BDCDATA` / `TAB_BDCMSGCOLL`, métodos encadenables, `call( )` devuelve un indicador de éxito y `CALL TRANSACTION` verifica autorización.
