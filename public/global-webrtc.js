/**
 * Global WebRTC Incoming & Group Call Handler
 * Handles 1-on-1 and Mesh Network Group Calls
 */

(function() {
    // 1. Inject Call Overlay HTML into the body immediately
    const overlayHtml = `
    <div class="call-overlay" id="global-call-overlay">
        <h2 id="global-call-title" style="margin-bottom: 5px; font-weight: 500;">Incoming Call...</h2>
        <p id="global-call-name" style="margin-bottom: 40px; color: rgba(255,255,255,0.7);">Someone is calling you</p>
        
        <!-- Video Container: Mesh topology (Grid) -->
        <div class="call-video-container" id="global-call-video-container" style="display:flex; flex-wrap:wrap; gap:10px; padding:10px; align-content:center; justify-content:center;">
            <!-- Remote videos injected here dynamically -->
            <video id="global-local-video" autoplay playsinline muted style="width: 200px; height: 150px; border-radius: 12px; object-fit: cover; border: 2px solid var(--primary); box-shadow: 0 5px 15px rgba(0,0,0,0.3); position: absolute; bottom: 20px; right: 20px; z-index: 100;"></video>
        </div>
        
        <div class="call-audio-container" id="global-call-audio-container">
            <div class="audio-avatar pulsing" id="global-audio-avatar">
                <i class="fas fa-users"></i>
            </div>
        </div>
        
        <div class="call-controls" id="global-call-controls-incoming">
            <button class="call-control-btn end-btn" onclick="window.globalRejectCall()">
                <i class="fas fa-phone-slash"></i>
            </button>
            <button class="call-control-btn accept-btn" onclick="window.globalAcceptCall()">
                <i class="fas fa-phone"></i>
            </button>
        </div>

        <div class="call-controls" id="global-call-controls-active" style="display: none;">
            <button class="call-control-btn" id="global-btn-toggle-mic" onclick="window.globalToggleMic()">
                <i class="fas fa-microphone"></i>
            </button>
            <button class="call-control-btn" id="global-btn-toggle-cam" onclick="window.globalToggleCam()" style="display:none;">
                <i class="fas fa-video"></i>
            </button>
            <button class="call-control-btn end-btn" onclick="window.globalEndCall()">
                <i class="fas fa-phone-slash"></i>
            </button>
        </div>
        
        <!-- Native Audio Ringtone component -->
        <audio id="global-ringtone" loop preload="auto">
            <source src="https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3" type="audio/mpeg">
        </audio>
    </div>
    <style>
        .remote-video-peer { flex: 1 1 45%; min-width: 300px; max-width: 100%; height: auto; aspect-ratio: 16/9; object-fit: cover; border-radius: 12px; background: #222; border: 1px solid rgba(255,255,255,0.1); }
    </style>
    `;
    
    document.body.insertAdjacentHTML('beforeend', overlayHtml);

    // 2. State configuration
    function parseJwt(token) {
        if(!token) return null;
        try {
            const base64Url = token.split('.')[1];
            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
            const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
                return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
            }).join(''));
            return JSON.parse(jsonPayload).user.id;
        } catch(e) { return null; }
    }

    function getCurrentUserId() {
        const token = localStorage.getItem('token');
        return parseJwt(token);
    }
    const currentUserId = getCurrentUserId();

    const eventHandlers = {};

    const processedSignals = new Set();
    function getSignalKey(type, payload) {
        if (!payload) return type;
        const from = payload.from || '';
        const to = payload.to || '';
        const candidate = payload.candidate ? (payload.candidate.candidate || '') : '';
        const sdp = (payload.offer && payload.offer.sdp) ? payload.offer.sdp.slice(0, 30) : 
                    ((payload.answer && payload.answer.sdp) ? payload.answer.sdp.slice(0, 30) : '');
        return `${type}_${from}_${to}_${candidate}_${sdp}`;
    }

    function handleIncomingSignal(type, payload) {
        if (!type || !payload) return;
        const key = getSignalKey(type, payload);
        if (processedSignals.has(key)) return;
        processedSignals.add(key);
        if (processedSignals.size > 300) {
            const first = processedSignals.values().next().value;
            processedSignals.delete(first);
        }
        if (eventHandlers[type]) {
            eventHandlers[type](payload);
        }
    }

    // --- 1. Real-time Socket.IO Signaling (Shared with Mobile App) ---
    let socket = null;
    function setupSocket() {
        if (typeof io !== 'undefined') {
            socket = io();
            socket.on('connect', () => {
                socket.emit('join_chat', currentUserId);
            });
            socket.on('webrtc_signal', (data) => {
                if (data && data.type) {
                    handleIncomingSignal(data.type, data.payload || data);
                }
            });
            socket.on('user-joined-call', (data) => {
                if (eventHandlers['user-joined-call']) {
                    eventHandlers['user-joined-call'](data);
                }
            });
            socket.on('user-left-call', (data) => {
                if (eventHandlers['user-left-call']) {
                    eventHandlers['user-left-call'](data);
                }
            });
        }
    }

    if (typeof io !== 'undefined') {
        setupSocket();
    } else {
        const s = document.createElement('script');
        s.src = '/socket.io/socket.io.js';
        s.onload = setupSocket;
        document.head.appendChild(s);
    }

    // --- 2. Guaranteed Firebase Realtime Database Dual Signaling Adapter ---
    let db = null;
    function initFirebaseSignaling() {
        if (db) return;
        if (window.firebase && window.firebase.database && currentUserId) {
            try {
                db = firebase.database();
                const signalsRef = db.ref(`webrtc/signals/${currentUserId}`);
                const statusRef = db.ref(`webrtc/status/${currentUserId}`);
                
                statusRef.set(true);
                statusRef.onDisconnect().remove();

                signalsRef.on('child_added', (snapshot) => {
                    const data = snapshot.val();
                    if (!data || !data.type) return;
                    handleIncomingSignal(data.type, data.payload);
                    snapshot.ref.remove().catch(e => console.error(e));
                });
                console.log('[WebRTC] Dual Firebase RTDB signaling ready for user:', currentUserId);
            } catch (e) {
                console.warn('[WebRTC] Firebase RTDB initialization warning:', e);
            }
        }
    }

    // Attempt immediately and poll until Firebase finishes async script load
    initFirebaseSignaling();
    if (!db) {
        let attempts = 0;
        const fbInterval = setInterval(() => {
            attempts++;
            initFirebaseSignaling();
            if (db || attempts > 40) clearInterval(fbInterval);
        }, 300);
    }

    window.globalSocket = {
        on: (event, handler) => {
            eventHandlers[event] = handler;
        },
        emit: async (event, data, callback) => {
            if (!db) initFirebaseSignaling();
            if (event === 'check-online') {
                const targetId = data;
                if (db) {
                    try {
                        const snap = await db.ref(`webrtc/status/${targetId}`).once('value');
                        if (callback) callback({ isOnline: snap.exists() });
                        return;
                    } catch(e) {}
                }
                if (callback) callback({ isOnline: true });
                return;
            }
            if (event === 'join-room') {
                if (socket) socket.emit('join_room', data);
                return;
            }
            
            // Standard 1-on-1 peer events require a "to" field
            if (data && data.to) {
                const eventMap = {
                    'call-user': 'call-made',
                    'make-answer': 'answer-made',
                    'reject-call': 'call-rejected',
                    'end-call': 'call-ended',
                    'ice-candidate': 'ice-candidate'
                };
                const translatedEvent = eventMap[event] || event;

                // Send via Socket.IO directly to target (Works for Mobile & Web cross-platform)
                if (socket) {
                    socket.emit('webrtc_signal', {
                        to: data.to,
                        type: translatedEvent,
                        payload: data
                    });
                }

                // Dual send via Firebase if available
                if (db) {
                    db.ref(`webrtc/signals/${data.to}`).push({
                        type: translatedEvent,
                        payload: data
                    }).catch(e => console.error(e));
                }
            } 
            // Group Call Logic
            else if (event === 'join-group-call') {
                const { groupId, userId } = data;
                if (socket) {
                    socket.emit('join-group-call', { groupId, userId });
                }
                if (db) {
                    const groupRef = db.ref(`webrtc/groups/${groupId}`);
                    const myNode = groupRef.child(userId);
                    const now = Date.now();
                    myNode.set(now);
                    myNode.onDisconnect().remove();

                    groupRef.on('child_added', snap => {
                        const otherId = snap.key;
                        const joinTime = snap.val();
                        if (otherId !== userId && joinTime > now) {
                            if (eventHandlers['user-joined-call']) {
                                eventHandlers['user-joined-call']({ userId: otherId });
                            }
                        }
                    });

                    groupRef.on('child_removed', snap => {
                        const otherId = snap.key;
                        if (otherId !== userId && eventHandlers['user-left-call']) {
                            eventHandlers['user-left-call']({ userId: otherId });
                        }
                    });
                }
            }
            else if (event === 'leave-group-call') {
                const { groupId, userId } = data;
                if (socket) {
                    socket.emit('leave-group-call', { groupId, userId });
                }
                if (db) {
                    db.ref(`webrtc/groups/${groupId}/${userId}`).remove();
                    db.ref(`webrtc/groups/${groupId}`).off();
                }
            }
        }
    };

    // Mesh Network State
    let peerConnections = {}; // Map of userId -> RTCPeerConnection
    let remoteStreams = {}; // Map of userId -> MediaStream
    let localStream;
    let isCallActive = false;
    let isVideoCall = false;
    
    // 1-on-1 state
    let incomingCallData = null;
    let currentCallTarget = null;
    let currentCallStartTime = null;
    let callTimeoutTimer = null;

    // Group state
    let activeGroupIdForCall = null;
        queuedCandidates = {};

    // Candidate buffering to prevent addIceCandidate on null remoteDescription
    let queuedCandidates = {};
    function addOrQueueCandidate(targetId, candidateData) {
        if (!targetId || !candidateData) return;
        const pc = peerConnections[targetId] || Object.values(peerConnections)[0];
        if (pc && pc.remoteDescription && pc.remoteDescription.type) {
            pc.addIceCandidate(new RTCIceCandidate(candidateData)).catch(e => console.warn('ICE add error:', e));
        } else {
            if (!queuedCandidates[targetId]) queuedCandidates[targetId] = [];
            queuedCandidates[targetId].push(candidateData);
        }
    }
    async function drainQueuedCandidates(targetId) {
        const pc = peerConnections[targetId] || Object.values(peerConnections)[0];
        if (!pc) return;
        const list = queuedCandidates[targetId] || [];
        queuedCandidates[targetId] = [];
        for (const cand of list) {
            try {
                await pc.addIceCandidate(new RTCIceCandidate(cand));
            } catch(e) {
                console.warn('ICE drain error:', e);
            }
        }
    }

    const servers = {
        iceServers: [
            { urls: "stun:stun.l.google.com:19302" },
            { urls: "stun:global.stun.twilio.com:3478" }
        ]
    };

    window.globalSocket.on('connect', () => {
        window.globalSocket.emit('join-room', currentUserId);
    });

    // ----------------------------------------------------
    // Signaling Event Listeners
    // ----------------------------------------------------

    // Receive an offer from another user
    window.globalSocket.on('call-made', async data => {
        if(isCallActive && !activeGroupIdForCall) {
            // Busy in a 1-on-1 call
            window.globalSocket.emit('reject-call', { to: data.from });
            return;
        }
        
        if (activeGroupIdForCall && data.isGroupCall) {
            // Auto-accept group mesh connections if we are already in the group call
            handleGroupOffer(data);
            return;
        }

        // Standard 1-on-1 Incoming Call
        document.getElementById('global-call-overlay').style.display = 'flex';
        document.getElementById('global-call-title').innerText = data.isVideo ? 'Incoming Video Call...' : 'Incoming Audio Call...';
        document.getElementById('global-call-name').innerText = 'User calling...';
        document.getElementById('global-call-controls-incoming').style.display = 'flex';
        document.getElementById('global-call-controls-active').style.display = 'none';
        
        incomingCallData = data;
        currentCallTarget = data.from;
        isVideoCall = data.isVideo;

        // Play Ringtone
        const ringbox = document.getElementById('global-ringtone');
        if (ringbox) {
            ringbox.currentTime = 0;
            ringbox.play().catch(e => console.log('Autoplay audio blocked', e));
        }

        // 40 second auto-miss timeout
        if (callTimeoutTimer) clearTimeout(callTimeoutTimer);
        callTimeoutTimer = setTimeout(() => {
            if (!isCallActive) {
                window.globalRejectCall();
                if(window.showToast) window.showToast('Missed call', 'info');
            }
        }, 40000);
    });

    window.globalSocket.on('answer-made', async data => {
        const targetPc = peerConnections[data.from] || Object.values(peerConnections)[0];
        if (targetPc) {
            await targetPc.setRemoteDescription(new RTCSessionDescription(data.answer));
            await drainQueuedCandidates(data.from);
        }

        document.getElementById('global-call-title').innerText = activeGroupIdForCall ? 'Group Call Active' : 'Connected';
        document.getElementById('global-audio-avatar').classList.remove('pulsing');
        if (!currentCallStartTime) currentCallStartTime = Date.now();
        if (callTimeoutTimer) clearTimeout(callTimeoutTimer);
    });

    window.globalSocket.on('call-rejected', data => {
        if(window.showToast) window.showToast('Call was declined', 'error');
        globalEndUI();
    });

    window.globalSocket.on('call-ended', data => {
        // If it's a 1-on-1 call
        if(!activeGroupIdForCall) {
            if(window.showToast) window.showToast('Call ended', 'info');
            globalEndUI();
        } else {
            // Group call: Someone dropped. We should remove their video.
            // Handled mostly by user-left-call below
        }
    });

    window.globalSocket.on('ice-candidate', data => {
        addOrQueueCandidate(data.from, data.candidate);
    });

    // ----------------------------------------------------
    // Group Call Specific Listeners
    // ----------------------------------------------------
    
    window.globalSocket.on('user-joined-call', async data => {
        if (!activeGroupIdForCall) return; // Not in a group call
        console.log(`[WebRTC] User ${data.userId} joined the group. Initiating connection...`);
        // I am already in the room. Someone joined. I must initiate the offer to them.
        await initiatePeerConnection(data.userId, isVideoCall, true);
    });

    window.globalSocket.on('user-left-call', data => {
        if (!activeGroupIdForCall) return;
        removePeer(data.userId);
    });

    // ----------------------------------------------------
    // Peer Connection Management
    // ----------------------------------------------------

    async function handleGroupOffer(data) {
        // An offer from another peer in the same group call
        try {
            const pc = createPeerConnection(data.from, true);
            await pc.setRemoteDescription(new RTCSessionDescription(data.offer));
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            window.globalSocket.emit('make-answer', {
                answer: answer,
                to: data.from,
                from: currentUserId
            });
        } catch(e) { console.error("Error handling group offer", e); }
    }

    function createPeerConnection(targetId, isGroup) {
        if (peerConnections[targetId]) return peerConnections[targetId];

        const pc = new RTCPeerConnection(servers);
        peerConnections[targetId] = pc;

        if (localStream) {
            localStream.getTracks().forEach(track => pc.addTrack(track, localStream));
        }

        pc.ontrack = event => {
            const stream = event.streams[0];
            remoteStreams[targetId] = stream;

            if (isGroup) {
                // Add dynamically to grid
                let vid = document.getElementById(`remote-video-${targetId}`);
                if (!vid) {
                    vid = document.createElement('video');
                    vid.id = `remote-video-${targetId}`;
                    vid.className = 'remote-video-peer';
                    vid.autoplay = true;
                    vid.playsinline = true;
                    const container = document.getElementById('global-call-video-container');
                    container.insertBefore(vid, document.getElementById('global-local-video')); // insert before local video
                }
                vid.srcObject = stream;
            } else {
                // 1-on-1 logic - use the single video wrapper
                let vid = document.getElementById('global-remote-video');
                if (!vid) {
                    vid = document.createElement('video');
                    vid.id = 'global-remote-video';
                    vid.className = 'remote-video-peer';
                    vid.autoplay = true;
                    vid.playsinline = true;
                    vid.style.width = '100%';
                    vid.style.height = '100%';
                    const container = document.getElementById('global-call-video-container');
                    container.insertBefore(vid, document.getElementById('global-local-video'));
                }
                vid.srcObject = stream;
            }
        };

        pc.onicecandidate = event => {
            if(event.candidate) {
                window.globalSocket.emit('ice-candidate', { candidate: event.candidate, to: targetId, from: currentUserId });
            }
        };

        return pc;
    }

    async function initiatePeerConnection(targetId, isVideo, isGroup) {
        try {
            const pc = createPeerConnection(targetId, isGroup);
            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);
            window.globalSocket.emit('call-user', {
                offer: offer,
                to: targetId,
                from: currentUserId,
                isVideo: isVideo,
                isGroupCall: isGroup
            });

            // 40 second ring timeout for standard calls
            if (!isGroup) {
                if(callTimeoutTimer) clearTimeout(callTimeoutTimer);
                callTimeoutTimer = setTimeout(() => {
                    if(!isCallActive) {
                        window.globalEndCall();
                        if(window.showToast) window.showToast('User unavailable', 'info');
                    }
                }, 40000);
            }
        } catch(e) { console.error('Failed to init PC', e); }
    }

    function removePeer(userId) {
        if (peerConnections[userId]) {
            peerConnections[userId].close();
            delete peerConnections[userId];
        }
        delete remoteStreams[userId];
        const vid = document.getElementById(`remote-video-${userId}`);
        if(vid) vid.remove();
    }

    // ----------------------------------------------------
    // User Actions
    // ----------------------------------------------------

    window.globalRejectCall = function() {
        if(incomingCallData) {
            window.globalSocket.emit('reject-call', { to: incomingCallData.from });
        }
        globalEndUI();
    };

    window.globalAcceptCall = async function() {
        try {
            if (!incomingCallData || !incomingCallData.from || !incomingCallData.offer) {
                console.error('No incoming call data available to accept');
                return;
            }
            try {
                if (isVideoCall) {
                    localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
                } else {
                    localStream = await navigator.mediaDevices.getUserMedia({ video: false, audio: true });
                }
            } catch (mediaErr) {
                if (isVideoCall) {
                    localStream = await navigator.mediaDevices.getUserMedia({ video: false, audio: true });
                    isVideoCall = false;
                } else {
                    throw mediaErr;
                }
            }
            document.getElementById('global-local-video').srcObject = localStream;
            
            document.getElementById('global-call-video-container').style.display = isVideoCall ? 'flex' : 'none';
            document.getElementById('global-call-audio-container').style.display = isVideoCall ? 'none' : 'flex';
            document.getElementById('global-btn-toggle-cam').style.display = isVideoCall ? 'flex' : 'none';
            
            document.getElementById('global-call-controls-incoming').style.display = 'none';
            document.getElementById('global-call-controls-active').style.display = 'flex';
            document.getElementById('global-call-title').innerText = 'Connecting...';
            document.getElementById('global-audio-avatar').classList.remove('pulsing');

            const pc = createPeerConnection(incomingCallData.from, false);
            await pc.setRemoteDescription(new RTCSessionDescription(incomingCallData.offer));
            await drainQueuedCandidates(incomingCallData.from);

            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);

            window.globalSocket.emit('make-answer', {
                answer: answer,
                to: incomingCallData.from,
                from: getCurrentUserId()
            });
            
            isCallActive = true;
            currentCallStartTime = Date.now();
        } catch(e) {
            console.error('Call Accept Error:', e);
            window.globalRejectCall();
        }
    };

    window.globalEndCall = async function() {
        if (activeGroupIdForCall) {
            window.globalSocket.emit('leave-group-call', { groupId: activeGroupIdForCall, userId: currentUserId });
            // Log duration maybe? 
        } else if(currentCallTarget) {
            window.globalSocket.emit('end-call', { to: currentCallTarget });
            
            // Log the call history message 
            let durationStr = "0s";
            if(currentCallStartTime) {
                const diff = Date.now() - currentCallStartTime;
                const secs = Math.floor(diff / 1000);
                const mins = Math.floor(secs / 60);
                durationStr = mins > 0 ? `${mins}m ${secs % 60}s` : `${secs}s`;
            }
            const logContent = `[SystemLog: ${isVideoCall ? 'Video ' : 'Audio '}Call Ended - ${durationStr}]`;
            logSystemMessage(currentCallTarget, logContent);
        }
        globalEndUI();
    };

    function globalEndUI() {
        if (callTimeoutTimer) clearTimeout(callTimeoutTimer);
        const ringbox = document.getElementById('global-ringtone');
        if (ringbox) {
            ringbox.pause();
            ringbox.currentTime = 0;
        }

        isCallActive = false;
        incomingCallData = null;
        currentCallTarget = null;
        currentCallStartTime = null;
        activeGroupIdForCall = null;

        document.getElementById('global-call-overlay').style.display = 'none';
        document.getElementById('global-btn-toggle-mic').innerHTML = '<i class="fas fa-microphone"></i>';
        
        if (localStream) {
            localStream.getTracks().forEach(track => track.stop());
            localStream = null;
        }

        Object.keys(peerConnections).forEach(id => removePeer(id));
        
        // Clean up the main video if it was 1-on-1
        const mainVid = document.getElementById('global-remote-video');
        if (mainVid) mainVid.remove();
    }
    window.globalEndUI = globalEndUI;

    window.globalToggleMic = function() {
        if (!localStream) return;
        const audioTrack = localStream.getAudioTracks()[0];
        if (audioTrack) {
            audioTrack.enabled = !audioTrack.enabled;
            const btn = document.getElementById('global-btn-toggle-mic');
            btn.innerHTML = audioTrack.enabled ? '<i class="fas fa-microphone"></i>' : '<i class="fas fa-microphone-slash"></i>';
            btn.style.background = audioTrack.enabled ? '' : '#ef4444';
        }
    };

    window.globalToggleCam = function() {
        if (!localStream) return;
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
            videoTrack.enabled = !videoTrack.enabled;
            const btn = document.getElementById('global-btn-toggle-cam');
            btn.innerHTML = videoTrack.enabled ? '<i class="fas fa-video"></i>' : '<i class="fas fa-video-slash"></i>';
            btn.style.background = videoTrack.enabled ? '' : '#ef4444';
        }
    };

    async function logSystemMessage(receiverId, content) {
        try {
            const token = localStorage.getItem('token');
            // We bypass CryptoJS and send plaintext because it's a System Log
            await fetch(`/api/messages/${receiverId}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-auth-token': token
                },
                body: JSON.stringify({ 
                    content: content, 
                    attachmentUrl: null, 
                    attachmentType: 'none',
                    isSystemLog: true
                })
            });
        } catch(e) { console.error('Failed to log call history', e); }
    }
    
    // ----------------------------------------------------
    // Initiators
    // ----------------------------------------------------

    window.globalInitiateCall = async function(targetUserId, targetUsername, isVideo) {
        const uid = getCurrentUserId();
        if (!uid) {
            if (window.showToast) window.showToast('Please log in to make a call.', 'error');
            return;
        }
        currentCallTarget = targetUserId;
        isVideoCall = !!isVideo;
            
        try {
            if (isVideoCall) {
                try {
                    localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
                } catch (mediaErr) {
                    localStream = await navigator.mediaDevices.getUserMedia({ video: false, audio: true });
                    isVideo = false;
                    isVideoCall = false;
                    if (window.showToast) window.showToast('Camera unavailable, continuing with audio only', 'info');
                }
            } else {
                localStream = await navigator.mediaDevices.getUserMedia({ video: false, audio: true });
            }

            document.getElementById('global-local-video').srcObject = localStream;
            document.getElementById('global-call-video-container').style.display = isVideoCall ? 'flex' : 'none';
            document.getElementById('global-call-audio-container').style.display = isVideoCall ? 'none' : 'flex';
            
            document.getElementById('global-call-overlay').style.display = 'flex';
            document.getElementById('global-call-controls-incoming').style.display = 'none';
            document.getElementById('global-call-controls-active').style.display = 'flex';
            document.getElementById('global-btn-toggle-cam').style.display = isVideoCall ? 'flex' : 'none';
            
            document.getElementById('global-call-name').innerText = targetUsername || 'User';
            document.getElementById('global-call-title').innerText = 'Connecting...';
            document.getElementById('global-audio-avatar').classList.add('pulsing');

            await initiatePeerConnection(targetUserId, isVideoCall, false);
            isCallActive = true;
        } catch(e) {
            console.error(e);
            window.globalEndUI();
            if(window.showToast) window.showToast('Microphone access denied.', 'error');
        }
    };

    window.globalInitiateGroupCall = async function(groupId, groupName, isVideo) {
        activeGroupIdForCall = groupId;
        isVideoCall = isVideo;
        currentCallTarget = null;
        
        try {
            try {
                localStream = await navigator.mediaDevices.getUserMedia({ video: isVideo, audio: true });
            } catch (mediaErr) {
                if (isVideo) {
                    localStream = await navigator.mediaDevices.getUserMedia({ video: false, audio: true });
                    isVideo = false;
                    isVideoCall = false;
                } else {
                    throw mediaErr;
                }
            }
            document.getElementById('global-local-video').srcObject = localStream;
            document.getElementById('global-call-video-container').style.display = isVideo ? 'flex' : 'none';
            document.getElementById('global-call-audio-container').style.display = isVideo ? 'none' : 'flex';
            
            document.getElementById('global-call-overlay').style.display = 'flex';
            document.getElementById('global-call-controls-incoming').style.display = 'none';
            document.getElementById('global-call-controls-active').style.display = 'flex';
            document.getElementById('global-btn-toggle-cam').style.display = isVideo ? 'flex' : 'none';
            
            document.getElementById('global-call-name').innerText = groupName || 'Group';
            document.getElementById('global-call-title').innerText = 'Joined Group Call';
            document.getElementById('global-audio-avatar').classList.remove('pulsing');

            // Tell server we joined the room
            window.globalSocket.emit('join-group-call', { groupId, userId: currentUserId });
            isCallActive = true;
        } catch(e) {
            console.error(e);
            window.globalEndUI();
            if(window.showToast) window.showToast('Microphone/Camera access denied.', 'error');
        }
    };

})();
