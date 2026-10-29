import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';

import 'dart:math' as math;

class GraficaCumplimientoPage extends StatefulWidget {
  const GraficaCumplimientoPage({super.key});

  @override
  State<GraficaCumplimientoPage> createState() =>
      _GraficaCumplimientoPageState();
}

class _SegmentoCumplimiento {
  final String nombre;
  final int cantidad;
  final Color color;

  const _SegmentoCumplimiento({
    required this.nombre,
    required this.cantidad,
    required this.color,
  });
}

class _PeriodoCumplimiento {
  final DateTime inicio;
  int realizadas = 0;
  int omitidas = 0;

  _PeriodoCumplimiento(this.inicio);
}

class _GraficaCumplimientoPageState extends State<GraficaCumplimientoPage> {
  List<Map<String, Object?>> registros = [];

  DateTimeRange? periodo;
  String? rutinaSeleccionada;

  bool cargando = true;
  String? error;
  int indiceTocado = -1;
  bool mostrarBarras = false;
  bool agruparPorSemana = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  String mostrarFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  Future<void> cargarDatos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = await AppDatabase.instance.obtenerHistorialCumplimiento();

      if (!mounted) return;

      final nombres = datos.map((r) => r['rutina_nombre'] as String).toSet();

      setState(() {
        registros = datos;
        cargando = false;
        indiceTocado = -1;

        if (rutinaSeleccionada != null &&
            !nombres.contains(rutinaSeleccionada)) {
          rutinaSeleccionada = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
        error = e.toString();
      });
    }
  }

  List<String> get rutinasDisponibles {
    return registros.map((r) => r['rutina_nombre'] as String).toSet().toList()
      ..sort();
  }

  List<Map<String, Object?>> get registrosFiltrados {
    return registros.where((registro) {
      if (rutinaSeleccionada != null &&
          registro['rutina_nombre'] != rutinaSeleccionada) {
        return false;
      }

      final fecha = DateTime.parse(registro['fecha'] as String);

      if (periodo != null) {
        if (fecha.isBefore(periodo!.start) || fecha.isAfter(periodo!.end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> seleccionarPeriodo() async {
    final seleccionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: periodo,
      helpText: 'Seleccionar período de cumplimiento',
      saveText: 'Aplicar',
    );

    if (seleccionado == null || !mounted) return;

    setState(() {
      periodo = seleccionado;
      indiceTocado = -1;
    });
  }

  void limpiarFiltros() {
    setState(() {
      periodo = null;
      rutinaSeleccionada = null;
      indiceTocado = -1;
    });
  }

  DateTime inicioDelPeriodo(DateTime fecha) {
    if (agruparPorSemana) {
      // En Dart, lunes = 1 y domingo = 7.
      // Cada semana comenzará el lunes.
      return DateTime(fecha.year, fecha.month, fecha.day - (fecha.weekday - 1));
    }

    // Los períodos mensuales comienzan
    // el primer día del mes.
    return DateTime(fecha.year, fecha.month, 1);
  }

  List<_PeriodoCumplimiento> obtenerPeriodos(List<Map<String, Object?>> datos) {
    if (datos.isEmpty) return [];

    final fechas =
        datos
            .map((registro) => DateTime.parse(registro['fecha'] as String))
            .toList()
          ..sort();

    // Si hay un filtro de fechas, conservaremos
    // también los períodos sin registros dentro
    // del intervalo seleccionado.
    final inicio = inicioDelPeriodo(periodo?.start ?? fechas.first);

    final fin = inicioDelPeriodo(periodo?.end ?? fechas.last);

    final conteos = <DateTime, _PeriodoCumplimiento>{};

    var cursor = inicio;

    while (!cursor.isAfter(fin)) {
      conteos[cursor] = _PeriodoCumplimiento(cursor);

      cursor = agruparPorSemana
          ? DateTime(cursor.year, cursor.month, cursor.day + 7)
          : DateTime(cursor.year, cursor.month + 1, 1);
    }

    for (final registro in datos) {
      final fecha = DateTime.parse(registro['fecha'] as String);

      final clave = inicioDelPeriodo(fecha);
      final grupo = conteos[clave];

      if (grupo == null) continue;

      if (registro['estado'] == 'realizado') {
        grupo.realizadas++;
      } else if (registro['estado'] == 'omitido') {
        grupo.omitidas++;
      }
    }

    return conteos.values.toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  Widget construirBarrasPorPeriodo(List<Map<String, Object?>> datos) {
    final grupos = obtenerPeriodos(datos);

    if (grupos.isEmpty) {
      return const Center(child: Text('No hay registros para graficar.'));
    }

    final colores = Theme.of(context).colorScheme;

    final maximo = grupos.fold<int>(
      0,
      (actual, grupo) =>
          math.max(actual, math.max(grupo.realizadas, grupo.omitidas)),
    );

    final alturaMaxima = math.max(2.0, maximo * 1.2);

    final intervaloVertical = maximo > 10 ? (maximo / 5).ceilToDouble() : 1.0;

    final anchoDisponible = MediaQuery.sizeOf(context).width - 48;

    final anchoGrafica = math.max(anchoDisponible, grupos.length * 85.0);

    String etiquetaPeriodo(DateTime inicio) {
      if (agruparPorSemana) {
        return '${inicio.day}/${inicio.month}';
      }

      return '${inicio.month}/${inicio.year}';
    }

    String descripcionPeriodo(DateTime inicio) {
      if (agruparPorSemana) {
        final fin = DateTime(inicio.year, inicio.month, inicio.day + 6);

        return '${mostrarFecha(inicio)}'
            ' al ${mostrarFecha(fin)}';
      }

      return '${inicio.month}/${inicio.year}';
    }

    final barras = List.generate(grupos.length, (indice) {
      final grupo = grupos[indice];

      return BarChartGroupData(
        x: indice,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: grupo.realizadas.toDouble(),
            width: 17,
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(3),
          ),
          BarChartRodData(
            fromY: 0,
            toY: grupo.omitidas.toDouble(),
            width: 17,
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          agruparPorSemana ? 'Comparación semanal' : 'Comparación mensual',
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 320,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: anchoGrafica,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: alturaMaxima,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barras,

                  borderData: FlBorderData(show: false),

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: colores.outlineVariant, strokeWidth: 0.8),
                  ),

                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: intervaloVertical,
                        getTitlesWidget: (valor, meta) {
                          if (valor != valor.roundToDouble()) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              valor.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (valor, meta) {
                          final indice = valor.round();

                          if (indice < 0 ||
                              indice >= grupos.length ||
                              (valor - indice).abs() > 0.001) {
                            return const SizedBox.shrink();
                          }

                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              etiquetaPeriodo(grupos[indice].inicio),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      maxContentWidth: 220,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => colores.primary,
                      getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
                        final datosPeriodo = grupos[grupo.x];

                        final esRealizada = indiceBarra == 0;

                        final cantidad = esRealizada
                            ? datosPeriodo.realizadas
                            : datosPeriodo.omitidas;

                        final estado = esRealizada ? 'Realizadas' : 'Omitidas';

                        return BarTooltipItem(
                          '${descripcionPeriodo(datosPeriodo.inicio)}\n'
                          '$estado: $cantidad',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            construirLeyenda(
              'Realizadas',
              datos.where((r) => r['estado'] == 'realizado').length,
              datos.length,
              Colors.green.shade600,
            ),
            construirLeyenda(
              'Omitidas',
              datos.where((r) => r['estado'] == 'omitido').length,
              datos.length,
              Colors.red.shade400,
            ),
          ],
        ),

        const SizedBox(height: 12),

        const Text(
          'Las barras muestran cantidades de '
          'registros realizados y omitidos. '
          'Un período con cero registros no '
          'implica necesariamente incumplimiento. '
          'Desliza horizontalmente para consultar '
          'más períodos.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget construirGrafica(int realizadas, int omitidas) {
    final total = realizadas + omitidas;

    final segmentos = <_SegmentoCumplimiento>[
      if (realizadas > 0)
        _SegmentoCumplimiento(
          nombre: 'Realizadas',
          cantidad: realizadas,
          color: Colors.green.shade600,
        ),
      if (omitidas > 0)
        _SegmentoCumplimiento(
          nombre: 'Omitidas',
          cantidad: omitidas,
          color: Colors.red.shade400,
        ),
    ];

    final seleccionado = indiceTocado >= 0 && indiceTocado < segmentos.length
        ? segmentos[indiceTocado]
        : null;

    return Column(
      children: [
        SizedBox(
          height: 290,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 55,
                  sectionsSpace: 3,
                  sections: List.generate(segmentos.length, (index) {
                    final segmento = segmentos[index];

                    final porcentaje = segmento.cantidad * 100 / total;

                    final tocado = index == indiceTocado;

                    return PieChartSectionData(
                      value: segmento.cantidad.toDouble(),
                      color: segmento.color,
                      radius: tocado ? 77 : 68,
                      title: porcentaje >= 8
                          ? '${porcentaje.toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      showTitle: porcentaje >= 8,
                    );
                  }),
                  pieTouchData: PieTouchData(
                    touchCallback: (evento, respuesta) {
                      final indice = evento.isInterestedForInteractions
                          ? respuesta?.touchedSection?.touchedSectionIndex ?? -1
                          : -1;

                      if (indice != indiceTocado) {
                        setState(() {
                          indiceTocado = indice;
                        });
                      }
                    },
                  ),
                ),
              ),

              // Texto situado en el centro del anillo.
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Text('registros'),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (seleccionado != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${seleccionado.nombre}: '
              '${seleccionado.cantidad} registros '
              '(${(seleccionado.cantidad * 100 / total).toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            construirLeyenda(
              'Realizadas',
              realizadas,
              total,
              Colors.green.shade600,
            ),
            construirLeyenda('Omitidas', omitidas, total, Colors.red.shade400),
          ],
        ),
      ],
    );
  }

  Widget construirLeyenda(String titulo, int cantidad, int total, Color color) {
    final porcentaje = total == 0 ? 0.0 : cantidad * 100 / total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$titulo: $cantidad '
          '(${porcentaje.toStringAsFixed(1)}%)',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = registrosFiltrados;

    final realizadas = filtrados
        .where((r) => r['estado'] == 'realizado')
        .length;

    final omitidas = filtrados.where((r) => r['estado'] == 'omitido').length;

    final total = realizadas + omitidas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráfica de cumplimiento'),
        actions: [
          IconButton(
            tooltip: 'Actualizar información',
            icon: const Icon(Icons.refresh),
            onPressed: cargarDatos,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cumplimiento de actividades',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta la proporción de actividades '
            'realizadas y omitidas según los registros '
            'almacenados.',
          ),
          const SizedBox(height: 20),

          // FILTRO DE RUTINA
          DropdownButtonFormField<String>(
            key: ValueKey('rutina-${rutinaSeleccionada ?? "todas"}'),
            initialValue: rutinaSeleccionada,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Rutina',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Todas las rutinas'),
              ),
              ...rutinasDisponibles.map(
                (nombre) => DropdownMenuItem<String>(
                  value: nombre,
                  child: Text(nombre, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (valor) {
              setState(() {
                rutinaSeleccionada = valor;
                indiceTocado = -1;
              });
            },
          ),

          const SizedBox(height: 16),

          // FILTRO DE FECHAS
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: seleccionarPeriodo,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    periodo == null
                        ? 'Seleccionar período'
                        : '${mostrarFecha(periodo!.start)}'
                              ' - '
                              '${mostrarFecha(periodo!.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (periodo != null)
                IconButton(
                  tooltip: 'Quitar filtro de fechas',
                  onPressed: () {
                    setState(() {
                      periodo = null;
                      indiceTocado = -1;
                    });
                  },
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: limpiarFiltros,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Limpiar filtros'),
            ),
          ),

          const SizedBox(height: 12),
          Text('Visualización', style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Circular'),
                  icon: Icon(Icons.pie_chart),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Por períodos'),
                  icon: Icon(Icons.bar_chart),
                ),
              ],
              selected: {mostrarBarras},
              onSelectionChanged: (seleccion) {
                setState(() {
                  mostrarBarras = seleccion.first;
                  indiceTocado = -1;
                });
              },
            ),
          ),

          if (mostrarBarras) ...[
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: Text('Semanas')),
                  ButtonSegment<bool>(value: false, label: Text('Meses')),
                ],
                selected: {agruparPorSemana},
                onSelectionChanged: (seleccion) {
                  setState(() {
                    agruparPorSemana = seleccion.first;
                  });
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No fue posible cargar los datos: $error',
                textAlign: TextAlign.center,
              ),
            )
          else if (total == 0)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No existen registros de cumplimiento '
                  'para los filtros seleccionados.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            if (mostrarBarras)
              construirBarrasPorPeriodo(filtrados)
            else
              construirGrafica(realizadas, omitidas),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del período',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Actividades realizadas: $realizadas'),
                    const SizedBox(height: 6),
                    Text('Actividades omitidas: $omitidas'),
                    const SizedBox(height: 6),
                    Text('Total de registros: $total'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Los porcentajes se calculan únicamente '
              'a partir de registros de cumplimiento '
              'guardados. Las actividades pendientes '
              'no están incluidas.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
