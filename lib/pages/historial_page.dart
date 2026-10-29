import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'grafica_cumplimiento_page.dart';

class HistorialPage extends StatefulWidget {
  final int actualizacion;
  final int? actividadIdInicial;

  const HistorialPage({
    super.key,
    this.actualizacion = 0,
    this.actividadIdInicial,
  });

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  List<Map<String, Object?>> registros = [];

  bool cargando = true;
  String? error;

  // Filtros seleccionados.
  String filtroEstado = 'todos';
  DateTime? fechaSeleccionada;
  String? rutinaSeleccionada;
  String? actividadSeleccionada;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  @override
  void didUpdateWidget(covariant HistorialPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.actualizacion != oldWidget.actualizacion) {
      cargarHistorial();
    }
  }

  Future<void> cargarHistorial() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = widget.actividadIdInicial == null
          ? await AppDatabase.instance.obtenerHistorialCumplimiento()
          : await AppDatabase.instance.obtenerHistorialActividad(
              widget.actividadIdInicial!,
            );

      if (!mounted) return;

      setState(() {
        registros = datos;
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

  String formatearFecha(String fecha) {
    final partes = fecha.split('-');

    if (partes.length != 3) return fecha;

    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  String fechaSQLite(DateTime fecha) {
    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    return '$anio-$mes-$dia';
  }

  // Obtener rutinas que tienen registros históricos.
  List<String> get rutinasDisponibles {
    return registros.map((r) => r['rutina_nombre'] as String).toSet().toList()
      ..sort();
  }

  // Mostrar las actividades correspondientes
  // a la rutina seleccionada.
  List<String> get actividadesDisponibles {
    if (rutinaSeleccionada == null) {
      return [];
    }

    return registros
        .where((r) => r['rutina_nombre'] == rutinaSeleccionada)
        .map((r) => r['actividad_nombre'] as String)
        .toSet()
        .toList()
      ..sort();
  }

  // Aplicar todos los filtros simultáneamente.
  List<Map<String, Object?>> get registrosFiltrados {
    return registros.where((registro) {
      if (filtroEstado != 'todos' && registro['estado'] != filtroEstado) {
        return false;
      }

      if (fechaSeleccionada != null &&
          registro['fecha'] != fechaSQLite(fechaSeleccionada!)) {
        return false;
      }

      if (rutinaSeleccionada != null &&
          registro['rutina_nombre'] != rutinaSeleccionada) {
        return false;
      }

      if (actividadSeleccionada != null &&
          registro['actividad_nombre'] != actividadSeleccionada) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (fecha == null || !mounted) return;

    setState(() {
      fechaSeleccionada = fecha;
    });
  }

  void limpiarFiltros() {
    setState(() {
      filtroEstado = 'todos';
      fechaSeleccionada = null;
      rutinaSeleccionada = null;
      actividadSeleccionada = null;
    });
  }

  Widget construirFiltros() {
    final rutinas = rutinasDisponibles;
    final actividades = actividadesDisponibles;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILTRO DE FECHA
          const Text('Fecha'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    fechaSeleccionada == null
                        ? 'Todas las fechas'
                        : formatearFecha(fechaSQLite(fechaSeleccionada!)),
                  ),
                  onPressed: seleccionarFecha,
                ),
              ),
              IconButton(
                tooltip: 'Quitar filtro de fecha',
                onPressed: fechaSeleccionada == null
                    ? null
                    : () {
                        setState(() {
                          fechaSeleccionada = null;
                        });
                      },
                icon: const Icon(Icons.clear),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // FILTRO DE RUTINA
          DropdownButtonFormField<String>(
            key: ValueKey('rutina-${rutinaSeleccionada ?? "todas"}'),
            initialValue: rutinaSeleccionada,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Rutina',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.list_alt),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Todas las rutinas'),
              ),
              ...rutinas.map(
                (nombre) => DropdownMenuItem<String>(
                  value: nombre,
                  child: Text(nombre, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (valor) {
              setState(() {
                rutinaSeleccionada = valor;

                // Al cambiar de rutina, reiniciamos
                // el filtro de actividad.
                actividadSeleccionada = null;
              });
            },
          ),

          const SizedBox(height: 12),

          // FILTRO DE ACTIVIDAD
          DropdownButtonFormField<String>(
            key: ValueKey(
              'actividad-${rutinaSeleccionada ?? "todas"}-'
              '${actividadSeleccionada ?? "todas"}',
            ),
            initialValue: actividadSeleccionada,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actividad',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.task_alt),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Todas las actividades'),
              ),
              ...actividades.map(
                (nombre) => DropdownMenuItem<String>(
                  value: nombre,
                  child: Text(nombre, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: rutinaSeleccionada == null
                ? null
                : (valor) {
                    setState(() {
                      actividadSeleccionada = valor;
                    });
                  },
          ),

          const SizedBox(height: 12),

          // FILTRO DE ESTADO
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos')),
                ButtonSegment(value: 'realizado', label: Text('Realizadas')),
                ButtonSegment(value: 'omitido', label: Text('Omitidas')),
              ],
              selected: {filtroEstado},
              onSelectionChanged: (seleccion) {
                setState(() {
                  filtroEstado = seleccion.first;
                });
              },
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${registrosFiltrados.length} '
                'de ${registros.length} registros',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget construirRegistro(Map<String, Object?> registro) {
    final estado = registro['estado'] as String;
    final realizada = estado == 'realizado';
    final motivo = registro['motivo'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    registro['actividad_nombre'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  realizada ? Icons.check_circle : Icons.cancel,
                  color: realizada ? Colors.green : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text('Rutina: ${registro['rutina_nombre']}'),

            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Hora programada: '
                  '${registro['hora_programada']}',
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              realizada ? 'Realizada' : 'Omitida',
              style: TextStyle(
                color: realizada ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (!realizada && motivo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Motivo: $motivo'),
            ],
          ],
        ),
      ),
    );
  }

  Widget construirLista(List<Map<String, Object?>> filtrados) {
    if (filtrados.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          Icon(Icons.search_off, size: 55, color: Colors.grey),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No hay registros que coincidan '
              'con los filtros seleccionados.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final registro = filtrados[index];
        final fecha = registro['fecha'] as String;

        final mostrarFecha =
            index == 0 || filtrados[index - 1]['fecha'] != fecha;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarFecha)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 10),
                child: Text(
                  formatearFecha(fecha),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            construirRegistro(registro),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = registrosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.actividadIdInicial == null
              ? 'Historial de cumplimiento'
              : 'Historial de actividad',
        ),
        actions: [
          IconButton(
            tooltip: 'Ver gráfica de cumplimiento',
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GraficaCumplimientoPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Actualizar historial',
            icon: const Icon(Icons.refresh),
            onPressed: cargarHistorial,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.actividadIdInicial != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Mostrando únicamente los registros de '
                'la actividad seleccionada.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          construirFiltros(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('Error: $error'))
                : RefreshIndicator(
                    onRefresh: cargarHistorial,
                    child: construirLista(filtrados),
                  ),
          ),
        ],
      ),
    );
  }
}
