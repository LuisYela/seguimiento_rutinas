import 'package:flutter/material.dart';

import '../data/app_database.dart';

class CumplimientoPage extends StatefulWidget {
  const CumplimientoPage({super.key});

  @override
  State<CumplimientoPage> createState() => _CumplimientoPageState();
}

class _CumplimientoPageState extends State<CumplimientoPage> {
  DateTime fechaSeleccionada = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  List<Map<String, Object?>> actividades = [];
  bool cargando = true;
  bool guardando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarActividades();
  }

  String formatoFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Future<void> cargarActividades() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = await AppDatabase.instance.obtenerActividadesDelDia(
        fechaSeleccionada,
      );

      if (!mounted) return;

      setState(() {
        actividades = datos;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        cargando = false;
      });
    }
  }

  Future<void> seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (fecha == null || !mounted) return;

    setState(() {
      fechaSeleccionada = fecha;
    });

    await cargarActividades();
  }

  Future<void> registrarCumplimiento({
    required int recordatorioId,
    required String estado,
    String motivo = '',
  }) async {
    if (guardando) return;

    setState(() {
      guardando = true;
    });

    try {
      await AppDatabase.instance.guardarCumplimiento(
        recordatorioId: recordatorioId,
        fecha: fechaSeleccionada,
        estado: estado,
        motivo: motivo,
      );

      await cargarActividades();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estado == 'realizado'
                ? 'Actividad registrada como realizada'
                : 'Actividad registrada como omitida',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el cumplimiento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  Future<void> registrarOmision(Map<String, Object?> actividad) async {
    final motivoAnterior = actividad['estado'] == 'omitido'
        ? actividad['motivo'] as String? ?? ''
        : '';

    String motivoIngresado = motivoAnterior;

    final motivo = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Registrar actividad omitida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Por qué no realizaste '
                '${actividad['actividad_nombre']}?',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: motivoAnterior,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ej. Falta de tiempo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (valor) {
                  motivoIngresado = valor;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, motivoIngresado.trim());
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (motivo == null || !mounted) return;

    await registrarCumplimiento(
      recordatorioId: actividad['recordatorio_id'] as int,
      estado: 'omitido',
      motivo: motivo,
    );
  }

  Widget construirActividad(Map<String, Object?> actividad) {
    final estado = actividad['estado'] as String?;
    final motivo = actividad['motivo'] as String? ?? '';

    final realizada = estado == 'realizado';
    final omitida = estado == 'omitido';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              actividad['actividad_nombre'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Rutina: ${actividad['rutina_nombre']}'),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 6),
                Text('${actividad['hora']}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  realizada
                      ? Icons.check_circle
                      : omitida
                      ? Icons.cancel
                      : Icons.schedule,
                  color: realizada
                      ? Colors.green
                      : omitida
                      ? Colors.red
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  realizada
                      ? 'Realizada'
                      : omitida
                      ? 'Omitida'
                      : 'Pendiente',
                ),
              ],
            ),
            if (omitida && motivo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Motivo: $motivo'),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: guardando
                        ? null
                        : () => registrarCumplimiento(
                            recordatorioId: actividad['recordatorio_id'] as int,
                            estado: 'realizado',
                          ),
                    icon: const Icon(Icons.check),
                    label: const Text('Realizada'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: guardando
                        ? null
                        : () => registrarOmision(actividad),
                    icon: const Icon(Icons.close),
                    label: const Text('Omitida'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro diario')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: seleccionarFecha,
              icon: const Icon(Icons.calendar_month),
              label: Text('Fecha: ${formatoFecha(fechaSeleccionada)}'),
            ),
          ),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('Error: $error'))
                : actividades.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay actividades programadas '
                        'para esta fecha.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: actividades.map(construirActividad).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
