class CompanionCollections {
  static const users = 'users';
  static const companionLinkCodes = 'companionLinkCodes';
  static const linkCodes = 'link_codes';
  static const appConnections = 'app_connections';
  static const companionLinks = 'companionLinks';
  static const deviceState = 'deviceState';
  static const deviceLocations = 'deviceLocations';
  static const remoteCommands = 'remoteCommands';
  static const trustedContacts = 'trustedContacts';
  static const safeZones = 'safeZones';
  static const checkIns = 'checkIns';
  static const activityLogs = 'activityLogs';
}

class RemoteCommandType {
  static const startShareLocation = 'START_SHARE_LOCATION';
  static const stopShareLocation = 'STOP_SHARE_LOCATION';
  static const playSiren = 'PLAY_SIREN';
  static const stopSiren = 'STOP_SIREN';
  static const placeApprovedCall = 'PLACE_APPROVED_CALL';
  static const triggerFakeCall = 'TRIGGER_FAKE_CALL';
  static const startCheckIn = 'START_CHECK_IN';
  static const cancelCheckIn = 'CANCEL_CHECK_IN';
  static const setBatterySaver = 'SET_BATTERY_SAVER';
  static const setMotionSensitivity = 'SET_MOTION_SENSITIVITY';
}

String companionLinkId(String mainUserId, String companionUserId) {
  return '${mainUserId}_$companionUserId';
}
