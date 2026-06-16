import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../../controllers/app_controller.dart';
import '../widgets/responsive_wrapper.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreTimerState();
  }

  // --- PERSISTENZA DEL TIMER ---

  /// Salva lo stato del timer in SharedPreferences
  Future<void> _saveTimerState() async {
    if (_isRunning) {
      // Se il timer è in esecuzione, salviamo il timestamp di quando è partito
      // sottraendo i secondi già accumulati, così al ripristino possiamo
      // ricalcolare il tempo trascorso
      final startTimestamp = DateTime.now().millisecondsSinceEpoch - (_seconds * 1000);
      await storageService.saveInt('timerStartTimestamp', startTimestamp);
      await storageService.saveBool('timerWasRunning', true);
    } else if (_seconds > 0) {
      // Timer in pausa con dei secondi accumulati
      await storageService.saveInt('timerPausedSeconds', _seconds);
      await storageService.saveBool('timerWasRunning', false);
    }
  }

  /// Ripristina lo stato del timer da SharedPreferences
  Future<void> _restoreTimerState() async {
    final wasRunning = await storageService.getBool('timerWasRunning');

    if (wasRunning == null) return; // Nessun timer salvato

    if (wasRunning) {
      // Il timer era in esecuzione: calcoliamo quanti secondi sono passati
      final startTimestamp = await storageService.getInt('timerStartTimestamp') ?? 0;
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTimestamp;
      final restoredSeconds = (elapsedMs / 1000).floor();

      setState(() {
        _seconds = restoredSeconds;
      });

      // Riavviamo il timer automaticamente
      _startTimer();
    } else {
      // Il timer era in pausa
      final pausedSeconds = await storageService.getInt('timerPausedSeconds') ?? 0;
      if (pausedSeconds > 0) {
        setState(() {
          _seconds = pausedSeconds;
        });
      }
    }

    // Puliamo i dati salvati (verranno risalvati se necessario)
    await _clearSavedTimerState();
  }

  /// Rimuove i dati del timer salvati
  Future<void> _clearSavedTimerState() async {
    await storageService.remove('timerStartTimestamp');
    await storageService.remove('timerWasRunning');
    await storageService.remove('timerPausedSeconds');
  }

  /// Intercetta i cambiamenti del ciclo di vita dell'app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      // L'app sta andando in background o viene chiusa
      if (_seconds > 0) {
        _saveTimerState();
      }
    } else if (state == AppLifecycleState.resumed) {
      // L'app torna in primo piano: se il timer era in esecuzione,
      // ricalcoliamo i secondi trascorsi
      _restoreTimerState();
    }
  }

  // --- LOGICA DEL TIMER ---

  void _startTimer() {
    _timer?.cancel(); // Evitiamo timer multipli
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
    // Salviamo lo stato in pausa
    if (_seconds > 0) {
      _saveTimerState();
    }
  }

  void _stopTimer() {
    _pauseTimer();
    
    // Puliamo i dati salvati poiché la sessione è conclusa
    _clearSavedTimerState();
    
    // Aggiungiamo il tempo alle statistiche globali!
    context.read<AppController>().addReadingTime(_seconds);
    
    // Mostriamo un avviso alla fine della sessione
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sessione conclusa'),
        content: Text(
          'Ottimo lavoro! Hai letto per ${_formatTime(_seconds)}.\n\n(Il tempo è stato aggiunto alle tue statistiche!)'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // chiudi alert
              // Reset del timer (la pagina è inline, non si fa pop)
              setState(() {
                _seconds = 0;
              });
            },
            child: Text('COMPLETA', style: TextStyle(color: Theme.of(dialogCtx).colorScheme.primary, fontWeight: FontWeight.bold)),
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

    showDialog(
      context: context,
      builder: (dialogContext) {
        String? hoursError;
        String? minutesError;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Aggiungi tempo manualmente'),
              content: SingleChildScrollView(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Campo ore
                        Expanded(
                          child: TextField(
                            controller: hoursController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) {
                              if (hoursError != null) setStateDialog(() => hoursError = null);
                            },
                            decoration: InputDecoration(
                              labelText: 'Ore',
                              hintText: '0',
                              errorText: hoursError,
                              errorMaxLines: 4,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                        // Campo minuti
                        Expanded(
                          child: TextField(
                            controller: minutesController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) {
                              if (minutesError != null) setStateDialog(() => minutesError = null);
                            },
                            decoration: InputDecoration(
                              labelText: 'Minuti',
                              hintText: '30',
                              errorText: minutesError,
                              errorMaxLines: 4,
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
                    FocusManager.instance.primaryFocus?.unfocus();
                    
                    final hours = int.tryParse(hoursController.text) ?? 0;
                    final minutes = int.tryParse(minutesController.text) ?? 0;
                    final totalSeconds = (hours * 3600) + (minutes * 60);

                    bool hasError = false;
                    String? newMinutesError;
                    String? newHoursError;

                    if (minutes > 59) {
                      newMinutesError = 'Max: 59';
                      hasError = true;
                    }

                    if (totalSeconds > 86400) {
                      newHoursError = 'Max: 24';
                      hasError = true;
                    }

                    if (hasError) {
                      setStateDialog(() {
                        minutesError = newMinutesError;
                        hoursError = newHoursError;
                      });
                      return;
                    }

                    if (totalSeconds > 0) {
                      context.read<AppController>().addReadingTime(totalSeconds);
                      Navigator.pop(dialogContext);

                      // Mostra conferma
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Aggiunto: ${hours > 0 ? '${hours}h ' : ''}${minutes}m alle tue statistiche!',
                          ),
                          backgroundColor: Colors.green,
                          action: SnackBarAction(
                            label: 'ANNULLA',
                            textColor: Colors.white,
                            onPressed: () {
                              context.read<AppController>().removeReadingTime(totalSeconds);
                            },
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('AGGIUNGI'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Se il timer è ancora attivo quando la pagina viene distrutta, salviamo
    if (_seconds > 0) {
      _saveTimerState();
    }
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
                    Icon(Icons.timer, size: iconSize, color: Theme.of(context).colorScheme.primary),
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
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
                      icon: Icon(Icons.edit_calendar, color: Theme.of(context).colorScheme.primary),
                      label: Text(
                        'Hai dimenticato il timer?\nAggiungi tempo manualmente',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
