/**
 * Automated Verification Test Suite for Vylithra WebRTC Calling & Signaling
 * Tests all 4 one-to-one combinations:
 *  1. Website -> Website
 *  2. Mobile -> Mobile
 *  3. Website -> Mobile
 *  4. Mobile -> Website
 * Plus edge cases: Offline recipient, Call rejection, Call termination, and Identity spoof prevention.
 */

const http = require('http');
const express = require('express');
const socketIo = require('socket.io');
const ioClient = require('socket.io-client');
const assert = require('assert');

// 1. Spin up isolated test signaling server matching server.js logic
const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: '*' } });

const userSocketMap = new Map();

io.on('connection', (socket) => {
    socket.on('join_chat', (userId) => {
        if (userId) {
            const uid = String(userId);
            socket.userId = uid;
            socket.join(uid);
            if (!userSocketMap.has(uid)) {
                userSocketMap.set(uid, new Set());
            }
            userSocketMap.get(uid).add(socket.id);
        }
    });

    socket.on('webrtc_signal', (data) => {
        if (!data || !data.to) return;
        const targetUserId = String(data.to);
        const senderId = socket.userId || (data.from ? String(data.from) : null);
        
        // Stamp authenticated sender identity to prevent impersonation
        if (senderId) {
            data.from = senderId;
            if (data.payload && typeof data.payload === 'object') {
                data.payload.from = senderId;
            }
        }

        const recipientSockets = userSocketMap.get(targetUserId);
        const isOnline = recipientSockets && recipientSockets.size > 0;
        
        io.to(targetUserId).emit('webrtc_signal', data);

        if (data.type === 'call-made' && !isOnline && senderId) {
            socket.emit('webrtc_signal', {
                type: 'call-rejected',
                to: senderId,
                from: targetUserId,
                payload: {
                    to: senderId,
                    from: targetUserId,
                    reason: 'offline'
                }
            });
        }
    });

    socket.on('disconnect', () => {
        if (socket.userId && userSocketMap.has(socket.userId)) {
            const set = userSocketMap.get(socket.userId);
            set.delete(socket.id);
            if (set.size === 0) {
                userSocketMap.delete(socket.userId);
            }
        }
    });
});

const TEST_PORT = 3456;
const SERVER_URL = `http://localhost:${TEST_PORT}`;

function createClient(userId) {
    return new Promise((resolve) => {
        const socket = ioClient(SERVER_URL, { transports: ['websocket'] });
        socket.on('connect', () => {
            socket.emit('join_chat', userId);
            setTimeout(() => resolve(socket), 50);
        });
    });
}

