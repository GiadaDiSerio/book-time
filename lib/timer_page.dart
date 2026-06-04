import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'responsive_wrapper.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
  }

  void _stopTimer() {
    _pauseTimer();
    
    // Aggiungiamo il tempo alle statistiche globali!
    appState.addReadingTime(_seconds);
    
    // Mostriamo un avviso alla fine della sessione
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sessione conclusa'),
        content: Text(
          'Ottimo lavoro! Hai letto per ${_formatTime(_seconds)}.\n\n(Il tempo è stato aggiunto alle tue statistiche!)'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // chiudi alert
              // Reset del timer (la pagina è inline, non si fa pop)
              setState(() {
                _seconds = 0;
              });
            },
            child: const Text('COMPLETA', style: TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Dialog per aggiungere manualmente il tempo di lettura
  void _showManualTimeDialog() {
    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    final scrollController = ScrollController();

    // Funzione per scrollare in fondo quando si tocca un campo
    void scrollToBottom() {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aggiungi tempo manualmente'),
        content: SingleChildScrollView(
          controller: scrollController,
          reverse: true, // Parte dal basso: i campi sono subito visibili
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hai dimenticato il cronometro?\nInserisci quanto tempo hai letto:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Campo ore
                  Expanded(
                    child: TextField(
                      controller: hoursController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onTap: scrollToBottom,
                      decoration: InputDecoration(
                        labelText: 'Ore',
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  // Campo minuti
                  Expanded(
                    child: TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onTap: scrollToBottom,
                      decoration: InputDecoration(
                        labelText: 'Minuti',
                        hintText: '30',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = int.tryParse(hoursController.text) ?? 0;
              final minutes = int.tryParse(minutesController.text) ?? 0;
              final totalSeconds = (hours * 3600) + (minutes * 60);

              if (totalSeconds > 86400) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Non puoi aggiungere più di 24 ore alla volta!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (totalSeconds > 0) {
                appState.addReadingTime(totalSeconds);
                Navigator.pop(dialogContext);

                // Mostra conferma
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Aggiunto: ${hours > 0 ? '${hours}h ' : ''}${minutes}m alle tue statistiche!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
            ),
            child: const Text('AGGIUNGI'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
        maxWidth: 500,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adattiamo le dimensioni in base allo spazio disponibile
            final isSmall = constraints.maxHeight < 500;
            final iconSize = isSmall ? 50.0 : 80.0;
            final timerFontSize = isSmall ? 40.0 : 64.0;
            final spacing = isSmall ? 16.0 : 48.0;

            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, size: iconSize, color: const Color(0xFF7B1FA2)),
                    const SizedBox(height: 24),
                    // Il cronometro
                    Text(
                      _formatTime(_seconds),
                      style: TextStyle(
                        fontSize: timerFontSize,
                        fontWeight: FontWeight.bold,
                        // Assicura che i numeri abbiano larghezza fissa (non saltellano)
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(height: spacing),
                    
                    // Pulsanti Play/Pausa e Stop
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton.large(
                          heroTag: 'play_pause',
                          onPressed: _isRunning ? _pauseTimer : _startTimer,
                          backgroundColor: const Color(0xFF7B1FA2),
                          foregroundColor: Colors.white,
                          child: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        ),
                        const SizedBox(width: 24),
                        FloatingActionButton(
                          heroTag: 'stop',
                          onPressed: _seconds > 0 ? _stopTimer : null,
                          backgroundColor: _seconds > 0 ? Colors.red : Colors.grey[300],
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.stop),
                        ),
                      ],
                    ),
                    
                    // Pulsante per aggiungere tempo manualmente
                    SizedBox(height: spacing),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showManualTimeDialog,
                      icon: const Icon(Icons.edit_calendar, color: Color(0xFF7B1FA2)),
                      label: const Text(
                        'Hai dimenticato il timer?\nAggiungi tempo manualmente',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF7B1FA2)),
                      ),
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
