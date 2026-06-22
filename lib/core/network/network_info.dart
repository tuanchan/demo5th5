abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class LocalNetworkInfo implements NetworkInfo {
  const LocalNetworkInfo();

  @override
  Future<bool> get isConnected async => true;
}