async function runTests() {
    console.log('--- STARTING VYLITHRA WEBRTC AUTOMATED VERIFICATION ---');
    await new Promise((resolve) => server.listen(TEST_PORT, resolve));
    console.log(`Test signaling server listening on port ${TEST_PORT}`);

    let passedTests = 0;
    let failedTests = 0;

    async function test(name, fn) {
        try {
            await fn();
            console.log(`[PASS] ${name}`);
            passedTests++;
        } catch (err) {
            console.error(`[FAIL] ${name}:`, err.message);
            failedTests++;
        }
    }

    // -------------------------------------------------------------
    // Test 1: Website -> Website Calling
    // -------------------------------------------------------------
    await test('Website -> Website (Voice & Video Call Flow)', async () => {
        const webCaller = await createClient('web_alice');
        const webReceiver = await createClient('web_bob');

        const callReceived = new Promise((resolve) => {
            webReceiver.on('webrtc_signal', (data) => {
                if (data.type === 'call-made') {
                    assert.strictEqual(data.from, 'web_alice');
                    assert.strictEqual(data.payload.isVideo, false);
                    assert(data.payload.offer);
                    // Web receiver accepts call
                    webReceiver.emit('webrtc_signal', {
                        to: 'web_alice',
                        type: 'answer-made',
                        payload: {
                            to: 'web_alice',
                            from: 'web_bob',
                            answer: { type: 'answer', sdp: 'fake-sdp-answer' }
                        }
                    });
                    resolve();
                }
            });
        });

        const answerReceived = new Promise((resolve) => {
            webCaller.on('webrtc_signal', (data) => {
                if (data.type === 'answer-made') {
                    assert.strictEqual(data.from, 'web_bob');
                    assert.strictEqual(data.payload.answer.sdp, 'fake-sdp-answer');
                    resolve();
                }
            });
        });

        // Web Alice initiates voice call
        webCaller.emit('webrtc_signal', {
            to: 'web_bob',
            type: 'call-made',
            payload: {
                to: 'web_bob',
                from: 'web_alice',
                isVideo: false,
                offer: { type: 'offer', sdp: 'fake-sdp-offer' }
            }
        });

        await Promise.all([callReceived, answerReceived]);

        // Exchange ICE candidate
        const iceReceived = new Promise((resolve) => {
            webReceiver.on('webrtc_signal', (data) => {
                if (data.type === 'ice-candidate') {
                    assert.strictEqual(data.from, 'web_alice');
                    assert.strictEqual(data.payload.candidate.candidate, 'candidate:123');
                    resolve();
                }
            });
        });

        webCaller.emit('webrtc_signal', {
            to: 'web_bob',
            type: 'ice-candidate',
            payload: {
                to: 'web_bob',
                from: 'web_alice',
                candidate: { candidate: 'candidate:123', sdpMid: 'audio', sdpMLineIndex: 0 }
            }
        });

        await iceReceived;

        // End Call
        const endReceived = new Promise((resolve) => {
            webReceiver.on('webrtc_signal', (data) => {
                if (data.type === 'call-ended') {
                    assert.strictEqual(data.from, 'web_alice');
                    resolve();
                }
            });
        });

        webCaller.emit('webrtc_signal', {
            to: 'web_bob',
            type: 'call-ended',
            payload: { to: 'web_bob' }
        });

        await endReceived;

        webCaller.disconnect();
        webReceiver.disconnect();
    });

    // -------------------------------------------------------------
    // Test 2: Mobile -> Mobile Calling
    // -------------------------------------------------------------
    await test('Mobile -> Mobile (Pending Offer & Rejection Flow)', async () => {
        const mobCaller = await createClient('mob_carol');
        const mobReceiver = await createClient('mob_dave');

        // Dave receives incoming call and rejects it
        const rejectPromise = new Promise((resolve) => {
            mobCaller.on('webrtc_signal', (data) => {
                if (data.type === 'call-rejected') {
                    assert.strictEqual(data.from, 'mob_dave');
                    resolve();
                }
            });
        });

        mobReceiver.on('webrtc_signal', (data) => {
            if (data.type === 'call-made') {
                assert.strictEqual(data.from, 'mob_carol');
                assert.strictEqual(data.payload.isVideo, true);
                // Dave rejects
                mobReceiver.emit('webrtc_signal', {
                    to: 'mob_carol',
                    type: 'call-rejected',
                    payload: { to: 'mob_carol' }
                });
            }
        });

        // Carol initiates video call
        mobCaller.emit('webrtc_signal', {
            to: 'mob_dave',
            type: 'call-made',
            payload: {
                to: 'mob_dave',
                from: 'mob_carol',
                isVideo: true,
                offer: { type: 'offer', sdp: 'fake-sdp-video-offer' }
            }
        });

        await rejectPromise;

        mobCaller.disconnect();
        mobReceiver.disconnect();
    });

    // -------------------------------------------------------------
    // Test 3: Website -> Mobile Calling
    // -------------------------------------------------------------
    await test('Website -> Mobile (Cross-Platform Signaling Interoperability)', async () => {
        const webCaller = await createClient('web_eve');
        const mobReceiver = await createClient('mob_frank');

        const callReceived = new Promise((resolve) => {
            mobReceiver.on('webrtc_signal', (data) => {
                if (data.type === 'call-made') {
                    assert.strictEqual(data.from, 'web_eve');
                    assert.strictEqual(data.payload.offer.type, 'offer');
                    // Mobile Frank answers
                    mobReceiver.emit('webrtc_signal', {
                        to: 'web_eve',
                        type: 'answer-made',
                        payload: {
                            to: 'web_eve',
                            from: 'mob_frank',
                            answer: { type: 'answer', sdp: 'mobile-frank-answer' }
                        }
                    });
                    resolve();
                }
            });
        });

        const answerReceived = new Promise((resolve) => {
            webCaller.on('webrtc_signal', (data) => {
                if (data.type === 'answer-made') {
                    assert.strictEqual(data.from, 'mob_frank');
                    assert.strictEqual(data.payload.answer.sdp, 'mobile-frank-answer');
                    resolve();
                }
            });
        });

        webCaller.emit('webrtc_signal', {
            to: 'mob_frank',
            type: 'call-made',
            payload: {
                to: 'mob_frank',
                from: 'web_eve',
                isVideo: false,
                offer: { type: 'offer', sdp: 'web-eve-offer' }
            }
        });

        await Promise.all([callReceived, answerReceived]);

        webCaller.disconnect();
        mobReceiver.disconnect();
    });

    // -------------------------------------------------------------
    // Test 4: Mobile -> Website Calling
    // -------------------------------------------------------------
    await test('Mobile -> Website (Cross-Platform Signaling Interoperability)', async () => {
        const mobCaller = await createClient('mob_grace');
        const webReceiver = await createClient('web_heidi');

        const callReceived = new Promise((resolve) => {
            webReceiver.on('webrtc_signal', (data) => {
                if (data.type === 'call-made') {
                    assert.strictEqual(data.from, 'mob_grace');
                    assert.strictEqual(data.payload.offer.type, 'offer');
                    // Web Heidi answers
                    webReceiver.emit('webrtc_signal', {
                        to: 'mob_grace',
                        type: 'answer-made',
                        payload: {
                            to: 'mob_grace',
                            from: 'web_heidi',
                            answer: { type: 'answer', sdp: 'web-heidi-answer' }
                        }
                    });
                    resolve();
                }
            });
        });

        const answerReceived = new Promise((resolve) => {
            mobCaller.on('webrtc_signal', (data) => {
                if (data.type === 'answer-made') {
                    assert.strictEqual(data.from, 'web_heidi');
                    assert.strictEqual(data.payload.answer.sdp, 'web-heidi-answer');
                    resolve();
                }
            });
        });

        mobCaller.emit('webrtc_signal', {
            to: 'web_heidi',
            type: 'call-made',
            payload: {
                to: 'web_heidi',
                from: 'mob_grace',
                isVideo: true,
                offer: { type: 'offer', sdp: 'mob-grace-video-offer' }
            }
        });

        await Promise.all([callReceived, answerReceived]);

        mobCaller.disconnect();
        webReceiver.disconnect();
    });

    // -------------------------------------------------------------
    // Test 5: Offline Recipient Detection
    // -------------------------------------------------------------
    await test('Offline Recipient Detection (Call to non-existent user)', async () => {
        const caller = await createClient('caller_online');

        const rejectedPromise = new Promise((resolve) => {
            caller.on('webrtc_signal', (data) => {
                if (data.type === 'call-rejected' && data.payload.reason === 'offline') {
                    assert.strictEqual(data.to, 'caller_online');
                    resolve();
                }
            });
        });

        caller.emit('webrtc_signal', {
            to: 'ghost_user_999999',
            type: 'call-made',
            payload: {
                to: 'ghost_user_999999',
                from: 'caller_online',
                offer: { type: 'offer', sdp: 'test' }
            }
        });

        await rejectedPromise;
        caller.disconnect();
    });

    // -------------------------------------------------------------
    // Test 6: Sender Identity Verification (Anti-Spoofing)
    // -------------------------------------------------------------
    await test('Anti-Spoofing: Server overrides fake "from" with authenticated socket userId', async () => {
        const maliciousSocket = await createClient('real_user_id');
        const victimSocket = await createClient('victim_recipient');

        const receivedPromise = new Promise((resolve) => {
            victimSocket.on('webrtc_signal', (data) => {
                // Must be authenticated user ID, not the forged one
                assert.strictEqual(data.from, 'real_user_id');
                assert.strictEqual(data.payload.from, 'real_user_id');
                resolve();
            });
        });

        maliciousSocket.emit('webrtc_signal', {
            to: 'victim_recipient',
            from: 'spoofed_admin_id',
            type: 'call-made',
            payload: {
                to: 'victim_recipient',
                from: 'spoofed_admin_id',
                offer: { type: 'offer', sdp: 'test' }
            }
        });

        await receivedPromise;
        maliciousSocket.disconnect();
        victimSocket.disconnect();
    });

    server.close();

    console.log('\n=============================================');
    console.log(`TOTAL TESTS: ${passedTests + failedTests}`);
    console.log(`PASSED: ${passedTests}`);
    console.log(`FAILED: ${failedTests}`);
    console.log('=============================================');

    if (failedTests > 0) {
        process.exit(1);
    } else {
        process.exit(0);
    }
}

runTests().catch(err => {
    console.error('Fatal test error:', err);
    process.exit(1);
});
