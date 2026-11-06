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
            <source src="/ringtone.mp3" type="audio/mpeg">
        </audio>
    </div>
    <style>
        .remote-video-peer { flex: 1 1 45%; min-width: 300px; max-width: 100%; height: auto; aspect-ratio: 16/9; object-fit: cover; border-radius: 12px; background: #222; border: 1px solid rgba(255,255,255,0.1); }
    </style>
    `;
    
    document.body.insertAdjacentHTML('beforeend', overlayHtml);

    
    // Call Audio Controller: Incoming Call Ringtone & Outgoing Receiver Tone (Ringback)
    let ringtoneAudioContext = null;
    let ringtoneOscillatorTimer = null;
    let ringbackAudioContext = null;
    let ringbackTimer = null;
    let audioUnlocked = false;

    // Browser Autoplay Policy Unlocker: Pre-unlock audio on the very first user interaction
    function unlockAudio() {
        if (audioUnlocked) return;
        const ringbox = document.getElementById('global-ringtone');
        if (ringbox) {
            ringbox.volume = 0;
            const p = ringbox.play();
            if (p !== undefined) {
                p.then(() => {
                    ringbox.pause();
                    ringbox.currentTime = 0;
                    ringbox.volume = 1;
                    audioUnlocked = true;
                }).catch(() => {});
            }
        }
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (AudioCtx) {
            if (!ringtoneAudioContext) ringtoneAudioContext = new AudioCtx();
            if (ringtoneAudioContext.state === 'suspended') {
                ringtoneAudioContext.resume().then(() => { audioUnlocked = true; }).catch(() => {});
            }
        }
    }
    ['click', 'pointerdown', 'touchstart', 'keydown'].forEach(evt => {
        window.addEventListener(evt, unlockAudio, { passive: true, capture: true });
    });

    // --- INCOMING CALL RINGTONE ---
    window.playCallRingtone = function() {
        const ringbox = document.getElementById('global-ringtone');
        if (ringbox) {
            ringbox.currentTime = 0;
            ringbox.volume = 1;
            const playPromise = ringbox.play();
            if (playPromise !== undefined) {
                playPromise.then(() => {
                    // Audio playing successfully
                }).catch(e => {
                    console.warn('[Vylithra Call] Autoplay blocked ringtone; triggering Web Audio chime fallback:', e);
                    startWebAudioChime();

                    // Modern browser fallback: as soon as user touches or moves their mouse on screen, start audio!
                    const resumeOnInteraction = () => {
                        window.removeEventListener('pointerdown', resumeOnInteraction);
                        window.removeEventListener('mousemove', resumeOnInteraction);
                        window.removeEventListener('touchstart', resumeOnInteraction);
                        window.removeEventListener('keydown', resumeOnInteraction);
                        if (incomingCallData) {
                            ringbox.currentTime = 0;
                            ringbox.play().then(() => {
                                stopWebAudioChime();
                            }).catch(() => {});
                        }
                    };
                    window.addEventListener('pointerdown', resumeOnInteraction, { once: true, passive: true });
                    window.addEventListener('mousemove', resumeOnInteraction, { once: true, passive: true });
                    window.addEventListener('touchstart', resumeOnInteraction, { once: true, passive: true });
                    window.addEventListener('keydown', resumeOnInteraction, { once: true, passive: true });
                });
            }
        } else {
            startWebAudioChime();
        }
    };

    window.stopCallRingtone = function() {
        const ringbox = document.getElementById('global-ringtone');
        if (ringbox) {
            ringbox.pause();
            ringbox.currentTime = 0;
        }
        stopWebAudioChime();
    };

    function startWebAudioChime() {
        try {
            if (!ringtoneAudioContext) {
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                if (!AudioCtx) return;
                ringtoneAudioContext = new AudioCtx();
            }
            if (ringtoneAudioContext.state === 'suspended') {
                ringtoneAudioContext.resume();
            }
            if (ringtoneOscillatorTimer) clearInterval(ringtoneOscillatorTimer);
            
            function playChimeTone() {
                if (!ringtoneAudioContext) return;
                const now = ringtoneAudioContext.currentTime;
                // Double chime: 523Hz (C5) then 659Hz (E5)
                [ { f: 523.25, t: 0 }, { f: 659.25, t: 0.15 } ].forEach(note => {
                    const osc = ringtoneAudioContext.createOscillator();
                    const gain = ringtoneAudioContext.createGain();
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(note.f, now + note.t);
                    gain.gain.setValueAtTime(0.2, now + note.t);
                    gain.gain.exponentialRampToValueAtTime(0.001, now + note.t + 0.35);
                    osc.connect(gain);
                    gain.connect(ringtoneAudioContext.destination);
                    osc.start(now + note.t);
                    osc.stop(now + note.t + 0.4);
                });
            }
            playChimeTone();
            ringtoneOscillatorTimer = setInterval(playChimeTone, 1800);
        } catch (err) {
            console.log('Web Audio ringtone fallback error:', err);
        }
    }

    function stopWebAudioChime() {
        if (ringtoneOscillatorTimer) {
            clearInterval(ringtoneOscillatorTimer);
            ringtoneOscillatorTimer = null;
        }
        if (ringtoneAudioContext) {
            ringtoneAudioContext.close().catch(() => {});
            ringtoneAudioContext = null;
        }
    }

    // --- OUTGOING RECEIVER TONE (RINGBACK) ---
    // Standard European/ITU-T pleasant telephone ringback tone: 440Hz + 480Hz dual sine chime
    window.playOutgoingRingbackTone = function() {
        try {
            if (!ringbackAudioContext) {
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                if (!AudioCtx) return;
                ringbackAudioContext = new AudioCtx();
            }
            if (ringbackAudioContext.state === 'suspended') {
                ringbackAudioContext.resume();
            }
            if (ringbackTimer) clearInterval(ringbackTimer);

            function playRingbackPulse() {
                if (!ringbackAudioContext) return;
                const now = ringbackAudioContext.currentTime;
                // Dual frequency 440Hz & 480Hz burst (1.5 seconds on)
                [440, 480].forEach(freq => {
                    const osc = ringbackAudioContext.createOscillator();
                    const gain = ringbackAudioContext.createGain();
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(freq, now);
                    gain.gain.setValueAtTime(0.08, now);
                    gain.gain.setValueAtTime(0.08, now + 1.4);
                    gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.5);
                    osc.connect(gain);
                    gain.connect(ringbackAudioContext.destination);
                    osc.start(now);
                    osc.stop(now + 1.5);
                });
            }

            playRingbackPulse();
            ringbackTimer = setInterval(playRingbackPulse, 3500); // 1.5s tone, 2s silence cadence
        } catch (err) {
            console.log('Outgoing ringback tone error:', err);
        }
    };

    window.stopOutgoingRingbackTone = function() {
        if (ringbackTimer) {
            clearInterval(ringbackTimer);
            ringbackTimer = null;
        }
        if (ringbackAudioContext) {
            ringbackAudioContext.close().catch(() => {});
            ringbackAudioContext = null;
        }
    };

    // 2. State configuration
    function parseJwt(token) {
        if(!token) return null;
        try {
            const base64Url = token.split('.')[1];
            if (!base64Url) return null;
            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
            const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
                return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
            }).join(''));
            const parsed = JSON.parse(jsonPayload);
            return (parsed.user && (parsed.user.id || parsed.user._id)) || parsed.id || parsed._id || null;
        } catch(e) { return null; }
    }

    function getCurrentUserId() {
        const token = localStorage.getItem('token');
        return parseJwt(token);
    }
    window.getCurrentUserId = getCurrentUserId;

    function getCurrentUsername() {
        try {
            const userStr = localStorage.getItem('user');
            if (userStr) {
                const u = JSON.parse(userStr);
                const uname = u.username || u.name;
                if (uname && uname !== 'undefined' && uname !== 'null' && String(uname).trim() !== '') {
                    return String(uname).trim();
                }
            }
        } catch(e) {}
        try {
            const stored = localStorage.getItem('username');
            if (stored && stored !== 'undefined' && stored !== 'null' && String(stored).trim() !== '') {
                return String(stored).trim();
            }
        } catch(e) {}
        try {
            const token = localStorage.getItem('token');
            if (token) {
                const base64Url = token.split('.')[1];
                if (base64Url) {
                    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
                    const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
                        return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
                    }).join(''));
                    const parsed = JSON.parse(jsonPayload);
                    const uname = (parsed.user && (parsed.user.username || parsed.user.name)) || parsed.username || parsed.name;
                    if (uname && uname !== 'undefined' && uname !== 'null' && String(uname).trim() !== '') {
                        return String(uname).trim();
                    }
                }
            }
        } catch(e) {}
        return 'User';
    }

    
    // --- Data Saving / Low-Bandwidth WebRTC Optimizations ---
    function getCallMediaConstraints(videoRequested) {
        const audioConstraints = {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            channelCount: 1, // Mono for voice reduces bandwidth by 50%
            sampleRate: 24000
        };
        if (!videoRequested) {
            return { audio: audioConstraints, video: false };
        }
        // Optimized 480p @ 20-24fps uses ~80% less data than unconstrained 1080p
        return {
            audio: audioConstraints,
            video: {
                width: { ideal: 640, max: 854 },
                height: { ideal: 480, max: 480 },
                frameRate: { ideal: 20, max: 24 },
                facingMode: 'user'
            }
        };
    }

    async function applyDataSavingBitrateLimits(pc) {
        if (!pc || !pc.getSenders) return;
        try {
            const senders = pc.getSenders();
            for (const sender of senders) {
                if (sender && sender.track) {
                    if (sender.track.kind === 'video') {
                        const params = sender.getParameters();
                        if (!params.encodings || params.encodings.length === 0) {
                            params.encodings = [{}];
                        }
                        params.encodings[0].maxBitrate = 450000; // 450 kbps cap (saves 80%+ data)
                        params.encodings[0].maxFramerate = 24;
                        await sender.setParameters(params);
                    } else if (sender.track.kind === 'audio') {
                        const params = sender.getParameters();
                        if (!params.encodings || params.encodings.length === 0) {
                            params.encodings = [{}];
                        }
                        params.encodings[0].maxBitrate = 32000; // 32 kbps cap (saves 70%+ audio data)
                        await sender.setParameters(params);
                    }
                }
            }
        } catch (e) {
            console.warn('[WebRTC] Bitrate limit notice:', e.message);
        }
    }

    function optimizeSdpForDataSaving(sdp) {
        if (!sdp) return sdp;
        try {
            // Enable Opus DTX (Discontinuous Transmission) so silence uses ~0 data
            if (sdp.includes('opus/48000')) {
                sdp = sdp.replace(/a=fmtp:(d+) (.*opus.*)/gi, function(match, pt, rest) {
                    if (!rest.includes('usedtx=1')) rest += ';usedtx=1';
                    if (!rest.includes('stereo=0')) rest += ';stereo=0';
                    if (!rest.includes('maxaveragebitrate=')) rest += ';maxaveragebitrate=32000';
                    return `a=fmtp:${pt} ${rest}`;
                });
            }
        } catch (e) {}
        return sdp;
    }

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
                const uid = getCurrentUserId();
                if (uid) {
                    socket.emit('join_chat', uid);
                    socket.emit('join-chat', uid);
                    socket.emit('join_room', uid);
                    socket.emit('join-room', uid);
                }
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
    const firebaseConfig = {
        apiKey: "AIzaSyBMe2R5iWYj_H4IZ5OpkXSsyc9ULM5Esbw",
        authDomain: "luminary-eae16.firebaseapp.com",
        databaseURL: "https://luminary-eae16-default-rtdb.firebaseio.com",
        projectId: "luminary-eae16",
        storageBucket: "luminary-eae16.firebasestorage.app",
        messagingSenderId: "271803460699",
        appId: "1:271803460699:web:fcdd88f117dfe0817de37e"
    };

    function ensureFirebaseLoaded(cb) {
        if (window.firebase && window.firebase.database && window.firebase.auth) {
            initFirebaseSignaling();
            if (cb) cb();
            return;
        }
        function loadScript(src, next) {
            const s = document.createElement('script');
            s.src = src;
            s.async = true;
            s.onload = next;
            s.onerror = () => { console.warn('[WebRTC] Script load failed:', src); };
            document.head.appendChild(s);
        }
        if (!window.firebase) {
            loadScript('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js', () => {
                loadScript('https://www.gstatic.com/firebasejs/10.8.0/firebase-auth-compat.js', () => {
                    loadScript('https://www.gstatic.com/firebasejs/10.8.0/firebase-database-compat.js', () => {
                        initFirebaseSignaling();
                        if (cb) cb();
                    });
                });
            });
        } else if (!window.firebase.auth) {
            loadScript('https://www.gstatic.com/firebasejs/10.8.0/firebase-auth-compat.js', () => {
                if (!window.firebase.database) {
                    loadScript('https://www.gstatic.com/firebasejs/10.8.0/firebase-database-compat.js', () => {
                        initFirebaseSignaling();
                        if (cb) cb();
                    });
                } else {
                    initFirebaseSignaling();
                    if (cb) cb();
                }
            });
        } else if (!window.firebase.database) {
            loadScript('https://www.gstatic.com/firebasejs/10.8.0/firebase-database-compat.js', () => {
                initFirebaseSignaling();
                if (cb) cb();
            });
        }
    }

    async function initFirebaseSignaling() {
        const uid = getCurrentUserId();
        if (!uid) return;
        if (window.firebase && window.firebase.database) {
            try {
                if (!window.firebase.apps || !window.firebase.apps.length) {
                    window.firebase.initializeApp(firebaseConfig);
                }

                // Authenticate Firebase Auth via Custom Token to prevent PERMISSION_DENIED
                if (window.firebase.auth && !window.firebase.auth().currentUser) {
                    const token = localStorage.getItem('token');
                    if (token) {
                        try {
                            const authRes = await fetch('/api/auth/firebase-token', {
                                headers: { 'x-auth-token': token, 'Authorization': `Bearer ${token}` }
                            });
                            if (authRes.ok) {
                                const authData = await authRes.json();
                                if (authData && authData.token) {
                                    await firebase.auth().signInWithCustomToken(authData.token);
                                    console.log('[WebRTC] Firebase Auth authorized for user:', uid);
                                }
                            }
                        } catch (tokErr) {
                            console.warn('[WebRTC] Firebase token fetch warning:', tokErr.message);
                        }
                    }
                }

                db = window.firebase.database();
                const signalsRef = db.ref(`webrtc/signals/${uid}`);
                const statusRef = db.ref(`webrtc/status/${uid}`);
                
                statusRef.set(true).catch(() => {});
                statusRef.onDisconnect().remove().catch(() => {});

                signalsRef.off('child_added');
                signalsRef.on('child_added', (snapshot) => {
                    const data = snapshot.val();
                    if (!data || !data.type) return;
                    handleIncomingSignal(data.type, data.payload);
                    snapshot.ref.remove().catch(e => console.error(e));
                });
                console.log('[WebRTC] Dual Firebase RTDB signaling ready for user:', uid);
            } catch (e) {
                console.warn('[WebRTC] Firebase RTDB initialization warning:', e);
            }
        }
    }

    // Attempt immediately and bootstrap scripts if needed
    ensureFirebaseLoaded();

    // Guaranteed HTTP signaling polling fallback (ensures signals are never dropped on serverless Vercel)
    setInterval(async () => {
        const uid = getCurrentUserId();
        const token = localStorage.getItem('token');
        if (!uid || !token) return;

        if (!db) initFirebaseSignaling();

        try {
            const res = await fetch('/api/webrtc/signals', {
                headers: {
                    'x-auth-token': token,
                    'Authorization': `Bearer ${token}`
                }
            });
            if (res.ok) {
                const signals = await res.json();
                if (Array.isArray(signals)) {
                    signals.forEach(sig => {
                        if (sig && sig.type && sig.payload) {
                            handleIncomingSignal(sig.type, sig.payload);
                        }
                    });
                }
            }
        } catch (e) {}
    }, 800);

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

                const uid = getCurrentUserId();
                const signalPayload = Object.assign({}, data, {
                    from: data.from || uid,
                    to: data.to
                });

                // 1. Send via Socket.IO
                if (socket) {
                    socket.emit('webrtc_signal', {
                        to: data.to,
                        from: data.from || uid,
                        type: translatedEvent,
                        payload: signalPayload
                    });
                }

                // 2. Send via Client Firebase Realtime Database
                const sendViaFirebase = () => {
                    if (db) {
                        db.ref(`webrtc/signals/${data.to}`).push({
                            type: translatedEvent,
                            from: data.from || uid,
                            to: data.to,
                            payload: signalPayload,
                            timestamp: Date.now()
                        }).catch(e => console.warn('[WebRTC] Client RTDB push notice:', e.message));
                    }
                };

                if (db) {
                    sendViaFirebase();
                } else {
                    ensureFirebaseLoaded(() => sendViaFirebase());
                }

                // 3. Guaranteed Server-Side Bridge (bypasses all client permission limits)
                try {
                    const token = localStorage.getItem('token');
                    if (token) {
                        fetch('/api/webrtc/signal', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'x-auth-token': token,
                                'Authorization': `Bearer ${token}`
                            },
                            body: JSON.stringify({
                                to: data.to,
                                from: data.from || uid,
                                type: translatedEvent,
                                payload: signalPayload
                            })
                        }).catch(() => {});
                    }
                } catch(e) {}
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

    // Dynamically retrieve configured ICE/TURN servers from backend
    try {
        fetch('/api/webrtc/ice-servers')
            .then(r => r.json())
            .then(data => {
                if (data && data.iceServers && data.iceServers.length > 0) {
                    servers.iceServers = data.iceServers;
                }
            })
            .catch(() => {});
    } catch(e) {}

    window.globalSocket.on('connect', () => {
        const uid = getCurrentUserId();
        if (uid) {
            window.globalSocket.emit('join-room', uid);
        }
    });

    // ----------------------------------------------------
    // Signaling Event Listeners
    // ----------------------------------------------------

    let callTimerInterval = null;
    function startCallTimer() {
        if (callTimerInterval) clearInterval(callTimerInterval);
        if (!currentCallStartTime) currentCallStartTime = Date.now();
        const updateTimer = () => {
            if (!isCallActive) return;
            const diff = Math.max(0, Math.floor((Date.now() - currentCallStartTime) / 1000));
            const mins = String(Math.floor(diff / 60)).padStart(2, '0');
            const secs = String(diff % 60).padStart(2, '0');
            const titleEl = document.getElementById('global-call-title');
            if (titleEl) {
                titleEl.innerText = activeGroupIdForCall ? `Group Call (${mins}:${secs})` : `Connected (${mins}:${secs})`;
            }
        };
        updateTimer();
        callTimerInterval = setInterval(updateTimer, 1000);
    }

    function stopCallTimer() {
        if (callTimerInterval) {
            clearInterval(callTimerInterval);
            callTimerInterval = null;
        }
    }

    // Receive an offer from another user
    window.globalSocket.on('call-made', async (data) => {
        if (!data) return;
        const from = data.from || (data.payload && data.payload.from);
        const offer = data.offer || (data.payload && data.payload.offer);
        const isVideo = data.isVideo !== undefined ? data.isVideo : (data.payload && data.payload.isVideo);
        const isGroupCall = data.isGroupCall || (data.payload && data.payload.isGroupCall);
        let callerName = data.callerName || (data.payload && data.payload.callerName);

        if (from === currentCallTarget) {
            // Already connected or ringing with this user, do not reject duplicate offer!
            return;
        }

        if (isCallActive && !activeGroupIdForCall) {
            // Busy in another call
            window.globalSocket.emit('reject-call', { to: from });
            return;
        }
        
        if (activeGroupIdForCall && isGroupCall) {
            // Auto-accept group mesh connections if we are already in the group call
            handleGroupOffer(data);
            return;
        }

        // Standard 1-on-1 Incoming Call
        if (!callerName || callerName === 'undefined' || callerName === 'null' || String(callerName).trim() === '') {
            callerName = 'User';
        }
        document.getElementById('global-call-overlay').style.display = 'flex';
        document.getElementById('global-call-title').innerText = isVideo ? 'Incoming Video Call...' : 'Incoming Audio Call...';
        document.getElementById('global-call-name').innerText = `@${callerName.replace('@', '')} is calling you`;
        document.getElementById('global-call-controls-incoming').style.display = 'flex';
        document.getElementById('global-call-controls-active').style.display = 'none';
        document.getElementById('global-audio-avatar').classList.add('pulsing');
        
        incomingCallData = {
            ...data,
            from,
            offer,
            isVideo: !!isVideo,
            callerName
        };
        currentCallTarget = from;
        isVideoCall = !!isVideo;

        // Play Ringtone
        if (window.playCallRingtone) {
            window.playCallRingtone();
        } else {
            const ringbox = document.getElementById('global-ringtone');
            if (ringbox) {
                ringbox.currentTime = 0;
                ringbox.play().catch(e => console.log('Autoplay audio blocked', e));
            }
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

    window.globalSocket.on('answer-made', async (data) => {
        if (!data) return;
        if (window.stopOutgoingRingbackTone) window.stopOutgoingRingbackTone();
        const from = data.from || (data.payload && data.payload.from);
        const answer = data.answer || (data.payload && data.payload.answer);
        const targetPc = peerConnections[from] || Object.values(peerConnections)[0];
        if (targetPc && answer) {
            await targetPc.setRemoteDescription(new RTCSessionDescription(answer));
            await drainQueuedCandidates(from);
        }

        document.getElementById('global-call-title').innerText = activeGroupIdForCall ? 'Group Call Active' : 'Connected';
        document.getElementById('global-audio-avatar').classList.remove('pulsing');
        if (!currentCallStartTime) currentCallStartTime = Date.now();
        if (callTimeoutTimer) clearTimeout(callTimeoutTimer);
        startCallTimer();
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
        if (!data) return;
        const from = data.from || (data.payload && data.payload.from);
        const candidate = data.candidate || (data.payload && data.payload.candidate);
        if (from && candidate) {
            addOrQueueCandidate(from, candidate);
        }
    });

    // ----------------------------------------------------
    // Group Call Specific Listeners
    // ----------------------------------------------------
    
    window.globalSocket.on('user-joined-call', async (data) => {
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
                from: getCurrentUserId()
            });
        } catch(e) { console.error("Error handling group offer", e); }
    }

    function createPeerConnection(targetId, isGroup) {
        if (peerConnections[targetId]) {
            const existingPc = peerConnections[targetId];
            if (existingPc.signalingState !== 'closed') {
                return existingPc;
            }
        }

        const pc = new RTCPeerConnection(servers);
        peerConnections[targetId] = pc;

        if (localStream) {
            localStream.getTracks().forEach(track => pc.addTrack(track, localStream));
        setTimeout(() => applyDataSavingBitrateLimits(pc), 100);
        }

        pc.onconnectionstatechange = () => {
            console.log('[WebRTC] connectionState changed:', pc.connectionState);
            if (pc.connectionState === 'connected') {
                const avatar = document.getElementById('global-audio-avatar');
                if (avatar) avatar.classList.remove('pulsing');
                startCallTimer();
            }
        };

        pc.oniceconnectionstatechange = () => {
            console.log('[WebRTC] iceConnectionState changed:', pc.iceConnectionState);
            if (pc.iceConnectionState === 'connected' || pc.iceConnectionState === 'completed') {
                const avatar = document.getElementById('global-audio-avatar');
                if (avatar) avatar.classList.remove('pulsing');
                startCallTimer();
            }
        };

        pc.ontrack = event => {
            const stream = (event.streams && event.streams[0]) ? event.streams[0] : (event.track ? new MediaStream([event.track]) : null);
            if (!stream) return;
            remoteStreams[targetId] = stream;

            // Dedicated audio player for guaranteed audio playback (even if video wrapper is hidden)
            let audioEl = document.getElementById('global-remote-audio');
            if (!audioEl) {
                audioEl = document.createElement('audio');
                audioEl.id = 'global-remote-audio';
                audioEl.autoplay = true;
                audioEl.playsInline = true;
                document.body.appendChild(audioEl);
            }
            audioEl.srcObject = stream;
            audioEl.play().catch(e => console.log('[WebRTC] Remote audio autoplay blocked:', e));

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
                vid.play().catch(e => console.log('[WebRTC] Group video autoplay blocked:', e));
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
                vid.play().catch(e => console.log('[WebRTC] 1-on-1 video autoplay blocked:', e));
            }
        };

        pc.onicecandidate = event => {
            if(event.candidate) {
                window.globalSocket.emit('ice-candidate', { 
                    candidate: {
                        candidate: event.candidate.candidate,
                        sdpMid: event.candidate.sdpMid,
                        sdpMLineIndex: event.candidate.sdpMLineIndex
                    }, 
                    to: targetId, 
                    from: getCurrentUserId() 
                });
            }
        };

        return pc;
    }

    async function initiatePeerConnection(targetId, isVideo, isGroup) {
        try {
            const pc = createPeerConnection(targetId, isGroup);
            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);
            const plainOffer = {
                type: offer.type || 'offer',
                sdp: offer.sdp
            };
            window.globalSocket.emit('call-user', {
                offer: plainOffer,
                to: targetId,
                from: getCurrentUserId(),
                callerName: getCurrentUsername(),
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
            if (callTimeoutTimer) clearTimeout(callTimeoutTimer);
            if (window.stopCallRingtone) {
            window.stopCallRingtone();
        } else {
            const ringbox = document.getElementById('global-ringtone');
            if (ringbox) { ringbox.pause(); ringbox.currentTime = 0; }
        }
            try {
                if (isVideoCall) {
                    localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(true));
                } else {
                    localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(false));
                }
            } catch (mediaErr) {
                if (isVideoCall) {
                    localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(false));
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
            document.getElementById('global-call-title').innerText = 'Connected';
            let calleeDisplayCaller = incomingCallData.callerName || (incomingCallData.payload && incomingCallData.payload.callerName);
            if (!calleeDisplayCaller || calleeDisplayCaller === 'undefined' || calleeDisplayCaller === 'null' || String(calleeDisplayCaller).trim() === '') {
                calleeDisplayCaller = 'User';
            }
            document.getElementById('global-call-name').innerText = `@${calleeDisplayCaller.replace('@', '')}`;
            document.getElementById('global-audio-avatar').classList.remove('pulsing');

            const pc = createPeerConnection(incomingCallData.from, false);
            await pc.setRemoteDescription(new RTCSessionDescription(incomingCallData.offer));
            await drainQueuedCandidates(incomingCallData.from);

            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);

            const plainAnswer = {
                type: answer.type || 'answer',
                sdp: answer.sdp
            };
            window.globalSocket.emit('make-answer', {
                answer: plainAnswer,
                to: incomingCallData.from,
                from: getCurrentUserId()
            });
            
            isCallActive = true;
            currentCallStartTime = Date.now();
            startCallTimer();
        } catch(e) {
            console.error('Call Accept Error:', e);
            window.globalRejectCall();
        }
    };

    window.globalEndCall = async function() {
        if (activeGroupIdForCall) {
            window.globalSocket.emit('leave-group-call', { groupId: activeGroupIdForCall, userId: getCurrentUserId() });
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
        if (window.stopCallRingtone) window.stopCallRingtone();
        if (window.stopOutgoingRingbackTone) window.stopOutgoingRingbackTone();
        if (callTimeoutTimer) clearTimeout(callTimeoutTimer);
        stopCallTimer();
        if (window.stopCallRingtone) {
            window.stopCallRingtone();
        } else {
            const ringbox = document.getElementById('global-ringtone');
            if (ringbox) { ringbox.pause(); ringbox.currentTime = 0; }
        }

        isCallActive = false;
        incomingCallData = null;
        currentCallTarget = null;
        currentCallStartTime = null;
        activeGroupIdForCall = null;

        document.getElementById('global-call-overlay').style.display = 'none';
        document.getElementById('global-call-title').innerText = 'Incoming Call...';
        document.getElementById('global-call-name').innerText = 'Someone is calling you';
        document.getElementById('global-btn-toggle-mic').innerHTML = '<i class="fas fa-microphone"></i>';
        
        if (localStream) {
            localStream.getTracks().forEach(track => track.stop());
            localStream = null;
        }

        const remoteAudio = document.getElementById('global-remote-audio');
        if (remoteAudio) {
            remoteAudio.srcObject = null;
            remoteAudio.remove();
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
                    localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(true));
                } catch (mediaErr) {
                    localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(false));
                    isVideo = false;
                    isVideoCall = false;
                    if (window.showToast) window.showToast('Camera unavailable, continuing with audio only', 'info');
                }
            } else {
                localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(false));
            }

            document.getElementById('global-local-video').srcObject = localStream;
            document.getElementById('global-call-video-container').style.display = isVideoCall ? 'flex' : 'none';
            document.getElementById('global-call-audio-container').style.display = isVideoCall ? 'none' : 'flex';
            
            document.getElementById('global-call-overlay').style.display = 'flex';
            document.getElementById('global-call-controls-incoming').style.display = 'none';
            document.getElementById('global-call-controls-active').style.display = 'flex';
            document.getElementById('global-btn-toggle-cam').style.display = isVideoCall ? 'flex' : 'none';
            
            let displayName = targetUsername;
            if (!displayName || displayName === 'Select a conversation' || displayName === 'undefined' || displayName === 'null' || String(displayName).trim() === '') {
                displayName = 'User';
            }
            document.getElementById('global-call-name').innerText = displayName.startsWith('@') ? displayName : `@${displayName}`;
            document.getElementById('global-call-title').innerText = 'Calling...';
            if (window.playOutgoingRingbackTone) window.playOutgoingRingbackTone();
            // Dispatch call initiation message to wake up Mobile app with high-priority FCM VoIP CallKit
            try {
                const token = localStorage.getItem('token');
                if (token) {
                    fetch(`/api/messages/${targetUserId}`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'x-auth-token': token,
                            'Authorization': `Bearer ${token}`
                        },
                        body: JSON.stringify({
                            content: isVideoCall ? 'Video Call' : 'Voice Call',
                            attachmentType: 'call'
                        })
                    }).catch(() => {});
                }
            } catch(callMsgErr) {}

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
                localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(isVideo));
            } catch (mediaErr) {
                if (isVideo) {
                    localStream = await navigator.mediaDevices.getUserMedia(getCallMediaConstraints(false));
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
            window.globalSocket.emit('join-group-call', { groupId, userId: getCurrentUserId() });
            isCallActive = true;
        } catch(e) {
            console.error(e);
            window.globalEndUI();
            if(window.showToast) window.showToast('Microphone/Camera access denied.', 'error');
        }
    };

})();
