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

Importar primero `zcl_ce` y `zcl_log`.

## Objetos del paquete

| Objeto | Tipo | Descripción |
|---|---|---|
| `ZCL_BDC` | Clase | Armado y ejecución del batch input |
| `ZCL_BDC` | Clase de mensajes | Mensajes propios de la clase (ver más abajo) |
| `ZBDC_DEMO1` | Programa | Demo: recorre una clase en `SE24` (ver *Demo*) |

## API

| Método | Descripción |
|---|---|
| `constructor( tcode, dismode, updmode, cattmode, defsize, racommit, nobinpt, nobiend, ref_log )` | Transacción y opciones de `CTU_PARAMS`. Por defecto: sin pantallas (`N`), actualización síncrona (`S`), tamaño de pantalla estándar. `ref_log` es opcional |
| `dynpro( program, dynpro )` | Agrega el inicio de una pantalla |
| `field( fnam, fval, conv, waers, maxlen )` | Agrega un campo. Con `conv = abap_true` (por defecto) el valor se pasa a formato externo con `zcl_ce=>output_string`: fechas, importes (con `waers`), cantidades y campos con rutina de conversión quedan como los teclearía el usuario; si la conversión falla se envía el valor tal cual. `maxlen` corta el valor a ese largo. Un valor inicial se envía vacío |
| `okcode( fcode )` | Agrega `BDC_OKCODE` |
| `cursor( fnam )` | Agrega `BDC_CURSOR` |
| `call( ) → ok` | Ejecuta la transacción (`WITH AUTHORITY-CHECK`), pasa todos sus mensajes al log y limpia los datos BDC para la siguiente ejecución |
| `set_ok_msg( id, no, ty )` | Define el mensaje que indica éxito (tipo `S` por defecto) |
| `has_msg( id, no, ty )` | Indica si la última ejecución dio un mensaje con esos datos; los parámetros omitidos no filtran |
| `has_error( )` | Indica si la última ejecución dio mensajes de tipo `E` o `A` |
| `get_messages( ) → tt_bdcmsgcoll` / `get_bdcdata( ) → tt_bdcdata` | Mensajes de la última ejecución / datos BDC pendientes |
| `set_log( ref_log )` | Asigna o cambia el log |
| `refresh( )` | Limpia datos BDC, mensajes y código de retorno. No toca el log |

`dynpro`, `field`, `okcode` y `cursor` devuelven la misma instancia, así que se pueden encadenar.

Atributos de solo lectura: `tcode`, `s_params` (`CTU_PARAMS`), `subrc` (`SY-SUBRC` de la última ejecución) y `ref_log`. Las constantes `c-dismode-*` y `c-updmode-*` nombran los modos. Los tipos `tt_bdcdata` y `tt_bdcmsgcoll` son tablas estándar de `BDCDATA` y `BDCMSGCOLL`.

## De una grabación SHDB a `zcl_bdc`

Cada línea de la grabación se traduce así:

| Grabación | `zcl_bdc` |
|---|---|
| Línea con programa, dynpro y `X` | `dynpro( program = ... dynpro = ... )` |
| `BDC_OKCODE` | `okcode( '...' )`, tal cual (incluido el `=` o `/` inicial) |
| `BDC_CURSOR` | `cursor( '...' )`. Necesario cuando el código de función actúa sobre la línea del cursor (doble clic, `=OO_PICKUP`, etc.); en otro caso se puede omitir |
| `BDC_SUBSCR` | Se puede omitir: solo informa qué subpantalla estaba activa |
| Campo con valor | `field( fnam = ... fval = ... )` |

