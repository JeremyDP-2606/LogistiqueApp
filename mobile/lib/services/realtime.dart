import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

/// Connexion Socket.IO authentifiée (suivi en direct, nouvelles courses).
class Realtime {
  io.Socket? _socket;
  final Set<String> _subscribedJobs = {};

  void connect(String token) {
    disconnect();
    final s = io.io(
      apiUrl,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableReconnection().build(),
    );
    s.onConnect((_) {
      for (final id in _subscribedJobs) {
        s.emit('job:subscribe', id);
      }
    });
    _socket = s;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void subscribeJob(String id) {
    _subscribedJobs.add(id);
    _socket?.emit('job:subscribe', id);
  }

  void unsubscribeJob(String id) {
    _subscribedJobs.remove(id);
    _socket?.emit('job:unsubscribe', id);
  }

  void sendLocation(double lat, double lng) => _socket?.emit('courier:location', {'lat': lat, 'lng': lng});

  /// Abonnement à un évènement ; renvoie une fonction de désabonnement.
  void Function() on(String event, void Function(Map<String, dynamic> data) handler) {
    void cb(dynamic data) {
      if (data is Map) handler(Map<String, dynamic>.from(data));
    }

    _socket?.on(event, cb);
    return () => _socket?.off(event, cb);
  }
}
