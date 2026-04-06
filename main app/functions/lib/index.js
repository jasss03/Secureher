"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.processSosAudio = exports.onAlertCreate = exports.cleanupExpiredCompanionLinkCodes = exports.onCheckInDue = exports.onRemoteCommandCreated = exports.enqueueRemoteCommand = exports.redeemCompanionLinkCode = exports.issueCompanionLinkCode = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const twilio_1 = __importDefault(require("twilio"));
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
const twilioSid = process.env.TWILIO_SID || functions.config().twilio?.sid;
const twilioToken = process.env.TWILIO_TOKEN || functions.config().twilio?.token;
const twilioFrom = process.env.TWILIO_FROM || functions.config().twilio?.from;
const client = twilioSid && twilioToken ? (0, twilio_1.default)(twilioSid, twilioToken) : null;
const COMMAND_TYPES = new Set([
    'START_SHARE_LOCATION',
    'STOP_SHARE_LOCATION',
    'PLAY_SIREN',
    'STOP_SIREN',
    'PLACE_APPROVED_CALL',
    'TRIGGER_FAKE_CALL',
    'START_CHECK_IN',
    'CANCEL_CHECK_IN',
    'SET_BATTERY_SAVER',
    'SET_MOTION_SENSITIVITY',
]);
function assertAuthenticated(context) {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication is required.');
    }
    return uid;
}
function randomCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}
function linkDocId(mainUserId, companionUserId) {
    return `${mainUserId}_${companionUserId}`;
}
async function upsertUserProfile(uid, data) {
    await db.collection('users').doc(uid).set({
        ...data,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function addActivityLog(mainUserId, type, summary, details = {}, actorUserId, actorRole) {
    await db.collection('activityLogs').doc(mainUserId).collection('events').add({
        type,
        summary,
        details,
        actorUserId: actorUserId ?? null,
        actorRole: actorRole ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function collectTrustedRecipients(mainUserId) {
    const snapshot = await db.collection('trustedContacts').doc(mainUserId).collection('items').get();
    return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
            id: doc.id,
            name: data.name ?? 'Trusted Contact',
            phone: data.phone ?? '',
            email: data.email ?? '',
            relationship: data.relationship ?? '',
        };
    });
}
exports.issueCompanionLinkCode = functions.https.onCall(async (_data, context) => {
    const uid = assertAuthenticated(context);
    const authUser = await admin.auth().getUser(uid);
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + 10 * 60 * 1000);
    await upsertUserProfile(uid, {
        role: 'main',
        displayName: authUser.displayName ?? null,
        email: authUser.email ?? null,
        phoneNumber: authUser.phoneNumber ?? null,
    });
    let code = randomCode();
    for (let attempt = 0; attempt < 5; attempt += 1) {
        const doc = await db.collection('companionLinkCodes').doc(code).get();
        if (!doc.exists)
            break;
        code = randomCode();
    }
    await db.collection('companionLinkCodes').doc(code).set({
        mainUserId: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
        used: false,
    });
    await addActivityLog(uid, 'link_code_issued', `Issued companion link code ${code}.`, { code }, uid, 'main');
    return {
        code,
        expiresAt: expiresAt.toMillis(),
    };
});
exports.redeemCompanionLinkCode = functions.https.onCall(async (data, context) => {
    const uid = assertAuthenticated(context);
    const code = String(data?.code ?? '').trim();
    if (!code) {
        throw new functions.https.HttpsError('invalid-argument', 'A companion link code is required.');
    }
    const authUser = await admin.auth().getUser(uid);
    const codeRef = db.collection('companionLinkCodes').doc(code);
    const now = admin.firestore.Timestamp.now();
    const result = await db.runTransaction(async (tx) => {
        const codeSnap = await tx.get(codeRef);
        if (!codeSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'This link code does not exist.');
        }
        const codeData = codeSnap.data();
        const expiresAt = codeData.expiresAt;
        if (codeData.used) {
            throw new functions.https.HttpsError('failed-precondition', 'This link code has already been used.');
        }
        if (!expiresAt || expiresAt.toMillis() <= now.toMillis()) {
            throw new functions.https.HttpsError('deadline-exceeded', 'This link code has expired.');
        }
        const mainUserId = String(codeData.mainUserId ?? '');
        if (!mainUserId) {
            throw new functions.https.HttpsError('internal', 'This link code is missing its owner.');
        }
        const linkId = linkDocId(mainUserId, uid);
        const linkRef = db.collection('companionLinks').doc(linkId);
        tx.set(linkRef, {
            mainUserId,
            companionUserId: uid,
            companionDisplayName: authUser.displayName ?? authUser.email ?? 'Companion',
            companionEmail: authUser.email ?? null,
            active: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.update(codeRef, {
            used: true,
            usedBy: uid,
            usedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { mainUserId, linkId };
    });
    await upsertUserProfile(uid, {
        role: 'companion',
        displayName: authUser.displayName ?? null,
        email: authUser.email ?? null,
        phoneNumber: authUser.phoneNumber ?? null,
    });
    await addActivityLog(result.mainUserId, 'companion_linked', `${authUser.displayName ?? authUser.email ?? 'Companion'} linked successfully.`, { companionUserId: uid, linkId: result.linkId }, uid, 'companion');
    return result;
});
exports.enqueueRemoteCommand = functions.https.onCall(async (data, context) => {
    const uid = assertAuthenticated(context);
    const mainUserId = String(data?.mainUserId ?? '').trim();
    const type = String(data?.type ?? '').trim();
    const payload = (data?.payload ?? {});
    if (!mainUserId || !type) {
        throw new functions.https.HttpsError('invalid-argument', 'Command type and main user are required.');
    }
    if (!COMMAND_TYPES.has(type)) {
        throw new functions.https.HttpsError('invalid-argument', `Unsupported command type: ${type}`);
    }
    const linkRef = db.collection('companionLinks').doc(linkDocId(mainUserId, uid));
    const linkSnap = await linkRef.get();
    if (!linkSnap.exists || linkSnap.data()?.active !== true) {
        throw new functions.https.HttpsError('permission-denied', 'This companion is not linked to the selected main user.');
    }
    let normalizedPayload = payload;
    if (type === 'PLACE_APPROVED_CALL') {
        const contactId = String(payload.contactId ?? '').trim();
        if (!contactId) {
            throw new functions.https.HttpsError('invalid-argument', 'An approved contact is required for remote calls.');
        }
        const contactSnap = await db.collection('trustedContacts').doc(mainUserId).collection('items').doc(contactId).get();
        if (!contactSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'The selected approved contact could not be found.');
        }
        const contactData = contactSnap.data();
        normalizedPayload = {
            contactId,
            phone: contactData.phone ?? '',
            name: contactData.name ?? 'Trusted Contact',
        };
    }
    const commandRef = await db.collection('remoteCommands').add({
        mainUserId,
        issuedByCompanionId: uid,
        type,
        payload: normalizedPayload,
        status: 'queued',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await addActivityLog(mainUserId, 'remote_command_queued', `Queued ${type} from companion.`, { commandId: commandRef.id, type, payload: normalizedPayload }, uid, 'companion');
    return { commandId: commandRef.id };
});
exports.onRemoteCommandCreated = functions.firestore
    .document('remoteCommands/{commandId}')
    .onCreate(async (snap) => {
    const data = snap.data();
    if (!data)
        return;
    const mainUserId = String(data.mainUserId ?? '');
    if (!mainUserId)
        return;
    const userSnap = await db.collection('users').doc(mainUserId).get();
    const tokens = (userSnap.data()?.fcmTokens ?? []).filter(Boolean);
    if (tokens.length === 0)
        return;
    try {
        await messaging.sendEachForMulticast({
            tokens,
            data: {
                type: 'remote_command',
                commandId: snap.id,
                commandType: String(data.type ?? ''),
                mainUserId,
            },
        });
    }
    catch (error) {
        console.error('Failed to fan out remote command notification', error);
    }
});
exports.onCheckInDue = functions.pubsub.schedule('every 1 minutes').onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const dueSnapshot = await db
        .collectionGroup('items')
        .where('kind', '==', 'check_in')
        .where('status', '==', 'pending')
        .where('scheduledFor', '<=', now)
        .get();
    if (dueSnapshot.empty)
        return;
    for (const doc of dueSnapshot.docs) {
        const data = doc.data();
        const mainUserId = String(data.mainUserId ?? '');
        if (!mainUserId)
            continue;
        await doc.ref.update({
            status: 'missed',
            missedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const recipients = await collectTrustedRecipients(mainUserId);
        await db.collection('alerts').add({
            type: 'missed_checkin',
            mainUserId,
            checkInId: doc.id,
            message: data.message ?? 'Missed check-in. Please reach out immediately.',
            recipients,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            active: true,
        });
        await db.collection('deviceState').doc(mainUserId).set({
            activeCheckIn: null,
            lastCommandResult: {
                type: 'CHECK_IN_MISSED',
                status: 'missed',
                message: 'A scheduled check-in was missed.',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        }, { merge: true });
        await addActivityLog(mainUserId, 'check_in_missed', 'A scheduled check-in was missed.', { checkInId: doc.id }, undefined, 'system');
    }
});
exports.cleanupExpiredCompanionLinkCodes = functions.pubsub.schedule('every 60 minutes').onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
        .collection('companionLinkCodes')
        .where('used', '==', false)
        .where('expiresAt', '<=', now)
        .get();
    if (snapshot.empty)
        return;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
});
exports.onAlertCreate = functions.firestore
    .document('alerts/{alertId}')
    .onCreate(async (snap) => {
    const data = snap.data();
    if (!data)
        return;
    const mainUserId = String(data.mainUserId ?? '');
    if (!mainUserId)
        return;
    const type = data.type || 'sos';
    const message = data.message || (type === 'safe' ? "I'm safe now." : 'SOS!');
    let recipients = Array.isArray(data.recipients)
        ? data.recipients
        : [];
    if (recipients.length === 0) {
        recipients = await collectTrustedRecipients(mainUserId);
    }
    // 1. Fan out high-priority FCM notifications to all linked companions
    try {
        const companionLinks = await db
            .collection('companionLinks')
            .where('mainUserId', '==', mainUserId)
            .where('active', '==', true)
            .get();
        const companionIds = companionLinks.docs.map((d) => d.data().companionUserId);
        if (companionIds.length > 0) {
            const tokens = [];
            for (const cid of companionIds) {
                const cUser = await db.collection('users').doc(cid).get();
                const t = cUser.data()?.fcmTokens ?? [];
                tokens.push(...t.filter(Boolean));
            }
            if (tokens.length > 0) {
                await messaging.sendEachForMulticast({
                    tokens: Array.from(new Set(tokens)),
                    notification: {
                        title: type === 'sos' ? 'EMERGENCY SOS' : 'Safety Update',
                        body: message,
                    },
                    data: {
                        type: 'sos_alert',
                        alertId: snap.id,
                        mainUserId,
                        triggerSiren: type === 'sos' ? 'true' : 'false',
                    },
                    android: {
                        priority: 'high',
                        notification: {
                            channelId: 'sos_channel',
                            sound: 'siren',
                            priority: 'max',
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: 'siren.wav',
                                critical: true,
                            },
                        },
                    },
                });
                console.log(`FCM fan-out successful for alert ${snap.id}`);
            }
        }
    }
    catch (err) {
        console.error('FCM fan-out failed:', err);
    }
    // 2. Fallback: Twilio SMS (Existing)
    if (!client || !twilioFrom) {
        console.log('Twilio not configured, skipping SMS send.');
        return;
    }
    const phones = recipients
        .map((r) => (r.phone || '').trim())
        .filter((p) => p.length > 0);
    await Promise.all(phones.map(async (to) => {
        try {
            await client.messages.create({ to, from: twilioFrom, body: message });
            console.log('SMS sent to', to);
        }
        catch (error) {
            console.error('Failed to send SMS to', to, error);
        }
    }));
});
/**
 * SOS Audio Processing Function
 */
const speech = __importStar(require("@google-cloud/speech"));
exports.processSosAudio = functions.storage.object().onFinalize(async (object) => {
    const filePath = object.name;
    if (!filePath || !filePath.startsWith('evidence/')) {
        console.log('Not an SOS evidence file. Skipping.');
        return null;
    }
    const alertId = object.metadata && object.metadata.alertId;
    if (!alertId) {
        console.warn('No alertId found in file metadata. Cannot sync to Firestore.');
        return null;
    }
    const speechClient = new speech.v1.SpeechClient();
    const bucket = admin.storage().bucket(object.bucket);
    const file = bucket.file(filePath);
    try {
        const [content] = await file.download();
        const request = {
            audio: {
                content: content.toString('base64'),
            },
            config: {
                encoding: 'LINEAR16',
                sampleRateHertz: 16000,
                languageCode: 'en-IN',
                alternativeLanguageCodes: ['hi-IN'],
                speechContexts: [{
                        phrases: ['help', 'bachao', 'madad', 'save me', 'police', 'hey bro', "i'll be late", 'i will be late'],
                        boost: 25.0,
                    }],
            },
        };
        const [response] = await speechClient.recognize(request);
        const transcription = response.results
            ?.map((result) => result.alternatives?.[0]?.transcript)
            .filter(Boolean)
            .join('\n') || '';
        console.log(`Transcription for alert ${alertId}: ${transcription}`);
        const distressKeywords = ['help', 'bachao', 'madad', 'save', 'police', 'danger', 'hey bro', "i'll be late", 'i will be late'];
        const lowercaseTranscription = transcription.toLowerCase();
        const isDistressMatch = distressKeywords.some((k) => lowercaseTranscription.includes(k));
        await db.collection('alerts').doc(alertId).update({
            backendTranscription: transcription,
            backendDistressConfirmed: isDistressMatch,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            backendSyncStatus: 'success',
            // If backend confirms danger, we also set triggerSiren to true to ensure all companions are alerted
            ...(isDistressMatch ? { triggerSiren: true, sirenTriggeredAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
        });
        return null;
    }
    catch (error) {
        console.error(`Error processing SOS audio for alert ${alertId}:`, error);
        await db.collection('alerts').doc(alertId).update({
            backendSyncStatus: 'failed',
            backendError: error.message,
        });
        throw error;
    }
});
//# sourceMappingURL=index.js.map