- **Valores grabados:** ya están en formato externo (como se teclearon). Para pasarlos tal cual, usar `conv = abap_false`. Con variables del programa en formato interno (fechas, importes, números con `ALPHA`), dejar la conversión por defecto.
- **Índices de table control** (`CAMPO(01)`): se refieren a la línea visible, no a la fila de la tabla. Para llegar más abajo hay que paginar o usar la búsqueda de la transacción.
- **Pantallas que dependen del usuario:** una grabación refleja la configuración de quien la hizo (por ejemplo, el editor con el que abre `SE24`). Si cambia entre usuarios, conviene parametrizar esos pasos, como hace `ZBDC_DEMO1` con `p_srce`.
- **Variantes en pantallas de selección:** si la grabación carga una variante (`/EGET` y luego `=PICK` con el cursor en una línea de la lista de variantes, pantalla `SAPMSSY0 0120`), ese paso depende de la posición de la variante en la lista y cambia en cuanto se crea otra. Es más estable llenar directamente los campos que importan.
- **Reportes que terminan en una lista:** al ejecutar (`=ONLI`) el reporte muestra su lista y, sin más datos BDC, el batch input termina con `00 344`. Ese mensaje sirve como `set_ok_msg` para saber que el reporte llegó a ejecutarse; un error en la pantalla de selección corta antes y no lo emite.
- **Largo de los valores:** `BDCDATA-FVAL` tiene 132 caracteres; un valor más largo (por ejemplo, una ruta de archivo) se corta. Conviene validarlo antes de llamar.
- **Leer la grabación sin SHDB:** queda guardada como juego de datos de batch input: cabecera en `APQI` (`GROUPID` = nombre de la grabación) y una fila de `APQD` por pantalla.

## Cuándo `call( )` devuelve `abap_true`

- **Con `set_ok_msg`:** si la transacción emitió ese mensaje, sin importar `SY-SUBRC`. Muchas transacciones graban y luego terminan con `SY-SUBRC = 1001` (sin datos para la pantalla siguiente), así que el mensaje de éxito es la señal más confiable. Si no aparece, se agrega al log el error `ZCL_BDC 001`.
- **Sin `set_ok_msg`:** si `SY-SUBRC = 0` y no hubo mensajes de tipo `E` ni `A`. Si falla sin un mensaje de error de la transacción, se agrega `ZCL_BDC 002` con el código de retorno.
- **Sin autorización** para la transacción: devuelve `abap_false`, deja `subrc = 4` y agrega `ZCL_BDC 003`.

## Demo

`ZBDC_DEMO1` recorre una clase en `SE24` (solo consulta, no modifica datos). Está basado en la grabación SHDB `ZCL_BDC`:

| Pantalla | Acción |
|---|---|
| `SAPLSEOD 1000` | Nombre de la clase en `SEOCLASS-CLSNAME` y Visualizar (`=WB_DISPLAY`) |
| `SAPLSEO_CLASS_EDITOR 0400` | Solo si `SE24` abre el editor basado en fuente: cambia a basado en formulario (`=OO_TOGGLE_CB_MODE`) |
| `SAPLSEOD 2000` + `SAPLSEO_CLEDITOR 0200` | Por cada método: cursor en `DY_0253-CPDNAME(nn)`, doble clic (`=OO_PICKUP`) y volver (`/EWB_BACK`) |
| `SAPLSEOD 2000` → `0400` → `1000` | Volver (`=WB_BACK` / `/EWB_BACK`) hasta salir de `SE24` |

- Parámetros: clase (por defecto `ZCL_BDC`), cantidad de métodos a visualizar (1 a 10, son líneas visibles del table control), si `SE24` abre el editor basado en fuente (depende de la configuración del usuario), modo de visualización y, opcionalmente, objeto y subobjeto de SLG0 para grabar el log.
- Como el recorrido sale de la transacción, el éxito se decide por `SY-SUBRC = 0` sin mensajes de error; no hace falta `set_ok_msg`.
- Al final agrega una línea con el resultado y `SY-SUBRC` y muestra el log.

## Clase de mensajes `ZCL_BDC`

| N.º | Texto |
|---|---|
| 000 | `&1 &2 &3 &4` |
| 001 | No se obtuvo el mensaje esperado &1 &2 en la transacción &3 |
| 002 | La transacción &1 terminó con código de retorno &2 |
| 003 | Sin autorización para ejecutar la transacción &1 |

## Origen

Inspirada en `ZCL_UTL_BDC`. Cambios principales: usa `zcl_log` en lugar de `ZCL_UTL_MSG`, `zcl_ce` en lugar de `ZUTL_CONVERSION_EXIT_OUTPUT`, tipos tabla propios `tt_bdcdata` / `tt_bdcmsgcoll` (no todos los releases tienen `TAB_BDCDATA`), métodos encadenables, `call( )` devuelve un indicador de éxito y `CALL TRANSACTION` verifica autorización.
