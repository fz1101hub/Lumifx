part of 'hue_bridge_client.dart';

/// The light health check: reachability and firmware from the older API,
/// the radio link from the newer one.
extension HueHealthCheck on HueBridgeClient {
  Future<HueHealthReport> fetchHealth() async {
    final responses = await Future.wait([
      _client.get(_v1('/lights')).timeout(HueBridgeClient._timeout),
      _client.get(_v1('/config')).timeout(HueBridgeClient._timeout),
    ]);
    final lights = _v1Result(responses[0]);
    final config = _v1Result(responses[1]);
    // The radio link is a bonus: older bridges do not report it.
    final links = await _resources('zigbee_connectivity')
        .catchError(_noResources, test: (error) => error is HueException);
    final linkOf = <String, String>{
      for (final link in links)
        if ((link['mac_address'], link['status'])
            case (final String mac, final String status))
          mac.toLowerCase(): status,
    };
    final health = <HueLightHealth>[];
    if (lights is Map) {
      for (final light in lights.values) {
        if (light is! Map) {
          continue;
        }
        final state = light['state'];
        final update = light['swupdate'];
        final unique = '${light['uniqueid'] ?? ''}'.toLowerCase();
        final mac = unique.split('-').first;
        final link = linkOf[mac];
        health.add(HueLightHealth(
          name: '${light['name'] ?? ''}',
          model: light['productname'] as String?,
          firmware: light['swversion'] as String?,
          issues: {
            if ((state is Map && state['reachable'] == false) ||
                link == 'disconnected')
              LightIssue.unreachable,
            if (link == 'connectivity_issue' ||
                link == 'unidirectional_incoming')
              LightIssue.weakSignal,
            if (update is Map && update['state'] == 'readytoinstall')
              LightIssue.updateReady,
          },
        ));
      }
    }
    final bridgeUpdate = config is Map ? config['swupdate2'] : null;
    return HueHealthReport(
      lights: HueHealthReport.sorted(health),
      bridgeUpdateReady: bridgeUpdate is Map &&
          const {'anyreadytoinstall', 'allreadytoinstall'}
              .contains(bridgeUpdate['state']),
    );
  }
}
