import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'grafica_metrica_page.dart';

class MetricasPage extends StatefulWidget {
  final int? rutinaIdInicial;
  final int? actividadIdInicial;

  const MetricasPage({
    super.key,
    this.rutinaIdInicial,
    this.actividadIdInicial,
  });

  @override
  State<MetricasPage> createState() => _MetricasPageState();
}

class _MetricasPageState extends State<MetricasPage> {
  List<Map<String, Object?>> rutinas = [];
  List<Map<String, Object?>> actividades = [];
  List<Map<String, Object?>> metricas = [];

  int? rutinaSeleccionada;
  int? actividadSeleccionada;

  bool cargandoRutinas = true;
  bool cargandoActividades = false;
  bool cargandoMetricas = false;
  bool _seleccionInicialAplicada = false;
  bool mostrarDesactivadas = false;

  @override
  void initState() {
    super.initState();
    cargarRutinas();
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String formatearFecha(String fecha) {
    final partes = fecha.split('-');
    if (partes.length != 3) return fecha;

    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  String fechaSQLite(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }

  double? convertirNumero(String texto) {
    return double.tryParse(texto.trim().replaceAll(',', '.'));
  }

  String mostrarNumero(num numero) {
    return numero.toString().replaceFirst(RegExp(r'\.0$'), '');
  }

  Future<void> cargarRutinas() async {
    try {
      final datos = await AppDatabase.instance.obtenerRutinas();

      if (!mounted) return;

      setState(() {
        rutinas = datos;
        cargandoRutinas = false;
      });
      final idInicial = widget.rutinaIdInicial;

      if (idInicial != null && datos.any((r) => r['id'] == idInicial)) {
        seleccionarRutina(idInicial);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargandoRutinas = false;
      });

      mostrarMensaje('Error al cargar rutinas: $e');
    }
  }

  Future<void> cargarActividades(int rutinaId) async {
    setState(() {
      cargandoActividades = true;
    });

    try {
      final datos = await AppDatabase.instance.obtenerActividades(rutinaId);

      if (!mounted || rutinaSeleccionada != rutinaId) {
        return;
      }

      final seleccionarInicial =
          !_seleccionInicialAplicada &&
          widget.rutinaIdInicial == rutinaId &&
          widget.actividadIdInicial != null &&
          datos.any((a) => a['id'] == widget.actividadIdInicial);

      setState(() {
        actividades = datos;
        cargandoActividades = false;

        if (seleccionarInicial) {
          actividadSeleccionada = widget.actividadIdInicial;
          _seleccionInicialAplicada = true;
        }
      });

      await cargarMetricas();
    } catch (e) {
      if (!mounted || rutinaSeleccionada != rutinaId) {
        return;
      }

      setState(() {
        cargandoActividades = false;
      });

      mostrarMensaje('Error al cargar actividades: $e');
    }
  }

  Future<void> cargarMetricas() async {
    final rutinaId = rutinaSeleccionada;
    final actividadId = actividadSeleccionada;
    final desactivadas = mostrarDesactivadas;

    if (rutinaId == null) return;

    setState(() {
      cargandoMetricas = true;
    });

    try {
      final datos = actividadId == null
          ? await AppDatabase.instance.obtenerMetricasPorRutina(
              rutinaId,
              soloDesactivadas: desactivadas,
            )
          : await AppDatabase.instance.obtenerMetricas(
              actividadId: actividadId,
              soloDesactivadas: desactivadas,
            );

      if (!mounted ||
          rutinaSeleccionada != rutinaId ||
          actividadSeleccionada != actividadId ||
          mostrarDesactivadas != desactivadas) {
        return;
      }

      setState(() {
        metricas = datos;
        cargandoMetricas = false;
      });
    } catch (e) {
      if (!mounted ||
          rutinaSeleccionada != rutinaId ||
          actividadSeleccionada != actividadId ||
          mostrarDesactivadas != desactivadas) {
        return;
      }

      setState(() {
        cargandoMetricas = false;
      });

      mostrarMensaje('Error al cargar métricas: $e');
    }
  }

  void seleccionarRutina(int? id) {
    setState(() {
      rutinaSeleccionada = id;
      actividadSeleccionada = null;
      actividades = [];
      metricas = [];
      cargandoActividades = false;
      cargandoMetricas = false;
    });

    if (id != null) {
      cargarActividades(id);
    }
  }

  void seleccionarActividad(int? id) {
    setState(() {
      actividadSeleccionada = id;
      metricas = [];
      cargandoMetricas = false;
    });

    if (rutinaSeleccionada != null) {
      cargarMetricas();
    }
  }

  Future<void> crearMetrica() async {
    final actividadId = actividadSeleccionada;
    if (actividadId == null) return;

    final formKey = GlobalKey<FormState>();

    String nombre = '';
    String unidad = '';
    double? minimo;
    double? maximo;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nueva métrica'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej. Motivación',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa un nombre';
                      }
                      return null;
                    },
                    onSaved: (valor) {
                      nombre = (valor ?? '').trim();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Unidad (opcional)',
                      hintText: 'Ej. minutos, horas',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (valor) {
                      unidad = (valor ?? '').trim();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor mínimo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return null;
                      }

                      return convertirNumero(valor) == null
                          ? 'Ingresa un número válido'
                          : null;
                    },
                    onSaved: (valor) {
                      minimo = valor == null || valor.trim().isEmpty
                          ? null
                          : convertirNumero(valor);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor máximo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return null;
                      }

