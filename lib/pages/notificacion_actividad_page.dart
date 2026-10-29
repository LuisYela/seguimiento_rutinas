import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'metricas_page.dart';

class NotificacionActividadPage extends StatefulWidget {
  final int recordatorioId;

  const NotificacionActividadPage({super.key, required this.recordatorioId});

  @override
  State<NotificacionActividadPage> createState() =>
      _NotificacionActividadPageState();
}

class _NotificacionActividadPageState extends State<NotificacionActividadPage> {
  Map<String, Object?>? detalle;
  Map<String, Object?>? cumplimiento;

  DateTime? fechaSeleccionada;
  bool cargando = true;
  bool guardando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarDetalle();
  }

  String formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  DateTime ultimaFechaProgramada(int diaSemana) {
    final ahora = DateTime.now();

    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final diferencia = (hoy.weekday - diaSemana + 7) % 7;

    return hoy.subtract(Duration(days: diferencia));
  }

  bool get puedeRegistrar {
    final datos = detalle;

    if (datos == null) return false;

    return datos['recordatorio_activo'] == 1 &&
        datos['actividad_activa'] == 1 &&
        datos['rutina_activa'] == 1;
  }

  Future<void> cargarDetalle() async {
    try {
      final datos = await AppDatabase.instance.obtenerDetalleRecordatorio(
        widget.recordatorioId,
      );

      if (!mounted) return;

      if (datos == null) {
        setState(() {
          cargando = false;
          error = 'Este recordatorio ya no existe.';
        });
        return;
      }

      final fecha = ultimaFechaProgramada(datos['dia_semana'] as int);

      final resultado = await AppDatabase.instance
          .obtenerCumplimientoRecordatorio(
            recordatorioId: widget.recordatorioId,
            fecha: fecha,
          );

      if (!mounted) return;

      setState(() {
        detalle = datos;
        fechaSeleccionada = fecha;
        cumplimiento = resultado;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  Future<void> seleccionarFecha() async {
    final datos = detalle;
    final fechaActual = fechaSeleccionada;

    if (datos == null || fechaActual == null) return;

    final diaSemana = datos['dia_semana'] as int;

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaActual,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      selectableDayPredicate: (fecha) => fecha.weekday == diaSemana,
    );

    if (fecha == null || !mounted) return;

    try {
      final resultado = await AppDatabase.instance
          .obtenerCumplimientoRecordatorio(
            recordatorioId: widget.recordatorioId,
            fecha: fecha,
          );

      if (!mounted) return;

      setState(() {
        fechaSeleccionada = fecha;
        cumplimiento = resultado;
      });
    } catch (e) {
      mostrarMensaje('No se pudo consultar la fecha: $e');
    }
  }

  void mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> guardarEstado({
    required String estado,
    String motivo = '',
  }) async {
    final fecha = fechaSeleccionada;

    if (fecha == null || guardando || !puedeRegistrar) {
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      await AppDatabase.instance.guardarCumplimiento(
        recordatorioId: widget.recordatorioId,
        fecha: fecha,
        estado: estado,
        motivo: motivo,
      );

      final resultado = await AppDatabase.instance
          .obtenerCumplimientoRecordatorio(
            recordatorioId: widget.recordatorioId,
            fecha: fecha,
          );

      if (!mounted) return;

      setState(() {
        cumplimiento = resultado;
      });

      mostrarMensaje('Cumplimiento guardado correctamente');
    } catch (e) {
      mostrarMensaje('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  Future<void> registrarOmision() async {
    final registro = cumplimiento;

    final motivoAnterior = registro != null && registro['estado'] == 'omitido'
        ? (registro['motivo'] as String? ?? '')
        : '';

    String motivo = motivoAnterior;

    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Actividad omitida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Puedes indicar por qué no realizaste '
              'esta actividad.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: motivoAnterior,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (texto) {
                motivo = texto;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, motivo.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado == null || !mounted) return;

    await guardarEstado(estado: 'omitido', motivo: resultado);
  }

  void abrirMetricas() {
    final datos = detalle;
    if (datos == null || !puedeRegistrar) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MetricasPage(
          rutinaIdInicial: datos['rutina_id'] as int,
          actividadIdInicial: datos['actividad_id'] as int,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datos = detalle;

    final estado = cumplimiento?['estado'] as String?;
    final motivo = cumplimiento?['motivo'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar actividad')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              ),
            )
          : datos == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  datos['actividad_nombre'] as String,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Rutina: ${datos['rutina_nombre']}'),
                Text('Hora programada: ${datos['hora']}'),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: seleccionarFecha,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Fecha: ${formatearFecha(fechaSeleccionada!)}'),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado: ${estado == 'realizado'
                              ? 'Realizada'
                              : estado == 'omitido'
                              ? 'Omitida'
                              : 'Pendiente'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (estado == 'omitido' && motivo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Motivo: $motivo'),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: guardando || !puedeRegistrar
                                  ? null
                                  : () => guardarEstado(estado: 'realizado'),
                              icon: const Icon(Icons.check),
                              label: const Text('Realizada'),
                            ),
                            OutlinedButton.icon(
                              onPressed: guardando || !puedeRegistrar
                                  ? null
                                  : registrarOmision,
                              icon: const Icon(Icons.close),
                              label: const Text('Omitida'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (!puedeRegistrar) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Esta rutina, actividad o recordatorio '
                    'está desactivado. No se pueden '
                    'registrar nuevos resultados.',
                  ),
                ],

                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: puedeRegistrar ? abrirMetricas : null,
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('Registrar métricas de la actividad'),
                ),
              ],
            ),
    );
  }
}
