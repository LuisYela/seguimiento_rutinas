import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../services/notification_service.dart';
import 'cumplimiento_page.dart';
import 'historial_page.dart';

class RecordatoriosPage extends StatefulWidget {
  final int actividadId;
  final String actividadNombre;

  const RecordatoriosPage({
    super.key,
    required this.actividadId,
    required this.actividadNombre,
  });

  @override
  State<RecordatoriosPage> createState() => _RecordatoriosPageState();
}

class _RecordatoriosPageState extends State<RecordatoriosPage> {
  final dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  List<Map<String, Object?>> recordatorios = [];
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = await AppDatabase.instance.obtenerRecordatorios(
        widget.actividadId,
      );

      if (!mounted) return;

      setState(() {
        recordatorios = datos;
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

  String formatoHora(TimeOfDay hora) {
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay leerHora(String? valor) {
    if (valor == null) return TimeOfDay.now();

    final partes = valor.split(':');

    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  Future<void> formulario({Map<String, Object?>? recordatorio}) async {
    int diaSeleccionado = recordatorio?['dia_semana'] as int? ?? 1;

    TimeOfDay horaSeleccionada = leerHora(recordatorio?['hora'] as String?);

    final datos = await showDialog<(int, TimeOfDay)>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, actualizarDialogo) {
            return AlertDialog(
              title: Text(
                recordatorio == null
                    ? 'Nuevo recordatorio'
                    : 'Editar recordatorio',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: diaSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Día de la semana',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      7,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(dias[index]),
                      ),
                    ),
                    onChanged: (valor) {
                      if (valor != null) {
                        actualizarDialogo(() {
                          diaSeleccionado = valor;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(horaSeleccionada.format(context)),
                    onPressed: () async {
                      final hora = await showTimePicker(
                        context: context,
                        initialTime: horaSeleccionada,
                      );

                      if (hora != null && dialogContext.mounted) {
                        actualizarDialogo(() {
                          horaSeleccionada = hora;
                        });
                      }
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
                  onPressed: () {
                    Navigator.pop(dialogContext, (
                      diaSeleccionado,
                      horaSeleccionada,
                    ));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (datos == null) return;

    try {
      final dia = datos.$1;
      final hora = formatoHora(datos.$2);

      int recordatorioId;

      if (recordatorio == null) {
        recordatorioId = await AppDatabase.instance.insertarRecordatorio(
          actividadId: widget.actividadId,
          diaSemana: dia,
          hora: hora,
        );
      } else {
        recordatorioId = recordatorio['id'] as int;

        await AppDatabase.instance.actualizarRecordatorio(
          id: recordatorioId,
          actividadId: widget.actividadId,
          diaSemana: dia,
          hora: hora,
        );
      }

      // Solicitar los permisos de Android.
      final autorizado = await NotificationService.instance
          .solicitarPermisosProgramacion();

      if (autorizado) {
        // Actualizar las notificaciones de todos
        // los horarios guardados en SQLite.
        await NotificationService.instance.sincronizarRecordatorios();
      } else {
        // Si no tenemos permisos, evitamos
        // conservar una programación antigua.
        await NotificationService.instance.cancelarRecordatorio(recordatorioId);
      }

      await cargar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autorizado ? 'Horario guardado y notificación semanal programada.' : 'Horario guardado, pero faltan permisos para mostrar su notificación.',
          ),
        ),
      );
    } on DatabaseException catch (e) {
      if (!mounted) return;

      final duplicado = e.isUniqueConstraintError();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            duplicado
                ? 'Ya existe ese día y hora para esta actividad'
                : 'Error de base de datos: $e',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  Future<void> eliminar(Map<String, Object?> recordatorio) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recordatorio'),
        content: const Text('¿Deseas eliminar este horario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      final id = recordatorio['id'] as int;

      await AppDatabase.instance.eliminarRecordatorio(
        id: id,
        actividadId: widget.actividadId,
      );

      await NotificationService.instance.cancelarRecordatorio(id);

      await cargar();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Future<void> probarNotificacion() async {
    try {
      final permitido = await NotificationService.instance
          .solicitarPermisoNotificaciones();

      if (!permitido) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes permitir las notificaciones.')),
        );
        return;
      }

      await NotificationService.instance.mostrarPrueba();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> probarProgramacion() async {
    try {
      final permitido = await NotificationService.instance
          .solicitarPermisoNotificaciones();

      if (!permitido) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes permitir las notificaciones.')),
        );
        return;
      }

      final programado = await NotificationService.instance.programarPrueba();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            programado
                ? 'Notificación programada para dentro de un minuto.'
                : 'Debes autorizar las alarmas exactas en Android.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          IconButton(
            tooltip: 'Registrar cumplimiento',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CumplimientoPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ver historial',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      HistorialPage(actividadIdInicial: widget.actividadId),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => formulario(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar horario'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text('Error: $error'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  widget.actividadNombre,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (recordatorios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Esta actividad no tiene horarios. '
                      'Agrega el primero para comenzar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...recordatorios.map((recordatorio) {
                  final dia = recordatorio['dia_semana'] as int;
                  final hora = recordatorio['hora'] as String;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(dias[dia - 1]),
                      subtitle: Text(hora),
                      trailing: PopupMenuButton<String>(
                        onSelected: (opcion) {
                          if (opcion == 'editar') {
                            formulario(recordatorio: recordatorio);
                          } else if (opcion == 'eliminar') {
                            eliminar(recordatorio);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'editar', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'eliminar',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
