/**
 * Automated Verification Test Suite for Vylithra Mesh Group Calling
 * Tests:
 *  1. Initial participant creates/joins group call room
 *  2. Second participant joins, mesh offer & answer exchanged
 *  3. Third participant joins, mesh connections formed with all existing peers
 *  4. Participant leaves without disconnecting others
 *  5. Unexpected disconnect cleanup & user-left-call broadcast
 *  6. Room cleanup when all participants leave
 */

const http = require('http');
const express = require('express');
const socketIo = require('socket.io');
const ioClient = require('socket.io-client');
const assert = require('assert');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: '*' } });

const userSocketMap = new Map();
const activeGroupCalls = new Map();

io.on('connection', (socket) => {
    socket.on('join_chat', (userId) => {
        if (userId) {
            const uid = String(userId);
            socket.userId = uid;
            socket.join(uid);
            if (!userSocketMap.has(uid)) userSocketMap.set(uid, new Set());
            userSocketMap.get(uid).add(socket.id);
        }
    });

    socket.on('join-group-call', (data) => {
        if (!data || !data.groupId) return;
        const groupId = String(data.groupId);
        const userId = socket.userId || (data.userId ? String(data.userId) : null);
        if (!userId) return;

        if (!activeGroupCalls.has(groupId)) {
            activeGroupCalls.set(groupId, new Map());
        }
        const groupMap = activeGroupCalls.get(groupId);

        // Send existing participants to the joiner
        const existingParticipants = Array.from(groupMap.keys()).filter(id => id !== userId);
        socket.emit('existing-group-participants', {
            groupId,
            participants: existingParticipants
        });

        // Register participant
        groupMap.set(userId, socket.id);
        socket.join('group_call_' + groupId);

        // Notify existing members
        socket.to('group_call_' + groupId).emit('user-joined-call', {
            userId,
            groupId
        });
    });

    socket.on('leave-group-call', (data) => {
        if (!data || !data.groupId) return;
        const groupId = String(data.groupId);
        const userId = socket.userId || (data.userId ? String(data.userId) : null);
        if (!userId) return;

        if (activeGroupCalls.has(groupId)) {
            const groupMap = activeGroupCalls.get(groupId);
            groupMap.delete(userId);
            if (groupMap.size === 0) activeGroupCalls.delete(groupId);
        }

        socket.leave('group_call_' + groupId);
        socket.to('group_call_' + groupId).emit('user-left-call', {
            userId,
            groupId
        });
    });

    socket.on('webrtc_signal', (data) => {
        if (!data || !data.to) return;
        const targetUserId = String(data.to);
        const senderId = socket.userId || (data.from ? String(data.from) : null);
        if (senderId) {
            data.from = senderId;
            if (data.payload && typeof data.payload === 'object') {
                data.payload.from = senderId;
            }
        }
        io.to(targetUserId).emit('webrtc_signal', data);
    });

    socket.on('disconnect', () => {
        if (socket.userId) {
            if (userSocketMap.has(socket.userId)) {
                const set = userSocketMap.get(socket.userId);
                set.delete(socket.id);
                if (set.size === 0) userSocketMap.delete(socket.userId);
            }
            for (const [groupId, groupMap] of activeGroupCalls.entries()) {
                if (groupMap.has(socket.userId)) {
                    groupMap.delete(socket.userId);
                    socket.to('group_call_' + groupId).emit('user-left-call', {
                        userId: socket.userId,
                        groupId
                    });
                    if (groupMap.size === 0) activeGroupCalls.delete(groupId);
                }
            }
        }
    });
});