                      return convertirNumero(valor) == null
                          ? 'Ingresa un número válido'
                          : null;
                    },
                    onSaved: (valor) {
                      maximo = valor == null || valor.trim().isEmpty
                          ? null
                          : convertirNumero(valor);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                formKey.currentState!.save();

                if (minimo != null && maximo != null && minimo! > maximo!) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El mínimo no puede ser mayor '
                        'que el máximo.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (guardar != true || !mounted) return;

    try {
      await AppDatabase.instance.insertarMetrica(
        actividadId: actividadId,
        nombre: nombre,
        unidad: unidad,
        valorMinimo: minimo,
        valorMaximo: maximo,
      );

      if (actividadSeleccionada == actividadId) {
        await cargarMetricas();
      }

      mostrarMensaje('Métrica creada correctamente');
    } catch (e) {
      mostrarMensaje('No se pudo crear la métrica: $e');
    }
  }

  Future<void> editarMetrica(Map<String, Object?> metrica) async {
    final formKey = GlobalKey<FormState>();

    final nombreAnterior = metrica['nombre'] as String;
    final unidadAnterior = metrica['unidad'] as String;

    final minimoAnterior = (metrica['valor_minimo'] as num?)?.toDouble();

    final maximoAnterior = (metrica['valor_maximo'] as num?)?.toDouble();

    String nombre = nombreAnterior;
    String unidad = unidadAnterior;
    double? minimo = minimoAnterior;
    double? maximo = maximoAnterior;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar métrica'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: nombreAnterior,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa un nombre';
                      }
                      return null;
                    },
                    onSaved: (valor) {
                      nombre = (valor ?? '').trim();
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: unidadAnterior,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Unidad (opcional)',
                      hintText: 'Ej. minutos, horas',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (valor) {
                      unidad = (valor ?? '').trim();
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: minimoAnterior == null
                        ? ''
                        : mostrarNumero(minimoAnterior),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor mínimo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (texto) {
                      if (texto == null || texto.trim().isEmpty) {
                        return null;
                      }

                      final numero = convertirNumero(texto);

                      if (numero == null || !numero.isFinite) {
                        return 'Ingresa un número válido';
                      }

                      return null;
                    },
                    onSaved: (texto) {
                      minimo = texto == null || texto.trim().isEmpty
                          ? null
                          : convertirNumero(texto);
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: maximoAnterior == null
                        ? ''
                        : mostrarNumero(maximoAnterior),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor máximo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (texto) {
                      if (texto == null || texto.trim().isEmpty) {
                        return null;
                      }

                      final numero = convertirNumero(texto);

                      if (numero == null || !numero.isFinite) {
                        return 'Ingresa un número válido';
                      }

                      return null;
                    },
                    onSaved: (texto) {
                      maximo = texto == null || texto.trim().isEmpty
                          ? null
                          : convertirNumero(texto);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                formKey.currentState!.save();

                if (minimo != null && maximo != null && minimo! > maximo!) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El mínimo no puede ser '
                        'mayor que el máximo.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (guardar != true || !mounted) return;

    try {
      // Advertir si se modifica la unidad
      // de una métrica con valores registrados.
      if (unidad != unidadAnterior) {
        final valores = await AppDatabase.instance.obtenerValoresMetrica(
          metrica['id'] as int,
        );

        if (!mounted) return;

        if (valores.isNotEmpty) {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Cambio de unidad'),
              content: const Text(
                'Esta métrica ya tiene valores registrados. '
                'Cambiar su unidad no convertirá '
                'automáticamente esos valores. '
                '¿Deseas continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );

          if (confirmar != true || !mounted) return;
        }
      }

      await AppDatabase.instance.actualizarMetrica(
        id: metrica['id'] as int,
        nombre: nombre,
        unidad: unidad,
        valorMinimo: minimo,
        valorMaximo: maximo,
      );

      await cargarMetricas();

      mostrarMensaje('Métrica actualizada correctamente');
    } catch (e) {
      mostrarMensaje('No se pudo actualizar: $e');
    }
  }

  Future<void> registrarValor(Map<String, Object?> metrica) async {
    final metricaId = metrica['id'] as int;

    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (fecha == null || !mounted) return;

    List<Map<String, Object?>> valores;

    try {
      valores = await AppDatabase.instance.obtenerValoresMetrica(metricaId);
    } catch (e) {
      mostrarMensaje('Error al consultar valores: $e');
      return;
    }

    if (!mounted) return;

    final fechaTexto = fechaSQLite(fecha);
    double? valorAnterior;
    String descripcionAnterior = '';

    for (final registro in valores) {
      if (registro['fecha'] == fechaTexto) {
        valorAnterior = (registro['valor'] as num).toDouble();
        descripcionAnterior = registro['descripcion'] as String? ?? '';
        break;
      }
    }

    final minimo = (metrica['valor_minimo'] as num?)?.toDouble();
    final maximo = (metrica['valor_maximo'] as num?)?.toDouble();

    final formKey = GlobalKey<FormState>();
    double valorIngresado = 0;
    String descripcionIngresada = descripcionAnterior;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(metrica['nombre'] as String),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fecha: ${formatearFecha(fechaTexto)}'),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: valorAnterior == null
                        ? ''
                        : mostrarNumero(valorAnterior),
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Valor',
                      suffixText: metrica['unidad'] as String,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (texto) {
                      final numero = convertirNumero(texto ?? '');
                      if (numero == null || !numero.isFinite) {
                        return 'Ingresa un número válido';
                      }
                      if (minimo != null && numero < minimo) {
                        return 'Mínimo: $minimo';
                      }
                      if (maximo != null && numero > maximo) {
                        return 'Máximo: $maximo';
                      }
                      return null;
                    },
                    onSaved: (texto) {
                      valorIngresado = convertirNumero(texto ?? '')!;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: descripcionAnterior,
                    maxLength: 250,
                    maxLines: 3,
                    minLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Ej. Hoy estaba cansado, pero terminé.',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (texto) {
                      descripcionIngresada = (texto ?? '').trim();
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                formKey.currentState!.save();
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (guardar != true || !mounted) return;

    try {
      await AppDatabase.instance.guardarValorMetrica(
        metricaId: metricaId,
        fecha: fecha,
        valor: valorIngresado,
        descripcion: descripcionIngresada,
      );
      mostrarMensaje('Valor y descripción guardados correctamente');
    } catch (e) {
      mostrarMensaje('No se pudo guardar el valor: $e');
    }
  }

  Future<void> verValores(Map<String, Object?> metrica) async {
    try {
      final valores = await AppDatabase.instance.obtenerValoresMetrica(
        metrica['id'] as int,
      );

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (dialogContext) {
          final colores = Theme.of(dialogContext).colorScheme;

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(dialogContext).height * 0.65,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Registros: ${metrica['nombre']}',
                            style: Theme.of(dialogContext).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.show_chart),
                          label: const Text('Ir a gráficas'),
                          onPressed: () {
                            Navigator.of(dialogContext).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GraficaMetricaPage(metrica: metrica),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: valores.isEmpty
                        ? const Center(
                            child: Text('Todavía no hay valores registrados.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: valores.length,
                            itemBuilder: (context, index) {
                              final registro = valores[index];

                              final esExtra =
                                  registro['fuera_programacion'] == 1;

                              final fecha = formatearFecha(
                                registro['fecha'] as String,
                              );

                              final numero = mostrarNumero(
                                registro['valor'] as num,
                              );

                              final unidad = metrica['unidad'] as String;
                              final descripcion =
                                  (registro['descripcion'] as String? ?? '')
                                      .trim();

                              final mensaje =
                                  '¡Buen registro adicional! '
                                  'Aunque esta actividad no '
                                  'estaba programada para ese '
                                  'día, registraste un valor '
                                  'para una de sus métricas.';

                              return Tooltip(
                                message: esExtra
                                    ? mensaje
                                    : 'Registro de métrica',
                                triggerMode: TooltipTriggerMode.longPress,
                                child: Card(
                                  color: esExtra
                                      ? colores.tertiaryContainer
                                      : null,
                                  child: ListTile(
                                    leading: Icon(
                                      esExtra
                                          ? Icons.star
                                          : Icons.calendar_today,
                                      color: esExtra
                                          ? colores.onTertiaryContainer
                                          : null,
                                    ),
                                    title: Text(
                                      fecha,
                                      style: TextStyle(
                                        decoration: esExtra
                                            ? TextDecoration.underline
                                            : TextDecoration.none,
                                        fontWeight: esExtra
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: esExtra || descripcion.isNotEmpty
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (esExtra)
                                                const Text(
                                                  'Registro adicional',
                                                ),
                                              if (descripcion.isNotEmpty)
                                                Text(
                                                  descripcion,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          )
                                        : null,
                                    trailing: Text(
                                      unidad.isEmpty
                                          ? numero
                                          : '$numero $unidad',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      mostrarMensaje('Error al consultar registros: $e');
    }
  }

  Future<void> desactivarMetrica(Map<String, Object?> metrica) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desactivar métrica'),
        content: Text(
          '¿Deseas desactivar "${metrica['nombre']}"? '
          'Sus valores históricos se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await AppDatabase.instance.desactivarMetrica(metrica['id'] as int);

      await cargarMetricas();

      mostrarMensaje('Métrica desactivada');
    } catch (e) {
      mostrarMensaje('Error al desactivar: $e');
    }
  }

  Widget construirMetrica(Map<String, Object?> metrica) {
    final minimo = metrica['valor_minimo'] as num?;
    final maximo = metrica['valor_maximo'] as num?;
    final unidad = metrica['unidad'] as String;
    final desactivada = (metrica['activa'] as int? ?? 1) == 0;

    String rango = 'Sin límites';

    if (minimo != null && maximo != null) {
      rango = '${mostrarNumero(minimo)} a ${mostrarNumero(maximo)}';
    } else if (minimo != null) {
      rango = 'Desde ${mostrarNumero(minimo)}';
    } else if (maximo != null) {
      rango = 'Hasta ${mostrarNumero(maximo)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrica['nombre'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de métrica',
                  onSelected: (opcion) {
                    if (opcion == 'editar') {
                      editarMetrica(metrica);
                    } else if (opcion == 'desactivar') {
                      desactivarMetrica(metrica);
                    } else if (opcion == 'reactivar') {
                      reactivarMetrica(metrica);
                    }
                  },
                  itemBuilder: (_) => [
                    if (desactivada)
                      const PopupMenuItem(
                        value: 'reactivar',
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_outline),
                            SizedBox(width: 8),
                            Text('Reactivar'),
                          ],
                        ),
                      )
                    else ...[
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'desactivar',
                        child: Row(
                          children: [
                            Icon(Icons.pause_circle_outline),
                            SizedBox(width: 8),
                            Text('Desactivar'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (actividadSeleccionada == null) ...[
              Text(
                'Actividad: ${metrica['actividad_nombre']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
            ],
            Text('Unidad: ${unidad.isEmpty ? "Sin unidad" : unidad}'),
            Text('Rango: $rango'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: desactivada ? null : () => registrarValor(metrica),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Registrar valor'),
                ),
                OutlinedButton.icon(
                  onPressed: () => verValores(metrica),
                  icon: const Icon(Icons.history),
                  label: const Text('Ver registros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> reactivarMetrica(Map<String, Object?> metrica) async {
    try {
      final filas = await AppDatabase.instance.reactivarMetrica(
        metrica['id'] as int,
      );

      if (filas == 0) {
        throw StateError('Métrica no encontrada');
      }

      await cargarMetricas();

      mostrarMensaje('Métrica reactivada correctamente');
    } catch (e) {
      mostrarMensaje('No se pudo reactivar la métrica: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas personalizadas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar métricas',
            onPressed: rutinaSeleccionada == null ? null : cargarMetricas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: actividadSeleccionada == null || mostrarDesactivadas
            ? null
            : crearMetrica,
        icon: const Icon(Icons.add),
        label: const Text('Nueva métrica'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  key: ValueKey('rutina-$rutinaSeleccionada'),
                  initialValue: rutinaSeleccionada,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rutina',
                    prefixIcon: Icon(Icons.calendar_month),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Seleccionar rutina'),
                    ),
                    ...rutinas.map(
                      (r) => DropdownMenuItem<int>(
                        value: r['id'] as int,
                        child: Text(
                          r['nombre'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: cargandoRutinas ? null : seleccionarRutina,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    'actividad-$rutinaSeleccionada-'
                    '$actividadSeleccionada',
                  ),
                  initialValue: actividadSeleccionada,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Actividad',
                    prefixIcon: Icon(Icons.task_alt),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Todas las actividades'),
                    ),
                    ...actividades.map(
                      (a) => DropdownMenuItem<int>(
                        value: a['id'] as int,
                        child: Text(
                          a['nombre'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: rutinaSeleccionada == null || cargandoActividades
                      ? null
                      : seleccionarActividad,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Activas'),
                        icon: Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Desactivadas'),
                        icon: Icon(Icons.pause_circle_outline),
                      ),
                    ],
                    selected: {mostrarDesactivadas},
                    onSelectionChanged: (seleccion) {
                      setState(() {
                        mostrarDesactivadas = seleccion.first;
                        metricas = [];
                      });

                      if (rutinaSeleccionada != null) {
                        cargarMetricas();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: cargandoActividades || cargandoMetricas
                ? const Center(child: CircularProgressIndicator())
                : rutinaSeleccionada == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Selecciona una rutina '
                        'para consultar tus métricas.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : metricas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay métricas registradas '
                        'para esta selección.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: metricas.length,
                    itemBuilder: (context, index) {
                      return construirMetrica(metricas[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
