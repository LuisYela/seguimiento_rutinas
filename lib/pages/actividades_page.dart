import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'recordatorios_page.dart';
import '../services/notification_service.dart';
import 'metricas_page.dart';

class ActividadesPage extends StatefulWidget {
  final int rutinaId;
  final String rutinaNombre;

  const ActividadesPage({
    super.key,
    required this.rutinaId,
    required this.rutinaNombre,
  });

  @override
  State<ActividadesPage> createState() => _ActividadesPageState();
}

class _ActividadesPageState extends State<ActividadesPage> {
  List<Map<String, Object?>> actividades = [];
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarActividades();
  }

  Future<void> cargarActividades() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await AppDatabase.instance.obtenerActividades(
        widget.rutinaId,
      );

      if (!mounted) return;

      setState(() {
        actividades = resultado;
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

  Future<void> mostrarFormulario({Map<String, Object?>? actividad}) async {
    final formKey = GlobalKey<FormState>();

    final nombreAnterior = actividad?['nombre'] as String? ?? '';

    final descripcionAnterior = actividad?['descripcion'] as String? ?? '';

    String nombreIngresado = nombreAnterior;
    String descripcionIngresada = descripcionAnterior;

    try {
      final datos = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              actividad == null ? 'Nueva actividad' : 'Editar actividad',
            ),
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
                        hintText: 'Ej. Leer 30 minutos',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un nombre';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        nombreIngresado = (value ?? '').trim();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: descripcionAnterior,
                      maxLength: 250,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (value) {
                        descripcionIngresada = (value ?? '').trim();
                      },
                    ),
                  ],
                ),
              ),
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
                  if (formKey.currentState?.validate() != true) {
                    return;
                  }

                  formKey.currentState!.save();

                  Navigator.pop(dialogContext, {
                    'nombre': nombreIngresado,
                    'descripcion': descripcionIngresada,
                  });
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );

      // Si el usuario cancela o toca fuera
      // del formulario, no se guarda nada.
      if (datos == null || !mounted) return;

      if (actividad == null) {
        await AppDatabase.instance.insertarActividad(
          rutinaId: widget.rutinaId,
          nombre: datos['nombre']!,
          descripcion: datos['descripcion']!,
        );
      } else {
        await AppDatabase.instance.actualizarActividad(
          id: actividad['id'] as int,
          rutinaId: widget.rutinaId,
          nombre: datos['nombre']!,
          descripcion: datos['descripcion']!,
        );

        // Actualizar las notificaciones después de editar.
        await NotificationService.instance.sincronizarRecordatorios();
      }

      await cargarActividades();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actividad == null
                ? 'Actividad creada correctamente'
                : 'Actividad actualizada correctamente',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> confirmarEliminacion(Map<String, Object?> actividad) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('¿Deseas eliminar "${actividad['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await AppDatabase.instance.eliminarActividad(
        id: actividad['id'] as int,
        rutinaId: widget.rutinaId,
      );
      await NotificationService.instance.sincronizarRecordatorios();

      await cargarActividades();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Actividad eliminada')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  void abrirRecordatorios(Map<String, Object?> actividad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordatoriosPage(
          actividadId: actividad['id'] as int,
          actividadNombre: actividad['nombre'] as String,
        ),
      ),
    );
  }

  void abrirMetricas(Map<String, Object?> actividad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MetricasPage(
          rutinaIdInicial: widget.rutinaId,
          actividadIdInicial: actividad['id'] as int,
        ),
      ),
    );
  }

  Future<void> cambiarEstadoActividad(Map<String, Object?> actividad) async {
    final id = actividad['id'] as int;
    final estabaActiva = (actividad['activa'] as int? ?? 1) == 1;

    try {
      final filas = await AppDatabase.instance.cambiarEstadoActividad(
        id: id,
        rutinaId: widget.rutinaId,
        activa: !estabaActiva,
      );

      if (filas == 0) {
        throw StateError('Actividad no encontrada');
      }

      await cargarActividades();

      try {
        await NotificationService.instance.sincronizarRecordatorios();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Estado guardado, pero no se pudieron '
              'sincronizar las notificaciones: $e',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estabaActiva ? 'Actividad desactivada' : 'Actividad reactivada',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cambiar el estado: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.rutinaNombre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva actividad'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudieron cargar las actividades.'),
                  const SizedBox(height: 12),
                  Text(error!),
                  FilledButton(
                    onPressed: cargarActividades,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : actividades.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Esta rutina todavía no tiene actividades. '
                  'Presiona "Nueva actividad" para agregar una.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: actividades.length,
              itemBuilder: (context, index) {
                final actividad = actividades[index];
                final activa = (actividad['activa'] as int? ?? 1) == 1;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: activa
                          ? Colors.green.shade600
                          : Colors.orange.shade700,
                      width: 2.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.checklist_outlined),
                        title: Text(actividad['nombre'] as String),
                        subtitle: Text(
                          (actividad['descripcion'] as String).isEmpty
                              ? 'Sin descripción'
                              : actividad['descripcion'] as String,
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activa ? 'Activa' : 'Pausada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: activa
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              onSelected: (opcion) {
                                if (opcion == 'editar') {
                                  mostrarFormulario(actividad: actividad);
                                } else if (opcion == 'estado') {
                                  cambiarEstadoActividad(actividad);
                                } else if (opcion == 'eliminar') {
                                  confirmarEliminacion(actividad);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'estado',
                                  child: Text(
                                    activa ? 'Desactivar' : 'Reactivar',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => abrirRecordatorios(actividad),
                              icon: const Icon(Icons.notifications_outlined),
                              label: const Text('Recordatorios'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => abrirMetricas(actividad),
                              icon: const Icon(Icons.insights_outlined),
                              label: const Text('Métricas'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
