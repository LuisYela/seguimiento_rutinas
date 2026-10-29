import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';

class GraficaMetricaPage extends StatefulWidget {
  final Map<String, Object?> metrica;

  const GraficaMetricaPage({super.key, required this.metrica});

  @override
  State<GraficaMetricaPage> createState() => _GraficaMetricaPageState();
}

class _PuntoMetrica {
  final DateTime fecha;
  final double valor;
  final String descripcion;

  const _PuntoMetrica({
    required this.fecha,
    required this.valor,
    required this.descripcion,
  });
}

class _GraficaMetricaPageState extends State<GraficaMetricaPage> {
  List<_PuntoMetrica> puntos = [];

  bool cargando = true;
  String? error;
  DateTimeRange? rangoSeleccionado;
  bool mostrarBarras = false;

  List<_PuntoMetrica> get puntosFiltrados {
    final rango = rangoSeleccionado;

    if (rango == null) {
      return puntos;
    }

    return puntos.where((punto) {
      final fecha = punto.fecha;

      return !fecha.isBefore(rango.start) && !fecha.isAfter(rango.end);
    }).toList();
  }

  String get unidad => widget.metrica['unidad'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  String mostrarNumero(double valor) {
    if (valor == valor.roundToDouble()) {
      return valor.toStringAsFixed(0);
    }

    return valor.toStringAsFixed(2);
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
      final registros = await AppDatabase.instance.obtenerValoresMetrica(
        widget.metrica['id'] as int,
      );

      final resultado = registros.map((registro) {
        return _PuntoMetrica(
          fecha: DateTime.parse(registro['fecha'] as String),
          valor: (registro['valor'] as num).toDouble(),
          descripcion: registro['descripcion'] as String? ?? '',
        );
      }).toList();

      resultado.sort((a, b) => a.fecha.compareTo(b.fecha));

      if (!mounted) return;

      setState(() {
        puntos = resultado;
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

  Future<void> seleccionarPeriodo() async {
    if (puntos.isEmpty) return;

    final periodo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange:
          rangoSeleccionado ??
          DateTimeRange(start: puntos.first.fecha, end: puntos.last.fecha),
      helpText: 'Selecciona el período',
      saveText: 'Aplicar',
    );

    if (periodo == null || !mounted) return;

    setState(() {
      rangoSeleccionado = periodo;
    });
  }

  Widget construirGraficaBarras() {
    final visibles = puntosFiltrados;
    final colores = Theme.of(context).colorScheme;

    if (visibles.isEmpty) {
      return const Center(child: Text('No hay valores para mostrar.'));
    }

    final valores = visibles.map((punto) => punto.valor).toList();

    final menor = valores.reduce(math.min);
    final mayor = valores.reduce(math.max);

    // Incluir el cero y admitir valores negativos.
    final limiteInferior = math.min(0.0, menor);
    final limiteSuperior = math.max(0.0, mayor);

    final margen = math.max(1.0, (limiteSuperior - limiteInferior) * 0.15);

    final minY = limiteInferior < 0 ? limiteInferior - margen : 0.0;

    final maxY = limiteSuperior > 0 ? limiteSuperior + margen : margen;

    // Evitar demasiadas etiquetas de fecha.
    final saltoEtiquetas = math.max(1, (visibles.length / 6).ceil());

    final barras = List.generate(visibles.length, (index) {
      final punto = visibles[index];

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: punto.valor,
            width: 20,
            color: colores.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    // Permitir desplazamiento horizontal
    // cuando existan muchos registros.
    final anchoDisponible = MediaQuery.sizeOf(context).width - 48;

    final anchoGrafica = math.max(anchoDisponible, visibles.length * 52.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 320,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: anchoGrafica,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
                child: BarChart(
                  BarChartData(
                    minY: minY,
                    maxY: maxY,
                    barGroups: barras,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: colores.outlineVariant,
                        strokeWidth: 0.8,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
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
                          reservedSize: 48,
                          getTitlesWidget: (valor, meta) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                mostrarNumero(valor),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (valor, meta) {
                            final indice = valor.round();

                            if (indice < 0 ||
                                indice >= visibles.length ||
                                (valor - indice).abs() > 0.001) {
                              return const SizedBox.shrink();
                            }

                            final esUltimo = indice == visibles.length - 1;

                            if (indice % saltoEtiquetas != 0 && !esUltimo) {
                              return const SizedBox.shrink();
                            }

                            final fecha = visibles[indice].fecha;

                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                '${fecha.day}/${fecha.month}',
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
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        maxContentWidth: 220,
                        getTooltipColor: (_) => colores.primary,
                        getTooltipItem:
                            (grupo, indiceGrupo, barra, indiceBarra) {
                              final registro = visibles[grupo.x];

                              final descripcion = registro.descripcion.trim();

                              final textoDescripcion = descripcion.isEmpty
                                  ? ''
                                  : '\nObservación: $descripcion';

                              return BarTooltipItem(
                                '${mostrarFecha(registro.fecha)}\n'
                                '${mostrarNumero(registro.valor)}'
                                '${unidad.isEmpty ? '' : ' $unidad'}'
                                '$textoDescripcion',
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
        ),
        const SizedBox(height: 12),
        Text(
          'Del ${mostrarFecha(visibles.first.fecha)} '
          'al ${mostrarFecha(visibles.last.fecha)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada barra representa un registro. '
          'Desliza horizontalmente si existen '
          'muchos valores y toca una barra '
          'para consultar sus detalles.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget construirGrafica() {
    final colores = Theme.of(context).colorScheme;
    final visibles = puntosFiltrados;

    final primeraFecha = visibles.first.fecha;
    final ultimaFecha = visibles.last.fecha;

    final diasReales = ultimaFecha.difference(primeraFecha).inDays;

    // Mantener un ancho válido aunque exista
    // solamente un registro.
    final maxX = math.max(1, diasReales).toDouble();

    final valores = visibles.map((p) => p.valor).toList();

    final menor = valores.reduce(math.min);
    final mayor = valores.reduce(math.max);

    final margen = mayor == menor
        ? math.max(1.0, mayor.abs() * 0.1)
        : (mayor - menor) * 0.15;

    final minY = menor - margen;
    final maxY = mayor + margen;

    final intervaloDias = math.max(1, (maxX / 4).ceil());

    // La posición horizontal corresponde a
    // los días transcurridos, no al número de
    // registro. Así respetamos los espacios
    // entre fechas diferentes.
    final spots = visibles.map((punto) {
      final dia = punto.fecha.difference(primeraFecha).inDays;

      return FlSpot(dia.toDouble(), punto.valor);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: colores.outlineVariant, strokeWidth: 0.8),
                ),
                borderData: FlBorderData(show: false),
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
                      reservedSize: 48,
                      getTitlesWidget: (valor, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            mostrarNumero(valor),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: intervaloDias.toDouble(),
                      getTitlesWidget: (valor, meta) {
                        final dia = valor.round();

                        if (dia < 0 ||
                            dia > diasReales ||
                            (valor - dia).abs() > 0.001) {
                          return const SizedBox.shrink();
                        }

                        final fecha = primeraFecha.add(Duration(days: dia));

                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${fecha.day}/${fecha.month}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 220,
                    getTooltipColor: (_) => colores.primary,
                    getTooltipItems: (spotsTocados) {
                      return spotsTocados.map((spot) {
                        final registro = visibles.firstWhere(
                          (punto) =>
                              punto.fecha.difference(primeraFecha).inDays ==
                              spot.x.round(),
                        );

                        final descripcion = registro.descripcion.trim();

                        final textoDescripcion = descripcion.isEmpty
                            ? ''
                            : '\nObservación: $descripcion';

                        return LineTooltipItem(
                          '${mostrarFecha(registro.fecha)}\n'
                          '${mostrarNumero(registro.valor)}'
                          '${unidad.isEmpty ? '' : ' $unidad'}'
                          '$textoDescripcion',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: colores.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colores.primary.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Del ${mostrarFecha(primeraFecha)} '
          'al ${mostrarFecha(ultimaFecha)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada punto representa un valor registrado. '
          'Los días sin registros no se consideran '
          'valores iguales a cero.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget construirResumen() {
    final valores = puntosFiltrados.map((p) => p.valor).toList();

    final minimo = valores.reduce(math.min);
    final maximo = valores.reduce(math.max);
    final promedio = valores.reduce((a, b) => a + b) / valores.length;

    Widget dato(String titulo, double valor) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(titulo, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                mostrarNumero(valor),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (unidad.isNotEmpty)
                Text(unidad, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        dato('Mínimo', minimo),
        dato('Máximo', maximo),
        dato('Promedio', promedio),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.metrica['nombre'] as String? ?? 'Métrica';
    final visibles = puntosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolución de métrica'),
        actions: [
          IconButton(
            tooltip: 'Actualizar gráfica',
            onPressed: cargarDatos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: $error', textAlign: TextAlign.center),
              ),
            )
          : puntos.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay valores registrados '
                  'para esta métrica.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(nombre, style: Theme.of(context).textTheme.headlineSmall),
                if (unidad.isNotEmpty) Text('Unidad: $unidad'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: seleccionarPeriodo,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          rangoSeleccionado == null
                              ? 'Seleccionar período'
                              : '${mostrarFecha(rangoSeleccionado!.start)}'
                                    ' - '
                                    '${mostrarFecha(rangoSeleccionado!.end)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    if (rangoSeleccionado != null)
                      IconButton(
                        tooltip: 'Mostrar todas las fechas',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            rangoSeleccionado = null;
                          });
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                if (visibles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No existen valores registrados '
                      'en el período seleccionado.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  construirResumen(),

                  const SizedBox(height: 20),

                  Text(
                    'Tipo de gráfica',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Líneas'),
                          icon: Icon(Icons.show_chart),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Barras'),
                          icon: Icon(Icons.bar_chart),
                        ),
                      ],
                      selected: {mostrarBarras},
                      onSelectionChanged: (seleccion) {
                        setState(() {
                          mostrarBarras = seleccion.first;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (mostrarBarras)
                    construirGraficaBarras()
                  else
                    construirGrafica(),
                ],
              ],
            ),
    );
  }
}
