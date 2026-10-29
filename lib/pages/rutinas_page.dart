import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'actividades_page.dart';
import '../services/notification_service.dart';

class RutinasPage extends StatefulWidget {
  const RutinasPage({super.key});

  @override
  State<RutinasPage> createState() => _RutinasPageState();
}

class _RutinasPageState extends State<RutinasPage> {
  List<Map<String, Object?>> rutinas = [];

  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarRutinas();
  }

  Future<void> cargarRutinas() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await AppDatabase.instance.obtenerRutinas();

      if (!mounted) return;

      setState(() {
        rutinas = resultado;
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

  Future<void> mostrarFormulario({Map<String, Object?>? rutina}) async {
    final formKey = GlobalKey<FormState>();

    final nombreAnterior = rutina?['nombre'] as String? ?? '';

    final descripcionAnterior = rutina?['descripcion'] as String? ?? '';

    String nombreIngresado = nombreAnterior;
    String descripcionIngresada = descripcionAnterior;

    try {
      final datos = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(rutina == null ? 'Crear rutina' : 'Editar rutina'),
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
                        labelText: 'Nombre de la rutina',
                        hintText: 'Ej. Rutina de estudio',
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
                        labelText: 'Descripción',
                        hintText: 'Describe tu objetivo (opcional)',
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

      // Si se cancela o se toca fuera
      // del formulario, no guardamos nada.
      if (datos == null || !mounted) return;

      if (rutina == null) {
        await AppDatabase.instance.insertarRutina(
          nombre: datos['nombre']!,
          descripcion: datos['descripcion']!,
        );
      } else {
        await AppDatabase.instance.actualizarRutina(
          id: rutina['id'] as int,
          nombre: datos['nombre']!,
          descripcion: datos['descripcion']!,
        );

        // Sincronizar los recordatorios asociados a la rutina.
        await NotificationService.instance.sincronizarRecordatorios();
      }

      await cargarRutinas();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rutina == null
                ? 'Rutina creada correctamente'
                : 'Rutina actualizada correctamente',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la rutina: $e')),
      );
    }
  }

  Future<void> confirmarEliminacion(Map<String, Object?> rutina) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar rutina'),
          content: Text('¿Deseas eliminar "${rutina['nombre']}"?'),
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
        );
      },
    );

    if (confirmado != true) return;

    try {
      await AppDatabase.instance.eliminarRutina(rutina['id'] as int);
      await NotificationService.instance.sincronizarRecordatorios();
      await cargarRutinas();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rutina eliminada')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la rutina: $e')),
      );
    }
  }

  Future<void> cambiarEstadoRutina(Map<String, Object?> rutina) async {
    final id = rutina['id'] as int;
    final estabaActiva = (rutina['activa'] as int? ?? 1) == 1;

    try {
      final filas = await AppDatabase.instance.cambiarEstadoRutina(
        id: id,
        activa: !estabaActiva,
      );

      if (filas == 0) {
        throw StateError('Rutina no encontrada');
      }

      await cargarRutinas();

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
            estabaActiva ? 'Rutina desactivada' : 'Rutina reactivada',
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva rutina'),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar las rutinas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: cargarRutinas,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : rutinas.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 64,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no tienes rutinas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea una rutina para comenzar '
                      'a organizar tus actividades.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => mostrarFormulario(),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear mi primera rutina'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: rutinas.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final rutina = rutinas[index];

                final nombre = rutina['nombre'] as String;
                final descripcion = rutina['descripcion'] as String;
                final activa = (rutina['activa'] as int? ?? 1) == 1;

                return Card(
                  elevation: 0,
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: activa
                          ? Colors.green.shade600
                          : Colors.orange.shade700,
                      width: 2.2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActividadesPage(
                            rutinaId: rutina['id'] as int,
                            rutinaNombre: rutina['nombre'] as String,
                          ),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: colors.secondaryContainer,
                      child: Icon(
                        Icons.event_note,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      descripcion.isEmpty ? 'Sin descripción' : descripcion,
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
                          tooltip: 'Opciones',
                          onSelected: (opcion) {
                            if (opcion == 'editar') {
                              mostrarFormulario(rutina: rutina);
                            } else if (opcion == 'estado') {
                              cambiarEstadoRutina(rutina);
                            } else if (opcion == 'eliminar') {
                              confirmarEliminacion(rutina);
                            }
                          },
                          itemBuilder: (_) => [
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
                            PopupMenuItem(
                              value: 'estado',
                              child: Row(
                                children: [
                                  Icon(
                                    activa
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(activa ? 'Desactivar' : 'Reactivar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'eliminar',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline),
                                  SizedBox(width: 8),
                                  Text('Eliminar'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