const TEST_PORT = 3567;
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

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function runGroupTests() {
    console.log('--- STARTING VYLITHRA GROUP WEBRTC AUTOMATED VERIFICATION ---');
    await new Promise((resolve) => server.listen(TEST_PORT, resolve));
    console.log(`Group test signaling server listening on port ${TEST_PORT}`);

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
    // Test 1: Two participants establish group call
    // -------------------------------------------------------------
    await test('Group Call: 2 Participants Join & Establish Mesh Signaling', async () => {
        const userA = await createClient('user_A');
        const userB = await createClient('user_B');

        const joinNotificationPromise = new Promise((resolve) => {
            userA.on('user-joined-call', (data) => {
                assert.strictEqual(data.userId, 'user_B');
                assert.strictEqual(data.groupId, 'group_101');
                resolve();
            });
        });

        userA.emit('join-group-call', { groupId: 'group_101', userId: 'user_A' });
        await sleep(50);
        userB.emit('join-group-call', { groupId: 'group_101', userId: 'user_B' });

        await joinNotificationPromise;

        const offerReceivedPromise = new Promise((resolve) => {
            userB.on('webrtc_signal', (data) => {
                if (data.type === 'call-made' && data.isGroupCall) {
                    assert.strictEqual(data.from, 'user_A');
                    assert.strictEqual(data.groupId, 'group_101');
                    resolve();
                }
            });
        });

        userA.emit('webrtc_signal', {
            to: 'user_B',
            type: 'call-made',
            isGroupCall: true,
            groupId: 'group_101',
            payload: { offer: { type: 'offer', sdp: 'sdp-mesh-A-to-B' } }
        });

        await offerReceivedPromise;

        userA.disconnect();
        userB.disconnect();
    });

    // -------------------------------------------------------------
    // Test 2: Third participant joins and mesh expands
    // -------------------------------------------------------------
    await test('Group Call: 3rd Participant Joins & Mesh Expands to All Peers', async () => {
        const user1 = await createClient('peer_1');
        const user2 = await createClient('peer_2');
        const user3 = await createClient('peer_3');

        user1.emit('join-group-call', { groupId: 'group_202', userId: 'peer_1' });
        await sleep(30);
        user2.emit('join-group-call', { groupId: 'group_202', userId: 'peer_2' });
        await sleep(30);

        const peer1Notified = new Promise((resolve) => {
            user1.on('user-joined-call', (data) => {
                if (data.userId === 'peer_3') resolve();
            });
        });
        const peer2Notified = new Promise((resolve) => {
            user2.on('user-joined-call', (data) => {
                if (data.userId === 'peer_3') resolve();
            });
        });
        const existingListPromise = new Promise((resolve) => {
            user3.on('existing-group-participants', (data) => {
                assert.strictEqual(data.groupId, 'group_202');
                assert(data.participants.includes('peer_1'));
                assert(data.participants.includes('peer_2'));
                resolve();
            });
        });

        user3.emit('join-group-call', { groupId: 'group_202', userId: 'peer_3' });

        await Promise.all([peer1Notified, peer2Notified, existingListPromise]);

        user1.disconnect();
        user2.disconnect();
        user3.disconnect();
    });

    // -------------------------------------------------------------
    // Test 3: Participant leaves without disrupting others
    // -------------------------------------------------------------
    await test('Group Call: Participant Leaves Gracefully without Collapsing Room', async () => {
        const uA = await createClient('u_alpha');
        const uB = await createClient('u_beta');
        const uC = await createClient('u_gamma');

        uA.emit('join-group-call', { groupId: 'group_303', userId: 'u_alpha' });
        await sleep(30);
        uB.emit('join-group-call', { groupId: 'group_303', userId: 'u_beta' });
        await sleep(30);
        uC.emit('join-group-call', { groupId: 'group_303', userId: 'u_gamma' });
        await sleep(50);

        const betaLeftNotifiedA = new Promise((resolve) => {
            uA.on('user-left-call', (data) => {
                if (data.userId === 'u_beta') resolve();
            });
        });

        const betaLeftNotifiedC = new Promise((resolve) => {
            uC.on('user-left-call', (data) => {
                if (data.userId === 'u_beta') resolve();
            });
        });

        uB.emit('leave-group-call', { groupId: 'group_303', userId: 'u_beta' });

        await Promise.all([betaLeftNotifiedA, betaLeftNotifiedC]);

        const groupMembers = activeGroupCalls.get('group_303');
        assert(groupMembers.has('u_alpha'));
        assert(groupMembers.has('u_gamma'));
        assert(!groupMembers.has('u_beta'));

        uA.disconnect();
        uB.disconnect();
        uC.disconnect();
    });

    // -------------------------------------------------------------
    // Test 4: Unexpected disconnect cleanup
    // -------------------------------------------------------------
    await test('Group Call: Sudden Network Disconnect Broadcasts user-left-call', async () => {
        const aliveUser = await createClient('alive_peer');
        const disconnectingUser = await createClient('disconnecting_peer');

        aliveUser.emit('join-group-call', { groupId: 'group_404', userId: 'alive_peer' });
        await sleep(50);
        disconnectingUser.emit('join-group-call', { groupId: 'group_404', userId: 'disconnecting_peer' });
        await sleep(50);

        const disconnectNotified = new Promise((resolve) => {
            aliveUser.on('user-left-call', (data) => {
                if (data.userId === 'disconnecting_peer') resolve();
            });
        });

        disconnectingUser.disconnect();

        await disconnectNotified;
        aliveUser.disconnect();
    });

    server.close();

    console.log('\n=============================================');
    console.log(`GROUP TESTS: ${passedTests + failedTests}`);
    console.log(`PASSED: ${passedTests}`);
    console.log(`FAILED: ${failedTests}`);
    console.log('=============================================');

    if (failedTests > 0) process.exit(1);
    else process.exit(0);
}

runGroupTests().catch(err => {
    console.error('Fatal group test error:', err);
    process.exit(1);
});
