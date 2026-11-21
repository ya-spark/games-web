// Browser storage for the web state (see web_state_model.dart). One key, `amc.state`, on this device only; nothing is
// sent anywhere. A browser that blocks storage simply starts empty every visit.
import 'web_platform.dart';
import 'web_state_model.dart';

WebState loadWebState() => WebState.parse(storageGet(WebState.storageKey));

void saveWebState(WebState s) => storageSet(WebState.storageKey, s.encode());
